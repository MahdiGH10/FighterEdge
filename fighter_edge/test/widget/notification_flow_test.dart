import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_settings_store.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/state/first_run_controller.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

import '../helpers/test_harness.dart';

/// The notification flows that cross screens, through the real app: the
/// primer after the first win, a tap on a delivered notification, and the one
/// question after a channel went quiet.
void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  FoodLogEntry meal(String id) => FoodLogEntry(
        id: id,
        name: 'Oats',
        notes: '',
        calories: 350,
        proteinGrams: 12,
        carbGrams: 60,
        fatGrams: 6,
        source: FoodLogSource.manual,
        loggedAt: DateTime.now(),
      );

  Future<void> bootFirstWeek(
    WidgetTester tester,
    ReminderGateway reminders,
  ) async {
    useTallScreen(tester);
    final repo = await makeRepo(
      signedIn: true,
      onboarded: true,
      plan: Plan.pro,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fe_first_run.${repo.currentUser!.id}.active', true);
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pumpAndSettle();
  }

  Future<BuildContext> logFirstMeal(WidgetTester tester) async {
    final shell = tester.element(find.byType(HomeShell));
    await shell.read<EdgeFuelController>().addEntry(meal('m1'));
    await tester.pumpAndSettle();
    expect(find.text('First meal logged.'), findsOneWidget);
    await tester.tap(find.text('Keep going'));
    await tester.pumpAndSettle();
    return shell;
  }

  group('the primer after the first win', () {
    testWidgets('Not now asks nothing of the OS and is never asked again',
        (tester) async {
      final reminders = FakeReminderGateway();
      await bootFirstWeek(tester, reminders);
      final shell = await logFirstMeal(tester);

      expect(find.text('Want a reminder before your next session?'),
          findsOneWidget);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();

      expect(reminders.permissionRequests, 0);
      expect(shell.read<FirstRunController>().remindersAsked, isTrue);
      expect(
        shell.read<NotificationController>().settings.enabledChannels,
        isEmpty,
      );

      // A second meal is just a meal: no sheet, no prompt.
      await shell.read<EdgeFuelController>().addEntry(meal('m2'));
      await tester.pumpAndSettle();
      expect(
          find.text('Want a reminder before your next session?'), findsNothing);
    });

    testWidgets('a swipe away counts as an answer', (tester) async {
      final reminders = FakeReminderGateway();
      await bootFirstWeek(tester, reminders);
      final shell = await logFirstMeal(tester);
      expect(shell.read<FirstRunController>().remindersAsked, isTrue);
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(
          find.text('Want a reminder before your next session?'), findsNothing);
      expect(reminders.permissionRequests, 0);
    });

    testWidgets('a refused OS prompt leaves the channel off and stays calm',
        (tester) async {
      final reminders = FakeReminderGateway(permissionGranted: false);
      await bootFirstWeek(tester, reminders);
      final shell = await logFirstMeal(tester);

      await tester.tap(find.text('Yes, remind me'));
      await tester.pumpAndSettle();

      final controller = shell.read<NotificationController>();
      expect(reminders.permissionRequests, 1);
      expect(controller.settings.enabledChannels, isEmpty);
      expect(controller.showPermissionNote, isTrue);
      expect(find.byType(SnackBar), findsNothing);
      expect(
          find.text('Want a reminder before your next session?'), findsNothing);
    });

    testWidgets('it is not offered where reminders cannot fire',
        (tester) async {
      final reminders = FakeReminderGateway()..available = false;
      await bootFirstWeek(tester, reminders);
      await tester
          .element(find.byType(HomeShell))
          .read<EdgeFuelController>()
          .addEntry(meal('m1'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keep going'));
      await tester.pumpAndSettle();
      expect(
          find.text('Want a reminder before your next session?'), findsNothing);
      expect(reminders.permissionRequests, 0);
    });

    testWidgets('nothing asks for permission before the first win',
        (tester) async {
      final reminders = FakeReminderGateway();
      await bootFirstWeek(tester, reminders);
      await tester.pump(const Duration(seconds: 2));
      expect(reminders.permissionRequests, 0);
      expect(
          find.text('Want a reminder before your next session?'), findsNothing);
    });
  });

  group('tapping a notification', () {
    Future<void> boot(WidgetTester tester, FakeReminderGateway gateway) async {
      useTallScreen(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await tester.pumpWidget(
        FighterEdgeApp(authRepo: repo, reminderGateway: gateway),
      );
      await tester.pumpAndSettle();
    }

    int tab(WidgetTester tester) =>
        tester.widget<AppBottomNav>(find.byType(AppBottomNav)).currentIndex;

    testWidgets('opens the tab the route names', (tester) async {
      final gateway = FakeReminderGateway();
      await boot(tester, gateway);
      expect(tab(tester), 0);

      gateway.tapController.add(const NotificationTap(id: 1, route: '/fuel'));
      await tester.pumpAndSettle();
      expect(tab(tester), 2);

      gateway.tapController.add(const NotificationTap(id: 2, route: '/review'));
      await tester.pumpAndSettle();
      expect(tab(tester), 1);

      gateway.tapController.add(const NotificationTap(id: 3, route: '/home'));
      await tester.pumpAndSettle();
      expect(tab(tester), 0);
    });

    testWidgets('a route outside the fixed set does nothing', (tester) async {
      final gateway = FakeReminderGateway();
      await boot(tester, gateway);
      gateway.tapController
          .add(const NotificationTap(id: 1, route: '/settings'));
      gateway.tapController
          .add(const NotificationTap(id: 2, route: 'https://example.com'));
      await tester.pumpAndSettle();
      expect(tab(tester), 0);
    });

    testWidgets('the tap that launched the app opens its tab', (tester) async {
      final gateway = FakeReminderGateway()
        ..launchTap = const NotificationTap(id: 9, route: '/fuel');
      await boot(tester, gateway);
      expect(tab(tester), 2);
    });
  });

  group('the question after a channel went quiet', () {
    Future<FakeReminderGateway> bootPaused(WidgetTester tester) async {
      useTallScreen(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      await prefs.setString(
        NotificationSettingsStore.settingsKey,
        NotificationSettingsStore.encode(NotificationSettings(
          enabledChannels: {NotificationChannel.sessionReminder},
        )),
      );
      await prefs.setString(
        NotificationHistoryStore.key,
        NotificationHistoryStore.encode(NotificationLedger(delivered: [
          for (var i = 0; i < 3; i++)
            DeliveredEntry(
              id: 100 + i,
              channel: NotificationChannel.sessionReminder,
              firedAt: now.subtract(Duration(days: 12 - i)),
              ignored: true,
            ),
        ])),
      );
      final gateway = FakeReminderGateway(allowed: true);
      await tester.pumpWidget(
        FighterEdgeApp(authRepo: repo, reminderGateway: gateway),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      return gateway;
    }

    testWidgets('asks once, and keeping the channel brings it back',
        (tester) async {
      final gateway = await bootPaused(tester);
      expect(find.text('Keep these reminders?'), findsOneWidget);
      expect(gateway.pending, isEmpty);

      await tester.tap(find.text('Keep them'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(find.text('Keep these reminders?'), findsNothing);
      final controller =
          tester.element(find.byType(HomeShell)).read<NotificationController>();
      expect(controller.settings.isEnabled(NotificationChannel.sessionReminder),
          isTrue);
      expect(controller.channelToConfirm, isNull);
    });

    testWidgets('turning it off switches the channel off', (tester) async {
      await bootPaused(tester);
      expect(find.text('Keep these reminders?'), findsOneWidget);

      await tester.tap(find.text('Turn off'));
      await tester.pumpAndSettle();

      final controller =
          tester.element(find.byType(HomeShell)).read<NotificationController>();
      expect(controller.settings.isEnabled(NotificationChannel.sessionReminder),
          isFalse);
      expect(find.text('Keep these reminders?'), findsNothing);
    });
  });
}
