import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/firestore_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_setup_controller.dart';
import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
import 'package:fighter_edge/features/weekly_review/presentation/weekly_target_acceptance.dart';
import 'package:fighter_edge/state/app_state.dart';

class _FailingCommitRepository extends InMemoryEdgeFuelRepository {
  bool failSetup = false;
  bool failReview = false;

  @override
  Future<void> saveConfirmedPlan(
      String userId, NutritionSetupDraft draft, NutritionTarget target) async {
    if (failSetup) throw StateError('setup batch rejected');
    await super.saveConfirmedPlan(userId, draft, target);
  }

  @override
  Future<void> saveAcceptedReview(String userId, NutritionTarget target,
      StoredTrainingPlan plan, DateTime weekStart) async {
    if (failReview) throw StateError('review batch rejected');
    await super.saveAcceptedReview(userId, target, plan, weekStart);
  }
}

class _DelayedDraftRepository extends InMemoryEdgeFuelRepository {
  Completer<void>? holdNext;
  bool committed = false;

  @override
  Future<void> saveProfileDraft(
      String userId, NutritionSetupDraft draft) async {
    final gate = holdNext;
    holdNext = null;
    if (gate != null) await gate.future;
    await super.saveProfileDraft(userId, draft);
  }

  @override
  Future<void> saveConfirmedPlan(
      String userId, NutritionSetupDraft draft, NutritionTarget target) async {
    committed = true;
    await super.saveConfirmedPlan(userId, draft, target);
  }
}

class _FlakyDraftRepository extends InMemoryEdgeFuelRepository {
  int failuresLeft = 0;

  @override
  Future<void> saveProfileDraft(
      String userId, NutritionSetupDraft draft) async {
    if (failuresLeft > 0) {
      failuresLeft--;
      throw StateError('draft save rejected');
    }
    await super.saveProfileDraft(userId, draft);
  }
}

