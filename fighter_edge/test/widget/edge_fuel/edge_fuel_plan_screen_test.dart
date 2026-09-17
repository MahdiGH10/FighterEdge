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

      await tester.ensureVisible(find.text('ASK EDGEFUEL COACH'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ASK EDGEFUEL COACH'));
      await tester.pump(); // enter loading state
      await tester.pumpAndSettle();

      expect(
          find.text('You are tracking well toward your goal.'), findsOneWidget);
      expect(
          find.textContaining('pace reduced to protect RMR'), findsOneWidget);
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

      await tester.ensureVisible(find.text('ASK EDGEFUEL COACH'));
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
