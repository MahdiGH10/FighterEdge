import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

class _FlakyFuel extends InMemoryEdgeFuelRepository {
  bool fail = true;

  @override
  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) =>
      fail
          ? Stream.error(StateError('read denied'))
          : super.watchNutritionDay(
              userId,
              localDate,
              targetSnapshot: targetSnapshot,
            );
}

class _FlakyPlan extends InMemoryDataRepository {
  bool fail = true;

  @override
  Stream<StoredTrainingPlan?> watchTrainingPlan(String userId) => fail
      ? Stream.error(StateError('read denied'))
      : super.watchTrainingPlan(userId);
}

void main() {
  testWidgets('Fuel shows a read failure and recovers on Retry',
      (tester) async {
    final auth = await makeRepo(signedIn: true, onboarded: true);
    final fuel = _FlakyFuel();
    await tester.pumpWidget(
      wrapApp(const NutritionScreen(), repo: auth, edgeFuelRepo: fuel),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fuel unavailable'), findsOneWidget);
    expect(find.text('Log food'), findsNothing);

    fuel.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel unavailable'), findsNothing);
    expect(find.byKey(const ValueKey('fuel-log-food')), findsOneWidget);
  });

  testWidgets('weekly review shows a read failure and recovers on Retry',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final auth = await makeRepo(signedIn: true, onboarded: true);
    final data = _FlakyPlan();
    final state = AppState(dataRepository: data)..setUser(auth.currentUser!.id);
    final plan = PlanController(log: state, repository: data)
      ..configure(userId: auth.currentUser!.id);
    await tester.pumpWidget(wrapApp(
      WeeklyReviewScreen(weekStart: DateTime(2026, 10, 19)),
      repo: auth,
      state: state,
      planController: plan,
    ));
    await tester.pumpAndSettle();
    expect(find.text('Weekly review unavailable'), findsOneWidget);
    expect(find.text('Recommendation'), findsNothing);

    data.fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Weekly review unavailable'), findsNothing);
    expect(find.text('Recommendation'), findsOneWidget);
  });
}