const _profile = NutritionProfile(
  goal: NutritionGoal.maintain,
  ageYears: 30,
  heightCm: 180,
  currentWeightKg: 80,
  equationProfile: EquationProfile.higherOffset,
  activityLevel: ActivityLevel.moderate,
  screeningStatus: NutritionScreeningStatus.completed,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 10, 25);

  test('setup batch failure leaves the draft restricted and target unchanged',
      () async {
    final repo = _FailingCommitRepository();
    final setup = EdgeFuelSetupController(
      repository: repo,
      userId: 'u',
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero);
    await setup.setGoal(NutritionGoal.maintain);
    await setup.setBodyInputs(
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      equationProfile: EquationProfile.higherOffset,
    );
    await setup.setActivityLevel(ActivityLevel.moderate);
    await setup.setScreeningReviewed(true);

    repo.failSetup = true;
    await expectLater(setup.confirm(), throwsStateError);
    expect(setup.draft.confirmed, isFalse);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isFalse);
    expect(await repo.watchTarget('u').first, isNull);

    repo.failSetup = false;
    expect(await setup.confirm(), isTrue);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isTrue);
    expect((await repo.watchTarget('u').first)?.isSuccess, isTrue);
    setup.dispose();
  });

  test('confirmation waits for an in-flight autosave', () async {
    final repo = _DelayedDraftRepository();
    final setup = EdgeFuelSetupController(
      repository: repo,
      userId: 'u',
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero);
    await setup.setGoal(NutritionGoal.maintain);
    await setup.setBodyInputs(
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      equationProfile: EquationProfile.higherOffset,
    );
    await setup.setActivityLevel(ActivityLevel.moderate);
    final gate = Completer<void>();
    repo.holdNext = gate;
    final autosave = setup.setScreeningReviewed(true);
    final confirmation = setup.confirm();
    await Future<void>.delayed(Duration.zero);
    expect(repo.committed, isFalse);
    gate.complete();
    await autosave;
    expect(await confirmation, isTrue);
    expect(repo.committed, isTrue);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isTrue);
    setup.dispose();
  });

  test('failed autosave retries before confirmation without leaving a target',
      () async {
    final repo = _FlakyDraftRepository();
    final setup = EdgeFuelSetupController(
      repository: repo,
      userId: 'u',
      clock: () => now,
    );
    await Future<void>.delayed(Duration.zero);
    await setup.setGoal(NutritionGoal.maintain);
    await setup.setBodyInputs(
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      equationProfile: EquationProfile.higherOffset,
    );
    await setup.setActivityLevel(ActivityLevel.moderate);
    repo.failuresLeft = 2;
    await setup.setScreeningReviewed(true);
    await expectLater(setup.confirm(), throwsStateError);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isFalse);
    expect(await repo.watchTarget('u').first, isNull);

    expect(await setup.confirm(), isTrue);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isTrue);
    expect((await repo.watchTarget('u').first)?.isSuccess, isTrue);
    setup.dispose();
  });

  test('review batch failure keeps both old target and unanswered review',
      () async {
    final repo = _FailingCommitRepository();
    final target = NutritionTargetCalculator.calculate(_profile, now: now);
    await repo.saveTarget('u', target);
    final data = InMemoryDataRepository();
    final state = AppState(dataRepository: data)..setUser('u');
    final plan = PlanController(log: state)
      ..configure(userId: 'u')
      ..startFresh(
          weeklyTrainingDays: 3,
          goal: 'Build fight-camp structure',
          level: 'Beginner');
    final week = DateTime.utc(2026, 10, 19);

    repo.failReview = true;
    await expectLater(
      WeeklyTargetAcceptance.accept(
        repository: repo,
        plan: plan,
        userId: 'u',
        weekStart: week,
        target: target,
        profile: _profile,
        deltaKcal: -100,
        now: now,
      ),
      throwsStateError,
    );
    expect((await repo.watchTarget('u').first)?.targetCalories,
        target.targetCalories);
    expect(plan.reviewDecision(week), isNull);
    expect(repo.acceptedReviewPlan('u'), isNull);

    repo.failReview = false;
    expect(
        await WeeklyTargetAcceptance.accept(
          repository: repo,
          plan: plan,
          userId: 'u',
          weekStart: week,
          target: target,
          profile: _profile,
          deltaKcal: -100,
          now: now,
        ),
        isTrue);
    expect((await repo.watchTarget('u').first)?.targetCalories,
        target.targetCalories! - 100);
    expect(plan.reviewDecision(week), ReviewDecision.accepted);
    expect(repo.acceptedReviewPlan('u')?.reviews['2026-10-19'],
        ReviewDecision.accepted);
    plan.dispose();
    state.dispose();
  });

  test('Firestore commits setup and review documents together', () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreEdgeFuelRepository(firestore: db);
    const draft = NutritionSetupDraft(
      confirmed: true,
      goal: NutritionGoal.maintain,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      equationProfile: EquationProfile.higherOffset,
      normalActivityLevel: ActivityLevel.moderate,
      screeningStatus: NutritionScreeningStatus.completed,
    );
    final target = NutritionTargetCalculator.calculate(_profile, now: now);
    await repo.saveConfirmedPlan('u', draft, target);
    expect((await repo.watchProfileDraft('u').first)?.confirmed, isTrue);
    expect((await repo.watchTarget('u').first)?.targetCalories,
        target.targetCalories);

    final state = AppState(dataRepository: InMemoryDataRepository())
      ..setUser('u');
    final plan = PlanController(log: state)
      ..configure(userId: 'u')
      ..startFresh(
          weeklyTrainingDays: 3,
          goal: 'Build fight-camp structure',
          level: 'Beginner');
    final week = DateTime.utc(2026, 10, 19);
    final prepared = plan.prepareAcceptedReview(week)!;
    await db
        .collection('users')
        .doc('u')
        .collection('trainingPlan')
        .doc('current')
        .set(plan.prepareAcceptedReview(DateTime.utc(2026, 10, 12))!.toJson());
    final adjusted = NutritionTargetCalculator.calculate(_profile,
        now: now, requestedCalories: target.targetCalories! - 100);
    await repo.saveAcceptedReview('u', adjusted, prepared, week);
    final savedPlan = await db
        .collection('users')
        .doc('u')
        .collection('trainingPlan')
        .doc('current')
        .get();
    expect((await repo.watchTarget('u').first)?.targetCalories,
        target.targetCalories! - 100);
    expect(
        StoredTrainingPlan.fromJson(savedPlan.data()!)?.reviews['2026-10-19'],
        ReviewDecision.accepted);
    await expectLater(
        repo.saveAcceptedReview('u', target, prepared, week), throwsStateError);
    expect((await repo.watchTarget('u').first)?.targetCalories,
        target.targetCalories! - 100,
        reason: 'a repeated acceptance cannot undo the first adjustment');
    plan.dispose();
    state.dispose();
  });

  test(
      'missing review document rejects the transaction without changing target',
      () async {
    final db = FakeFirebaseFirestore();
    final repo = FirestoreEdgeFuelRepository(firestore: db);
    final oldTarget = NutritionTargetCalculator.calculate(_profile, now: now);
    await repo.saveTarget('u', oldTarget);
    final state = AppState(dataRepository: InMemoryDataRepository())
      ..setUser('u');
    final plan = PlanController(log: state)
      ..configure(userId: 'u')
      ..startFresh(
        weeklyTrainingDays: 3,
        goal: 'Build fight-camp structure',
        level: 'Beginner',
      );
    final week = DateTime.utc(2026, 10, 19);
    final proposed = NutritionTargetCalculator.calculate(_profile,
        now: now, requestedCalories: oldTarget.targetCalories! - 100);

    await expectLater(
        repo.saveAcceptedReview(
            'u', proposed, plan.prepareAcceptedReview(week)!, week),
        throwsStateError);
    expect((await repo.watchTarget('u').first)?.targetCalories,
        oldTarget.targetCalories);
    expect(plan.reviewDecision(week), isNull);
    plan.dispose();
    state.dispose();
  });
}
