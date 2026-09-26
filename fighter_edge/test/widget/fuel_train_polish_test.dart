import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/widgets/progress_ring.dart';
import '../helpers/test_harness.dart';

void main() {
  for (final weekday in [DateTime.wednesday, DateTime.thursday]) {
    testWidgets(
        'only today or the next unfinished session is highlighted on $weekday',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      final data = InMemoryDataRepository();
      for (final day in ['Mon', 'Wed', 'Fri']) {
        await data.saveSession(
            repo.currentUser!.id,
            TrainingSession(
                day: day,
                title: day,
                subtitle: 'Practice',
                icon: Icons.sports_mma,
                completed: false));
      }
      final state = AppState(
          dataRepository: data,
          clock: () => DateTime(2026, 9, 21 + weekday - 1))
        ..setUser(repo.currentUser!.id);
      await tester.pumpWidget(
          wrapApp(const TrainingCampScreen(), repo: repo, state: state));
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('primary-session-start'));
      expect(primary, findsOneWidget);
      final semantics = tester.widget<Semantics>(
          find.ancestor(of: primary, matching: find.byType(Semantics)).first);
      expect(semantics.properties.label,
          weekday == DateTime.wednesday ? 'Start Wed' : 'Start Mon');
    });
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets('Fuel has one calorie hero and readable macros at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = await makeRepo(signedIn: true);
      final fuelRepo = InMemoryEdgeFuelRepository();
      await fuelRepo.saveTarget(
          repo.currentUser!.id,
          NutritionTarget(
              status: NutritionTargetStatus.success,
              policyVersion: 1,
              calculatedAt: DateTime(2026, 9, 26),
              targetCalories: 2500,
              proteinGrams: 150,
              carbGrams: 280,
              fatGrams: 87));
      await tester.pumpWidget(
          wrapApp(const NutritionScreen(), repo: repo, edgeFuelRepo: fuelRepo));
      await tester.pumpAndSettle();
      expect(find.byType(ProgressRing), findsOneWidget);
      expect(find.text('2500'), findsOneWidget);
      expect(find.text('kcal left'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Protein'), 100,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('0 / 150 g'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.bySemanticsLabel('Previous day'));
      await tester.pumpAndSettle();
      expect(
          tester
              .element(find.byType(NutritionScreen))
              .read<EdgeFuelController>()
              .isToday,
          isFalse);
      expect(tester.takeException(), isNull);
    });
  }
}
