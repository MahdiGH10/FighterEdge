import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/widgets/stat_card.dart';
import 'package:provider/provider.dart';

import '../helpers/test_harness.dart';

/// The "Camp reminders" switch in Settings, driven through the real app so
/// the permission request and scheduling call are exercised end to end.
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  Finder remindersSwitch() => find.descendant(
        of: find.ancestor(
          of: find.text('Camp reminders'),
          matching: find.byType(AppCard),
        ),
        matching: find.byType(Switch),
      );

  testWidgets('granting permission turns reminders on and schedules them',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final reminders = FakeReminderGateway();
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pump();
    await openSettings(tester);

    await tester.tap(remindersSwitch());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(remindersSwitch()).value, isTrue);
    expect(reminders.permissionRequests, 1);
    expect(reminders.scheduledWeekdays, isNotNull);
    final state = tester.element(find.byType(SettingsScreen)).read<AppState>();
    expect(state.campReminders, isTrue);
  });

  testWidgets('a denied permission leaves the switch off and explains why',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final reminders = FakeReminderGateway(permissionGranted: false);
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pump();
    await openSettings(tester);

    await tester.tap(remindersSwitch());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(remindersSwitch()).value, isFalse);
    expect(reminders.scheduledWeekdays, isNull);
    expect(
      find.textContaining('Notifications are turned off for Fighter Edge'),
      findsOneWidget,
    );
    final state = tester.element(find.byType(SettingsScreen)).read<AppState>();
    expect(state.campReminders, isFalse);
  });

  testWidgets('turning reminders off cancels what was scheduled',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final reminders = FakeReminderGateway();
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pump();
    await openSettings(tester);

    await tester.tap(remindersSwitch());
    await tester.pumpAndSettle();
    expect(reminders.scheduledWeekdays, isNotNull);

    await tester.tap(remindersSwitch());
    await tester.pumpAndSettle();

    expect(tester.widget<Switch>(remindersSwitch()).value, isFalse);
    expect(reminders.cancelled, isTrue);
  });
}
