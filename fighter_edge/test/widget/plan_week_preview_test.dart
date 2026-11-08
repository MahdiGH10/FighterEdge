import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/screens/onboarding/plan_week_preview.dart';
import 'package:fighter_edge/state/app_state.dart';

import '../helpers/test_harness.dart';

void main() {
  final wednesday = DateTime(2026, 9, 23, 20);

  Future<PlanController> seededPlan(
    AppState state,
    InMemoryDataRepository data,
    String userId,
  ) async =>
      PlanController(log: state, repository: data)
        ..configure(userId: userId)
        ..startFresh(
          weeklyTrainingDays: 3,
          goal: 'Build fight-camp structure',
          level: 'Beginner',
        );

  for (final scale in [1.0, 2.0]) {
    testWidgets('lists the real next seven days at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      final data = InMemoryDataRepository();
      final userId = repo.currentUser!.id;
      final state = AppState(dataRepository: data, clock: () => wednesday)
        ..setUser(userId);
      final plan = await seededPlan(state, data, userId);

      await tester.pumpWidget(
        wrapApp(
          MediaQuery(
            data: MediaQueryData(
              size: const Size(320, 568),
              textScaler: TextScaler.linear(scale),
              disableAnimations: true,
            ),
            child: const Scaffold(
                body: SingleChildScrollView(
              child: PlanWeekPreview(),
            )),
          ),
          repo: repo,
          state: state,
          planController: plan,
        ),
      );
      await tester.pumpAndSettle();

      // Three days a week is Mon, Wed, Fri. From Wednesday the next seven
      // days hold Wednesday (today), Friday and the following Monday.
      expect(find.text('Your first 7 days'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.textContaining('move or skip'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('upcoming matches the Train week for the same days',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final data = InMemoryDataRepository();
    final userId = repo.currentUser!.id;
    final state = AppState(dataRepository: data, clock: () => wednesday)
      ..setUser(userId);
    final plan = await seededPlan(state, data, userId);

    final rows = PlanWeekPreview.upcoming(plan);

    expect(rows.map((r) => r.date), [
      DateTime.utc(2026, 9, 23),
      DateTime.utc(2026, 9, 25),
      DateTime.utc(2026, 9, 28),
    ]);
    final train = [
      for (final day in plan.weekDays()) ...day.rows,
    ].where((r) => !r.date.isBefore(DateTime.utc(2026, 9, 23)));
    for (final row in train) {
      expect(rows.any((r) => r.session.id == row.session.id), isTrue);
    }
  });

  testWidgets('draws nothing without a plan', (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(
      wrapApp(
        const Scaffold(body: PlanWeekPreview()),
        repo: repo,
        state: AppState(clock: () => wednesday),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your first 7 days'), findsNothing);
  });
}
