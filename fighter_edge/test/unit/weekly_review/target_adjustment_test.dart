import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import 'package:fighter_edge/features/weekly_review/domain/review_window.dart';
import 'package:fighter_edge/features/weekly_review/domain/target_adjustment.dart';

NutritionTarget _target({
  NutritionTargetStatus status = NutritionTargetStatus.success,
  int? kcal = 2500,
  int? carbs = 280,
}) =>
    NutritionTarget(
      status: status,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 9, 1),
      estimatedRmrKcal: 1800,
      targetCalories: kcal,
      proteinGrams: 160,
      fatGrams: 80,
      carbGrams: carbs,
      appliedGoalAdjustmentPercent: -10,
    );

void main() {
  final now = DateTime(2026, 10, 25, 20);
  const profile = NutritionProfile(
    goal: NutritionGoal.maintain,
    ageYears: 30,
    heightCm: 180,
    currentWeightKg: 90,
    equationProfile: EquationProfile.higherOffset,
    activityLevel: ActivityLevel.moderate,
    screeningStatus: NutritionScreeningStatus.completed,
  );

  group('TargetAdjustment', () {
    test('recalculates every macro and context through the policy', () {
      final before = NutritionTargetCalculator.calculate(profile, now: now);
      final t =
          TargetAdjustment.apply(before, -100, profile: profile, now: now)!;
      expect(t.targetCalories, before.targetCalories! - 100);
      expect(t.proteinGrams, before.proteinGrams);
      expect(t.fatGrams, isNot(before.fatGrams));
      expect(t.policyVersion, 1, reason: 'the policy itself is not changed');
      expect(t.calculatedAt, now);
      expect(t.estimatedRmrKcal, before.estimatedRmrKcal);
    });

    test('macros still reconcile with the calories after a step', () {
      final before = NutritionTargetCalculator.calculate(profile, now: now);
      for (final delta in [-150, -100, 100, 150]) {
        final t =
            TargetAdjustment.apply(before, delta, profile: profile, now: now)!;
        expect((t.macroDerivedCalories! - t.targetCalories!).abs(),
            lessThanOrEqualTo(20),
            reason: '$delta');
      }
    });

    test('never touches a target that is not a success', () {
      expect(
        TargetAdjustment.apply(
            _target(status: NutritionTargetStatus.needsProfessionalReview),
            -100,
            profile: profile,
            now: now),
        isNull,
      );
      expect(
          TargetAdjustment.apply(_target(kcal: null), 100,
              profile: profile, now: now),
          isNull);
      expect(
          TargetAdjustment.apply(_target(kcal: null), -100,
              profile: profile, now: now),
          isNull);
    });

    test('refuses a step below RMR', () {
      expect(
          TargetAdjustment.apply(_target(kcal: 1950), -150,
              profile: profile, now: now),
          isNull);
    });

    test('refuses a high-training loss step below the carbohydrate floor', () {
      const active = NutritionProfile(
        goal: NutritionGoal.loseFat,
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        targetWeightKg: 72,
        goalPace: GoalPace.standard,
        equationProfile: EquationProfile.higherOffset,
        activityLevel: ActivityLevel.high,
        screeningStatus: NutritionScreeningStatus.completed,
      );
      final before = NutritionTargetCalculator.calculate(active,
          now: now, requestedCalories: 2050);
      expect(before.isSuccess, isTrue);
      expect(before.targetCalories, 2050);
      expect(TargetAdjustment.apply(before, -150, profile: active, now: now),
          isNull);
    });

    test('a changed or flagged profile cannot inherit an old target', () {
      final before = NutritionTargetCalculator.calculate(profile, now: now);
      final flagged = profile.copyWith(
        safetyFlags: const NutritionSafetyFlags(kidneyDisease: true),
      );
      expect(TargetAdjustment.apply(before, -100, profile: flagged, now: now),
          isNull);
    });
  });

  group('ReviewWindow', () {
    test('Sunday reviews the week that is ending', () {
      expect(ReviewWindow.weekFor(DateTime(2026, 10, 25, 9)),
          DateTime.utc(2026, 10, 19));
    });

    test('Monday still offers the week that just ended', () {
      expect(ReviewWindow.weekFor(DateTime(2026, 10, 26, 9)),
          DateTime.utc(2026, 10, 19));
    });

    test('no other day offers a review', () {
      for (var day = 20; day <= 24; day++) {
        expect(ReviewWindow.weekFor(DateTime(2026, 10, day)), isNull,
            reason: 'Oct $day');
      }
    });
  });
}
