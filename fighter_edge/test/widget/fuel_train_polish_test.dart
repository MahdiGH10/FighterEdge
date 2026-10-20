import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/screens/profile_screen.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/widgets/progress_ring.dart';
import 'package:fighter_edge/widgets/stat_card.dart';
import '../helpers/test_harness.dart';

void main() {
  testWidgets('Train has a Tools row for the timer and the play button is gone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const TrainingCampScreen(),
        repo: repo,
        state: AppState(
            dataRepository: InMemoryDataRepository(),
            clock: () => DateTime(2026, 9, 23))));
    await tester.pumpAndSettle();
    expect(find.text('Tools'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Start ')), findsNothing);
    await tester.tap(find.text('Round Timer'));
    await tester.pumpAndSettle();
    expect(find.byType(RoundTimerScreen), findsOneWidget);
  });

  testWidgets('Profile no longer lists the round timer', (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: AppState()));
    await tester.pumpAndSettle();
    expect(find.text('Round timer'), findsNothing);
    expect(find.text('Weight tracker'), findsOneWidget);
  });

  for (final weekday in [DateTime.wednesday, DateTime.thursday]) {
    testWidgets(
        'only today or the next unfinished session is highlighted on $weekday',
        (tester) async {
      tester.view.physicalSize = const Size(390, 1100);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      final data = InMemoryDataRepository();
      final state = AppState(
          dataRepository: data,
          clock: () => DateTime(2026, 9, 21 + weekday - 1))
        ..setUser(repo.currentUser!.id);
      // Three days a week is Mon, Wed, Fri.
      final plan = PlanController(log: state, repository: data)
        ..configure(userId: repo.currentUser!.id)
        ..startFresh(
            weeklyTrainingDays: 3,
            goal: 'Build fight-camp structure',
            level: 'Beginner');
      await tester.pumpWidget(wrapApp(const TrainingCampScreen(),
          repo: repo, state: state, planController: plan));
      await tester.pumpAndSettle();
      final primary = find.byKey(const ValueKey('primary-session-log'));
      expect(primary, findsOneWidget);
      final semantics = tester.widget<Semantics>(
          find.ancestor(of: primary, matching: find.byType(Semantics)).first);
      expect(semantics.properties.label, 'Log Skill session');
      // Today's row on Wednesday, the next one (Friday) on Thursday.
      final row = find.ancestor(of: primary, matching: find.byType(AppCard));
      expect(
          find.descendant(
              of: row,
              matching: find
                  .text(weekday == DateTime.wednesday ? 'Wed 23' : 'Fri 25')),
          findsOneWidget);
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
