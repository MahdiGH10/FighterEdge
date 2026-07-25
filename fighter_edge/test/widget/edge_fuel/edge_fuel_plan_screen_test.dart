import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('EdgeFuelPlanScreen', () {
    testWidgets('shows an empty state with a way to start setup when no plan exists',
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
      await edgeFuelRepo.saveTarget(
        userId,
        NutritionTarget(
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
        ),
      );

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
  });
}
