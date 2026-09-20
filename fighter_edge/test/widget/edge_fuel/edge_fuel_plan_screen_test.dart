import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
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
    testWidgets('offers setup when there is no saved plan', (tester) async {
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

    testWidgets('renders the deterministic target and calculation context',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

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
      expect(
        find.textContaining('Estimated resting energy: 1780 kcal'),
        findsOneWidget,
      );
      expect(find.text('High confidence'), findsOneWidget);
    });

    testWidgets('shows remaining nutrition and recipes that fit today',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('2500 kcal left today'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.text('Recipes that fit, highest protein first'),
        findsOneWidget,
      );
    });

    testWidgets('gives a free athlete a real personalized brief preview',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.free);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());
      final now = DateTime.now();
      await edgeFuelRepo.saveNutritionDay(
        repo.currentUser!.id,
        NutritionDay.empty(
          localDate: now.toIso8601String().substring(0, 10),
          timeZone: 'UTC',
          now: now,
          targetSnapshot: _successTarget(),
        ).copyWith(entries: [
          FoodLogEntry(
            id: 'meal-1',
            name: 'Chicken and rice',
            notes: 'test fixture',
            calories: 650,
            proteinGrams: 35,
            carbGrams: 70,
            fatGrams: 12,
            loggedAt: now,
          ),
        ]),
      );

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('UNLOCK MY FIGHTER BRIEF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('FIGHTER BRIEF'), findsOneWidget);
      expect(find.text('FREE PREVIEW'), findsOneWidget);
      expect(find.text('Protein is the main gap in today\'s target.'),
          findsOneWidget);
      expect(find.text('UNLOCK MY FIGHTER BRIEF'), findsOneWidget);
    });

    testWidgets('routes a Pro athlete to the single Coach experience',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('OPEN AI FIGHTER BRIEF'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('OPEN AI FIGHTER BRIEF'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OPEN AI FIGHTER BRIEF'));
      await tester.pumpAndSettle();

      expect(find.text('Talk to your coach'), findsOneWidget);
      expect(find.text('GET TODAY\'S FIGHTER BRIEF'), findsOneWidget);
    });
  });
}
