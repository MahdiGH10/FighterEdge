import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_route.dart';
import 'package:fighter_edge/notifications/notification_scheduler.dart';
import 'package:fighter_edge/notifications/notification_settings_store.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';
import 'notification_test_helpers.dart';

void main() {
  late FakeReminderGateway gateway;
  late DateTime clock;
  Locale locale = const Locale('en');
  var signedIn = true;

  NotificationInputs inputs() => NotificationInputs(
        sessions: [for (var i = 0; i < 21; i++) session(i)],
        ageYears: 30,
      );

  NotificationController build({FakeReminderGateway? with_}) {
    gateway = with_ ?? gateway;
    return NotificationController(
      gateway: gateway,
      now: () => clock,
      debounce: const Duration(milliseconds: 50),
    );
  }

  Future<void> attach(NotificationController c) => c.attach(
        readInputs: inputs,
        readLocale: () => locale,
        readSignedIn: () => signedIn,
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeReminderGateway();
    clock = now;
    locale = const Locale('en');
    signedIn = true;
  });

  group('where reminders cannot fire', () {
    test('it loads nothing, stores nothing and never schedules', () async {
      SharedPreferences.setMockInitialValues({
        NotificationSettingsStore.legacyCampRemindersKey: true,
      });
      final c = build(with_: FakeReminderGateway()..available = false);
      await c.load();
      await attach(c);
      c.requestReconcile();
      await c.reconcileNow();

      expect(c.isAvailable, isFalse);
      expect(c.settings.enabledChannels, isEmpty);
      expect(gateway.replaceCalls, 0);
      expect(gateway.permissionRequests, 0);
      // The old switch is left for a device that can use it.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool(NotificationSettingsStore.legacyCampRemindersKey),
          isTrue);
      expect(prefs.containsKey(NotificationSettingsStore.settingsKey), isFalse);
      c.dispose();
    });
  });

  group('first launch', () {
    test('everything is off and the OS is never asked', () async {
      final c = build();
      await c.load();
      await attach(c);
      await c.reconcileNow();

      expect(c.settings.enabledChannels, isEmpty);
      expect(gateway.permissionRequests, 0);
      expect(gateway.pending, isEmpty);
      expect(c.showPermissionNote, isFalse);
      c.dispose();
    });

    test('a device that had camp reminders keeps them as session reminders',
        () async {
      SharedPreferences.setMockInitialValues({
        NotificationSettingsStore.legacyCampRemindersKey: true,
      });
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      await c.reconcileNow();

      expect(c.settings.isEnabled(NotificationChannel.sessionReminder), isTrue);
      expect(c.settings.usualTrainingHour, 18);
      expect(gateway.pending, isNotEmpty);
      c.dispose();
    });
  });

  group('turning channels on', () {
    test('a yes asks the OS once, turns the channel on and schedules',
        () async {
      final c = build();
      await c.load();
      await attach(c);

      expect(
          await c.setChannelEnabled(NotificationChannel.sessionReminder, true),
          isTrue);
      await c.reconcileNow();

      expect(gateway.permissionRequests, 1);
      expect(gateway.provisionalRequests, 0);
      expect(c.settings.isEnabled(NotificationChannel.sessionReminder), isTrue);
      expect(gateway.pending, isNotEmpty);
      expect(c.showPermissionNote, isFalse);
      c.dispose();
    });

    test('a no leaves the channel off, schedules nothing and says where',
        () async {
      final c = build(with_: FakeReminderGateway(permissionGranted: false));
      await c.load();
      await attach(c);

      expect(
          await c.setChannelEnabled(NotificationChannel.sessionReminder, true),
          isFalse);
      await c.reconcileNow();

      expect(
          c.settings.isEnabled(NotificationChannel.sessionReminder), isFalse);
      expect(gateway.pending, isEmpty);
      expect(c.showPermissionNote, isTrue);
      c.dispose();
    });

    test('only the weekly review asks for the quiet iOS permission', () async {
      final c = build();
      await c.load();
      await c.setChannelEnabled(NotificationChannel.weeklyReview, true);
      expect(gateway.provisionalRequests, 1);

      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      expect(gateway.permissionRequests, 2);
      expect(gateway.provisionalRequests, 1);
      c.dispose();
    });

    test('the choice survives a restart', () async {
      var c = build();
      await c.load();
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      c.setUsualTime(7, 30);
      c.setSessionLead(30);
      c.setPauseAll(true);
      await Future<void>.delayed(Duration.zero);
      c.dispose();

      c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      expect(c.settings.isEnabled(NotificationChannel.sessionReminder), isTrue);
      expect(c.settings.usualTrainingHour, 7);
      expect(c.settings.usualTrainingMinute, 30);
      expect(c.settings.sessionLeadMinutes, 30);
      expect(c.settings.pauseAll, isTrue);
      c.dispose();
    });

    test('the system turning notifications off clears the schedule', () async {
      final c = build();
      await c.load();
      await attach(c);
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      expect(gateway.pending, isNotEmpty);

      gateway.allowed = false;
      await c.refreshPermission();
      await c.reconcileNow();
      expect(gateway.pending, isEmpty);
      expect(c.showPermissionNote, isTrue);

      gateway.allowed = true;
      await c.refreshPermission();
      await c.reconcileNow();
      expect(gateway.pending, isNotEmpty);
      expect(c.showPermissionNote, isFalse);
      c.dispose();
    });
  });

  group('reconciling', () {
    testWidgets('a burst of requests becomes one run', (tester) async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await tester.runAsync(() async {
        await c.load();
        await attach(c);
        await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      });
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      final before = gateway.replaceCalls;

      for (var i = 0; i < 10; i++) {
        c.requestReconcile();
        await tester.pump(const Duration(milliseconds: 10));
      }
      await tester.pump(const Duration(seconds: 1));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      expect(gateway.replaceCalls - before, 1);
      c.dispose();
    });

    test('a language change reschedules with the new words', () async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      expect(gateway.pending.values.first.title, 'Your session is coming up');

      locale = const Locale('de');
      await c.reconcileNow();
      expect(gateway.pending.values.first.title, 'Deine Einheit steht bevor');
      c.dispose();
    });

    test('signing out takes the schedule away, and keeps the settings',
        () async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      expect(gateway.pending, isNotEmpty);

      await c.clearScheduled();
      expect(gateway.pending, isEmpty);
      expect(c.settings.isEnabled(NotificationChannel.sessionReminder), isTrue);
      c.dispose();
    });

    test('signed out at reconcile time schedules nothing', () async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      signedIn = false;
      await c.reconcileNow();
      expect(gateway.pending, isEmpty);
      c.dispose();
    });

    test('a reconcile that throws never reaches the caller', () async {
      final c = NotificationController(
        gateway: _ThrowingGateway(),
        now: () => clock,
      );
      await c.load();
      await attach(c);
      await c.reconcileNow();
      c.dispose();
    });
  });

  group('taps', () {
    test('a tap records an open and hands over the route once', () async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      final n = gateway.pending.values.first;
      clock = n.fireAt.add(const Duration(minutes: 1));

      gateway.tapController.add(NotificationTap(id: n.id, route: n.route));
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(c.pendingRoute, n.route);
      expect(c.takePendingRoute(), n.route);
      expect(c.takePendingRoute(), isNull);

      final ledger = await NotificationHistoryStore().load();
      expect(ledger.delivered.single.id, n.id);
      expect(ledger.delivered.single.opened, isTrue);
      c.dispose();
    });

    test('the tap that launched the app is handled at start', () async {
      final c = build(
          with_: FakeReminderGateway(allowed: true)
            ..launchTap = const NotificationTap(id: 7, route: '/fuel'));
      await c.load();
      await attach(c);
      expect(c.takePendingRoute(), '/fuel');
      c.dispose();
    });

    test('a payload outside the fixed routes is ignored', () async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await attach(c);
      for (final bad in [
        'https://example.com',
        '/settings',
        '/train/session/../../etc',
        '/home?weight=80',
        '',
        null,
      ]) {
        gateway.tapController.add(NotificationTap(id: 1, route: bad));
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);
        expect(c.pendingRoute, isNull, reason: '$bad');
      }
      c.dispose();
    });

    test('routes map onto tabs', () {
      expect(NotificationRoute.parse('/home'), '/home');
      expect(NotificationRoute.parse('/train/session/2026-06-01.abc'),
          '/train/session/2026-06-01.abc');
      expect(
          NotificationRoute.destination('/fuel'), NotificationDestination.fuel);
      expect(
          NotificationRoute.destination('/home'), NotificationDestination.home);
      expect(NotificationRoute.destination('/review'),
          NotificationDestination.train);
      expect(NotificationRoute.destination('/train/session/s-1'),
          NotificationDestination.train);
    });
  });

  group('auto-pause question', () {
    NotificationInputs sparse() => NotificationInputs(
          sessions: [
            for (final i in [0, 1, 2, 6]) session(i)
          ],
          ageYears: 30,
        );

    Future<NotificationController> paused() async {
      final c = build(with_: FakeReminderGateway(allowed: true));
      await c.load();
      await c.attach(
        readInputs: sparse,
        readLocale: () => locale,
        readSignedIn: () => true,
      );
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      clock = day(3, 12);
      await c.reconcileNow();
      clock = day(4, 18);
      await c.reconcileNow();
      return c;
    }

    test(
        'three unopened in a row ask once; the channel stays paused until '
        'answered', () async {
      final c = await paused();
      expect(c.channelToConfirm, NotificationChannel.sessionReminder);
      expect(gateway.pending, isEmpty);

      c.markAsked(NotificationChannel.sessionReminder);
      expect(c.channelToConfirm, isNull);
      c.dispose();
    });

    test('keeping the channel starts its count again', () async {
      final c = await paused();
      await c.keepChannel(NotificationChannel.sessionReminder);
      await c.reconcileNow();
      expect(c.channelToConfirm, isNull);
      expect(c.settings.isEnabled(NotificationChannel.sessionReminder), isTrue);
      expect(gateway.pending, isNotEmpty);
      c.dispose();
    });

    test('turning it off switches the channel off and resets its count',
        () async {
      final c = await paused();
      await c.turnOffChannel(NotificationChannel.sessionReminder);
      await c.reconcileNow();
      expect(
          c.settings.isEnabled(NotificationChannel.sessionReminder), isFalse);
      expect(c.channelToConfirm, isNull);
      expect(gateway.pending, isEmpty);

      // Turning it on later starts clean.
      await c.setChannelEnabled(NotificationChannel.sessionReminder, true);
      await c.reconcileNow();
      expect(c.channelToConfirm, isNull);
      expect(gateway.pending, isNotEmpty);
      c.dispose();
    });
  });
}

class _ThrowingGateway extends FakeReminderGateway {
  @override
  Future<void> replaceScheduled(List<ScheduledReminder> reminders) =>
      throw StateError('boom');
}
