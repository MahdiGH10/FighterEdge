import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import 'package:fighter_edge/theme/app_theme.dart';
import 'package:fighter_edge/widgets/skeleton.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';

import '../../helpers/test_harness.dart';

NutritionTarget _successTarget() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      estimatedRmrKcal: 1780,
      maintenanceRangeLowKcal: 2400,
      maintenanceRangeHighKcal: 2600,
      targetCalories: 2500,
      proteinGrams: 150,
      fatGrams: 80,
      carbGrams: 260,
      fiberGramsLow: 30,
      fiberGramsHigh: 40,
      equationProfileUsed: EquationProfile.higherOffset,
      confidence: ConfidenceLabel.high,
    );

void main() {
  group('EdgeFuelPlanScreen', () {
    testWidgets(
        'shows an empty state with a way to start setup when no plan exists',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: InMemoryEdgeFuelRepository(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No plan yet'), findsOneWidget);
      expect(find.text('START SETUP'), findsOneWidget);
    });

    testWidgets('shows the calculated target, macros, and explanation',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('2500 kcal'), findsOneWidget);
      expect(find.text('150 g'), findsOneWidget);
      expect(find.text('260 g'), findsOneWidget);
      expect(find.text('80 g'), findsOneWidget);
      expect(find.textContaining('Estimated resting energy: 1780 kcal'),
          findsOneWidget);
      expect(find.text('High confidence'), findsOneWidget);
    });

    testWidgets('Ask EdgeFuel Coach shows the AI explanation on success',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: FakeEdgeFuelAiGateway(
          nextResult: () => const EdgeFuelAiResult.success(
            EdgeFuelAiResponse(
              summary: 'You are tracking well toward your goal.',
              warnings: ['pace reduced to protect RMR'],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('ASK EDGEFUEL COACH'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ASK EDGEFUEL COACH'));
      await tester.pump(); // enter loading state
      await tester.pumpAndSettle();

      expect(
          find.text('You are tracking well toward your goal.'), findsOneWidget);
      expect(
          find.textContaining('pace reduced to protect RMR'), findsOneWidget);
    });

    testWidgets('Pro can generate and read the full Fighter Brief',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: const FakeEdgeFuelAiGateway(),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('GENERATE FULL FIGHTER BRIEF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pumpAndSettle();

      expect(find.text('NEXT ACTION'), findsOneWidget);
      expect(find.text('MEAL SUGGESTION'), findsOneWidget);
      expect(find.text('TRAINING TIMING'), findsOneWidget);
      expect(find.text('WEEKLY ADJUSTMENT'), findsOneWidget);
    });

    testWidgets(
        'the brief shows a shaped building state that names each step, '
        'and leaves the coach alone', (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());
      final gateway = _PendingBriefGateway();

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: gateway,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('GENERATE FULL FIGHTER BRIEF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pump();

      expect(find.text('Reading your plan…'), findsOneWidget);
      expect(find.byType(Skeleton), findsOneWidget,
          reason: 'only the brief is loading, not the coach');
      expect(find.text('ASK EDGEFUEL COACH'), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(MotionTokens.fast);
      expect(find.text('Checking today’s log…'), findsOneWidget);

      gateway.brief.complete(const EdgeFuelAiResult.unavailable());
      await tester.pumpAndSettle();
      expect(find.byType(Skeleton), findsNothing);
      expect(find.text('Couldn’t build your brief'), findsOneWidget);
    });

    testWidgets('a used-up quota says when the brief comes back',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: FakeEdgeFuelAiGateway(
          nextResult: () => const EdgeFuelAiResult.quotaReached(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('GENERATE FULL FIGHTER BRIEF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GENERATE FULL FIGHTER BRIEF'));
      await tester.pumpAndSettle();

      expect(find.text('Today’s briefs are used up'), findsOneWidget);
      expect(find.textContaining('resets tomorrow'), findsOneWidget);
    });

    testWidgets(
        'Ask EdgeFuel Coach shows an unavailable state without crashing',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: FakeEdgeFuelAiGateway(
          nextResult: () => const EdgeFuelAiResult.unavailable(),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('ASK EDGEFUEL COACH'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ASK EDGEFUEL COACH'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('EdgeFuel Coach is unavailable right now'),
        findsOneWidget,
      );
    });

    testWidgets('a free account sees a lock instead of the coach',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.free);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(find.text('SEE PRO'), 300,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('SEE PRO'), findsOneWidget);
      expect(find.text('ASK EDGEFUEL COACH'), findsNothing);
    });

    testWidgets('a free account sees a personalized Fighter Brief preview',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.free);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(userId, _successTarget());
      final today = DateTime.now();
      final entry = FoodLogEntry(
        id: 'meal-1',
        name: 'Chicken and rice',
        notes: 'test fixture',
        calories: 650,
        proteinGrams: 35,
        carbGrams: 70,
        fatGrams: 12,
        loggedAt: today,
      );
      await edgeFuelRepo.saveNutritionDay(
        userId,
        NutritionDay.empty(
          localDate: today.toIso8601String().substring(0, 10),
          timeZone: 'UTC',
          now: today,
          targetSnapshot: _successTarget(),
        ).copyWith(entries: [entry]),
      );

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('FIGHTER BRIEF'), findsOneWidget);
      expect(find.text('Protein is the main gap in today\'s target.'),
          findsOneWidget);
      expect(find.text('UNLOCK MY FIGHTER BRIEF'), findsOneWidget);
      expect(find.text('Log a meal to unlock your personalized next step.'),
          findsNothing);
    });
  });
}

/// Answers the coach at once and holds the brief open until the test
/// completes [brief].
class _PendingBriefGateway implements EdgeFuelAiGateway {
  final brief = Completer<EdgeFuelAiResult>();

  @override
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async =>
      const EdgeFuelAiResult.success(EdgeFuelAiResponse(summary: 'coach'));

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) =>
      brief.future;
}
