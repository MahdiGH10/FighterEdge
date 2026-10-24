import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/notifications/notification_settings_screen.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/widgets/grouped_list.dart';

import '../helpers/test_harness.dart';

/// Settings > Notifications, driven through the real app so the permission
/// request, the stored settings and the reconcile are exercised end to end.
void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  Future<void> boot(WidgetTester tester, ReminderGateway reminders) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  Future<void> openNotifications(WidgetTester tester) async {
    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.notificationSettings);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  }

  Finder switchFor(String title) => find.descendant(
        of: find.ancestor(
          of: find.text(title),
          matching: find.byType(GroupedRow),
        ),
        matching: find.byType(Switch),
      );

  /// Lets the debounced reconcile run.
  Future<void> reconcile(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
  }

  NotificationController controllerOf(WidgetTester tester) => tester
      .element(find.byType(NotificationSettingsScreen))
      .read<NotificationController>();

  testWidgets('Settings links to Notifications where reminders can fire',
      (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Camp reminders'), findsNothing);

    await tester.tap(find.text('Notifications'));
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  });

  testWidgets('the whole feature is hidden where reminders cannot fire',
      (tester) async {
    final reminders = FakeReminderGateway()..available = false;
    await boot(tester, reminders);
    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Notifications'), findsNothing);
    expect(reminders.permissionRequests, 0);
    expect(reminders.replaceCalls, 0);
  });

  testWidgets('every channel starts off and nothing asks for permission',
      (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    await openNotifications(tester);

    expect(tester.widget<Switch>(switchFor('Session reminder')).value, isFalse);
    expect(tester.widget<Switch>(switchFor('Weekly review')).value, isFalse);
    expect(reminders.permissionRequests, 0);
    expect(reminders.pending, isEmpty);
  });

  testWidgets('granting permission turns a reminder on and schedules it',
      (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    await openNotifications(tester);

    await tester.tap(switchFor('Weekly review'));
    await tester.pumpAndSettle();
    await reconcile(tester);

    expect(tester.widget<Switch>(switchFor('Weekly review')).value, isTrue);
    expect(reminders.permissionRequests, 1);
    // Only the weekly review asks for the quiet iOS permission.
    expect(reminders.provisionalRequests, 1);
    expect(reminders.pending, isNotEmpty);
    expect(
      reminders.pending.values.map((r) => r.channel).toSet(),
      {NotificationChannel.weeklyReview},
    );
    expect(reminders.pending.values.first.route, '/review');
  });

  testWidgets('a denied permission leaves the switch off and explains where',
      (tester) async {
    final reminders = FakeReminderGateway(permissionGranted: false);
    await boot(tester, reminders);
    await openNotifications(tester);

    await tester.tap(switchFor('Session reminder'));
    await tester.pumpAndSettle();
    await reconcile(tester);

    expect(tester.widget<Switch>(switchFor('Session reminder')).value, isFalse);
    expect(reminders.pending, isEmpty);
    expect(
      find.textContaining('Notifications are turned off for Fighter Edge'),
      findsOneWidget,
    );
    // A calm state: no repeat prompt from just looking at the screen.
    expect(reminders.permissionRequests, 1);
  });

  testWidgets('turning a reminder off removes what was scheduled',
      (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    await openNotifications(tester);

    await tester.tap(switchFor('Weekly review'));
    await tester.pumpAndSettle();
    await reconcile(tester);
    expect(reminders.pending, isNotEmpty);

    await tester.tap(switchFor('Weekly review'));
    await tester.pumpAndSettle();
    await reconcile(tester);

    expect(tester.widget<Switch>(switchFor('Weekly review')).value, isFalse);
    expect(reminders.pending, isEmpty);
  });

  testWidgets('Pause all silences everything until it is switched off',
      (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    await openNotifications(tester);

    await tester.tap(switchFor('Weekly review'));
    await tester.pumpAndSettle();
    await reconcile(tester);
    expect(reminders.pending, isNotEmpty);

    await tester.tap(switchFor('Pause all'));
    await tester.pumpAndSettle();
    await reconcile(tester);
    expect(reminders.pending, isEmpty);

    await tester.tap(switchFor('Pause all'));
    await tester.pumpAndSettle();
    await reconcile(tester);
    expect(reminders.pending, isNotEmpty);
    expect(controllerOf(tester).settings.pauseAll, isFalse);
  });

  testWidgets('repeated reconciles never leave duplicates', (tester) async {
    final reminders = FakeReminderGateway();
    await boot(tester, reminders);
    await openNotifications(tester);

    await tester.tap(switchFor('Weekly review'));
    await tester.pumpAndSettle();
    await reconcile(tester);
    final first = reminders.pending.keys.toSet();

    final controller = controllerOf(tester);
    for (var i = 0; i < 3; i++) {
      await controller.reconcileNow();
    }
    expect(reminders.pending.keys.toSet(), first);
  });

  testWidgets('the screen holds at 200% text on a 320 px phone',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(
      FighterEdgeApp(
        authRepo: repo,
        reminderGateway: FakeReminderGateway(permissionGranted: false),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await openNotifications(tester);

    // Show the denied note too, the longest block on the screen.
    await tester.ensureVisible(switchFor('Session reminder'));
    await tester.pumpAndSettle();
    await tester.tap(switchFor('Session reminder'));
    await tester.pumpAndSettle();
    // The note sits at the top of the list, the help text at the bottom.
    await tester.drag(find.byType(ListView).last, const Offset(0, 3000));
    await tester.pumpAndSettle();
    expect(find.textContaining('Notifications are turned off'), findsOneWidget);
    await tester.drag(find.byType(ListView).last, const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Reminders not arriving?'), findsOneWidget);
  });
}
