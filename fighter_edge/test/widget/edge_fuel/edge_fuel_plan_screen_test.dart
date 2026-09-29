import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
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
      expect(find.text('Start setup'), findsOneWidget);
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

    testWidgets('offers a free athlete Pro instead of the coach',
        (tester) async {
      final repo = await makeRepo(signedIn: true, plan: Plan.free);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _successTarget());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelPlanScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('See Pro'),
        300,
        scrollable: find.byType(Scrollable).first,
      );

      expect(find.text('EdgeFuel Coach'), findsOneWidget);
      expect(find.text('See Pro'), findsOneWidget);
      expect(find.text('Ask your coach'), findsNothing);
    });

    testWidgets('routes a Pro athlete to the Coach experience', (tester) async {
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
        find.text('Ask your coach'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('Ask your coach'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ask your coach'));
      await tester.pumpAndSettle();

      expect(find.text('Talk to your coach'), findsOneWidget);
    });
  });
}
