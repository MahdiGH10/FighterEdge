import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/review_window.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
import 'package:fighter_edge/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

import '../helpers/test_harness.dart';

/// The weekly review notification opens the review for the week that is ready
/// to review, with a clock the test sets (the review window is Sunday and
/// Monday).
void main() {
  late FakeReminderGateway gateway;
  late PlanController plan;

  Future<void> boot(WidgetTester tester, DateTime clock) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await makeRepo(signedIn: true, onboarded: true);
    final uid = repo.currentUser!.id;
    final data = InMemoryDataRepository();
    addTearDown(data.dispose);
    for (final slot in [
      const LegacySessionSlot(
          id: 'Mon-Striking', day: 'Mon', title: 'Striking'),
      const LegacySessionSlot(
          id: 'Wed-Wrestling', day: 'Wed', title: 'Wrestling'),
      const LegacySessionSlot(id: 'Fri-BJJ', day: 'Fri', title: 'BJJ'),
    ]) {
      await data.saveLegacySession(uid, slot);
    }
    final state = AppState(dataRepository: data, clock: () => clock)
      ..setUser(uid);
    plan = PlanController(log: state, repository: data, sync: SyncTracker());
    gateway = FakeReminderGateway(allowed: true);

    await tester.pumpWidget(wrapApp(
      const HomeShell(),
      repo: repo,
      state: state,
      planController: plan,
      reminderGateway: gateway,
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tapReview(WidgetTester tester) async {
    gateway.tapController.add(const NotificationTap(id: 7, route: '/review'));
    await tester.pumpAndSettle();
  }

  int tab(WidgetTester tester) =>
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex;

  testWidgets('on Sunday it opens the review for this week', (tester) async {
    // Sunday 25 October 2026, 18:00.
    await boot(tester, DateTime(2026, 10, 25, 18));
    expect(plan.hasPlan, isTrue);
    await tapReview(tester);

    expect(find.byType(WeeklyReviewScreen), findsOneWidget);
    final screen =
        tester.widget<WeeklyReviewScreen>(find.byType(WeeklyReviewScreen));
    expect(screen.weekStart, ReviewWindow.weekFor(plan.today));
    expect(screen.weekStart.weekday, DateTime.monday);
  });

  testWidgets('on Monday it opens the review for the week just ended',
      (tester) async {
    await boot(tester, DateTime(2026, 10, 26, 9));
    await tapReview(tester);
    final screen =
        tester.widget<WeeklyReviewScreen>(find.byType(WeeklyReviewScreen));
    expect(screen.weekStart.day, 19, reason: 'the week of Monday 19 October');
  });

  testWidgets('from another screen it comes back to Home first',
      (tester) async {
    await boot(tester, DateTime(2026, 10, 25, 18));
    final nav = tester.widget<AppBottomNav>(find.byType(AppBottomNav));
    nav.onTap(2);
    await tester.pumpAndSettle();
    expect(tab(tester), 2);

    await tapReview(tester);
    expect(find.byType(WeeklyReviewScreen), findsOneWidget);
    Navigator.of(tester.element(find.byType(WeeklyReviewScreen))).pop();
    await tester.pumpAndSettle();
    expect(tab(tester), 0);
  });

  testWidgets('outside the review window the athlete simply lands on Home',
      (tester) async {
    await boot(tester, DateTime(2026, 10, 28, 12)); // a Wednesday
    await tapReview(tester);
    expect(find.byType(WeeklyReviewScreen), findsNothing);
    expect(tab(tester), 0);
  });

  testWidgets('a review already answered is not opened again', (tester) async {
    await boot(tester, DateTime(2026, 10, 25, 18));
    plan.recordReview(ReviewWindow.weekFor(plan.today)!, ReviewDecision.kept);
    await tester.pumpAndSettle();
    await tapReview(tester);
    expect(find.byType(WeeklyReviewScreen), findsNothing);
    expect(tab(tester), 0);
  });

  testWidgets('a session reminder opens the Train tab', (tester) async {
    await boot(tester, DateTime(2026, 10, 26, 9));
    gateway.tapController
        .add(const NotificationTap(id: 8, route: '/train/session/s-1'));
    await tester.pumpAndSettle();
    expect(tab(tester), 1);
  });
}
