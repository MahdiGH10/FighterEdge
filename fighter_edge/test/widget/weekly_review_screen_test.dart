import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
import 'package:fighter_edge/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:fighter_edge/state/app_state.dart';

import '../helpers/test_harness.dart';

void main() {
  // Sunday evening; the week under review started on Monday 2026-10-19.
  final sunday = DateTime(2026, 10, 25, 20);
  final week = DateTime.utc(2026, 10, 19);

  Future<PlanController> pump(WidgetTester tester,
      {int days = 6,
      bool doEverything = false,
      Size size = const Size(430, 1800),
      double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = await makeRepo(signedIn: true);
    final data = InMemoryDataRepository();
    final userId = repo.currentUser!.id;
    var now = DateTime(2026, 10, 19, 9);
    final state = AppState(dataRepository: data, clock: () => now)
      ..setUser(userId);
    final plan = PlanController(log: state, repository: data)
      ..configure(userId: userId)
      ..startFresh(
          weeklyTrainingDays: days, goal: 'Gain muscle', level: 'Beginner');
    if (doEverything) {
      for (final session in plan.currentWeek!.sessions) {
        plan.complete(session, title: 't');
      }
    }
    now = sunday;
    await tester.pumpWidget(wrapApp(WeeklyReviewScreen(weekStart: week),
        repo: repo, state: state, planController: plan));
    await tester.pumpAndSettle();
    return plan;
  }

  testWidgets('shows the week and ends in one recommendation', (tester) async {
    await pump(tester);
    expect(find.text('Training'), findsOneWidget);
    expect(find.text('0 of 6 sessions done'), findsOneWidget);
    expect(find.text('Food'), findsOneWidget);
    expect(find.text('Set up Fuel to compare your week with a target.'),
        findsOneWidget);
    expect(find.text('Weight'), findsOneWidget);
    expect(find.text('Recommendation'), findsOneWidget);
    expect(find.text('You have a planned session left over. Move it to today?'),
        findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Keep current'), findsOneWidget);
  });

  testWidgets('accepting moves the left-over session to today', (tester) async {
    final plan = await pump(tester);
    expect(plan.todaySession, isNull);

    await tester.tap(find.text('Accept'));
    await tester.pumpAndSettle();

    expect(plan.todaySession, isNotNull);
    expect(plan.reviewDecision(week), ReviewDecision.accepted);
    expect(
        plan.rows.where((r) => r.status == SessionStatus.moved), hasLength(1));
  });

  testWidgets('keeping the current plan changes nothing', (tester) async {
    final plan = await pump(tester);
    final before = plan.rows.map((r) => '${r.session.id}:${r.status}').toList();

    await tester.tap(find.text('Keep current'));
    await tester.pumpAndSettle();

    expect(plan.reviewDecision(week), ReviewDecision.kept);
    expect(
        plan.rows.map((r) => '${r.session.id}:${r.status}').toList(), before);
    expect(plan.todaySession, isNull);
  });

  testWidgets('a full week with no calorie target just says so',
      (tester) async {
    final plan = await pump(tester, days: 3, doEverything: true);
    expect(find.text('3 of 3 sessions done'), findsOneWidget);
    expect(
        find.text('Set up Fuel to get a calorie target before changes can be '
            'suggested.'),
        findsOneWidget);
    expect(find.text('Accept'), findsNothing);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(plan.reviewDecision(week), ReviewDecision.kept);
  });

  testWidgets('a reviewed week shows the answer, not the buttons',
      (tester) async {
    final plan = await pump(tester);
    plan.recordReview(week, ReviewDecision.accepted);
    await tester.pumpAndSettle();
    expect(find.text('You accepted this review.'), findsOneWidget);
    expect(find.text('Accept'), findsNothing);
  });

  testWidgets('review actions remain visible at 320px and 200% text',
      (tester) async {
    await pump(tester, size: const Size(320, 640), textScale: 2);
    expect(find.text('Accept'), findsOneWidget);
    expect(find.text('Keep current'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
