import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/local_reminder_gateway.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// The real gateway against a fake plugin channel, as Android: what it
/// schedules, what it cancels, what it leaves alone.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pluginChannel =
      MethodChannel('dexterous.com/flutter/local_notifications');
  const zoneChannel = MethodChannel('flutter_timezone');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  /// What the "OS" holds, keyed by id. The plugin turns a null payload into ''.
  late Map<int, Map<String, Object?>> os;
  late List<int> cancelled;
  late List<Map<Object?, Object?>> scheduleCalls;
  late String zone;
  late bool notificationsEnabled;
  late bool throwOnSchedule;

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    os = {};
    cancelled = [];
    scheduleCalls = [];
    zone = 'UTC';
    notificationsEnabled = true;
    throwOnSchedule = false;

    messenger.setMockMethodCallHandler(pluginChannel, (call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'pendingNotificationRequests':
          return [for (final p in os.values) Map<String, Object?>.of(p)];
        case 'zonedSchedule':
          if (throwOnSchedule) throw PlatformException(code: 'boom');
          scheduleCalls.add(Map.of(args));
          os[args['id'] as int] = {
            'id': args['id'],
            'title': args['title'],
            'body': args['body'],
            'payload': args['payload'],
          };
          return null;
        case 'cancel':
          cancelled.add(args['id'] as int);
          os.remove(args['id']);
          return null;
        case 'areNotificationsEnabled':
          return notificationsEnabled;
        case 'requestNotificationsPermission':
          return notificationsEnabled;
        case 'getNotificationAppLaunchDetails':
          return null;
        case 'initialize':
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(zoneChannel, (call) async {
      if (call.method == 'getLocalTimezone') return {'identifier': zone};
      return null;
    });
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(pluginChannel, null);
    messenger.setMockMethodCallHandler(zoneChannel, null);
  });

  DateTime inDays(int days, [int hour = 17, int minute = 0]) {
    final t = DateTime.now().add(Duration(days: days));
    return DateTime(t.year, t.month, t.day, hour, minute);
  }

  ScheduledReminder reminder(
    int id,
    DateTime at, {
    NotificationChannel channel = NotificationChannel.sessionReminder,
    String route = '/train/session/s-1',
  }) =>
      ScheduledReminder(
        id: id,
        channel: channel,
        fireAt: at,
        title: 'Title $id',
        body: 'Body $id',
        route: route,
      );

  /// The wall-clock text the plugin was given for [id].
  String wallTime(int id) =>
      scheduleCalls.lastWhere((c) => c['id'] == id)['scheduledDateTime']
          as String;

  String stamp(DateTime t) =>
      '${t.year.toString().padLeft(4, '0')}-${t.month.toString().padLeft(2, '0')}-'
      '${t.day.toString().padLeft(2, '0')}T'
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  test('schedules each reminder under its id with a route-only payload',
      () async {
    final gateway = LocalReminderGateway();
    final at = inDays(2);
    await gateway.replaceScheduled([
      reminder(111, at),
      reminder(222, inDays(3, 18), route: '/review'),
    ]);

    expect(os.keys.toSet(), {111, 222});
    expect(os[111]!['payload'], '/train/session/s-1');
    expect(os[111]!['title'], 'Title 111');
    expect(os[222]!['payload'], '/review');
    // Wall-clock time is kept as given.
    expect(wallTime(111), stamp(at));
  });

  test('is inexact and allow-while-idle, never exact', () async {
    await LocalReminderGateway().replaceScheduled([reminder(1, inDays(2))]);
    final specifics = scheduleCalls.single['platformSpecifics'] as Map;
    expect(specifics['scheduleMode'], 'inexactAllowWhileIdle');
  });

  test('a repeat run replaces rather than duplicates', () async {
    final gateway = LocalReminderGateway();
    final plan = [reminder(111, inDays(2)), reminder(222, inDays(3))];
    await gateway.replaceScheduled(plan);
    await gateway.replaceScheduled(plan);
    await gateway.replaceScheduled(plan);
    expect(os.keys.toSet(), {111, 222});
    expect(os, hasLength(2));
  });

  test('cancels plan-owned reminders that are no longer wanted', () async {
    // Left over from an earlier plan.
    os[111] = {'id': 111, 'title': 'old', 'body': '', 'payload': '/review'};
    os[999] = {'id': 999, 'title': 'old', 'body': '', 'payload': '/home'};

    await LocalReminderGateway().replaceScheduled([reminder(111, inDays(2))]);

    expect(os.keys.toSet(), {111});
    expect(cancelled, contains(999));
    expect(cancelled, isNot(contains(111)));
  });

  test('clears what older versions scheduled directly, so nobody gets two',
      () async {
    // The weekly training reminders, and the trial-end reminder that the
    // planner owns now.
    os[6103] = {'id': 6103, 'title': 'weekly', 'body': '', 'payload': ''};
    os[6200] = {'id': 6200, 'title': 'trial', 'body': '', 'payload': ''};

    await LocalReminderGateway().replaceScheduled([reminder(111, inDays(2))]);

    expect(os.keys.toSet(), {111});
    expect(cancelled, contains(6103));
    expect(cancelled, contains(6200));
    // Every legacy weekday id is cleared, so nobody gets both kinds.
    for (var weekday = 1; weekday <= 7; weekday++) {
      expect(cancelled, contains(6100 + weekday));
    }
  });

  test('an empty plan clears the plan-owned set', () async {
    os[111] = {'id': 111, 'title': 'x', 'body': '', 'payload': '/home'};
    await LocalReminderGateway().replaceScheduled(const []);
    expect(os, isEmpty);
  });

  test('cancelAll clears plan-owned and legacy notifications', () async {
    os[111] = {'id': 111, 'title': 'x', 'body': '', 'payload': '/home'};
    os[6101] = {'id': 6101, 'title': 'weekly', 'body': '', 'payload': ''};
    os[6200] = {'id': 6200, 'title': 'trial', 'body': '', 'payload': ''};
    await LocalReminderGateway().cancelAll();
    expect(os, isEmpty);
  });

  test('never schedules more than the iOS limit allows, soonest first',
      () async {
    final plan = [
      for (var i = 0; i < 80; i++)
        reminder(1000 + i, inDays(1).add(Duration(hours: i))),
    ];
    await LocalReminderGateway().replaceScheduled(plan);
    expect(os.length, lessThanOrEqualTo(64));
    expect(os.length, 60);
    expect(os.keys, contains(1000));
    expect(os.keys, isNot(contains(1079)));
  });

  test('the device time zone is read again on every run', () async {
    final gateway = LocalReminderGateway();
    final at = inDays(2);

    zone = 'Asia/Tokyo';
    await gateway.replaceScheduled([reminder(1, at)]);
    expect(scheduleCalls.last['timeZoneName'], 'Asia/Tokyo');
    expect(wallTime(1), stamp(at));

    // The athlete lands somewhere else; the next reconcile moves the
    // reminder to the same wall-clock time in the new zone.
    zone = 'America/New_York';
    await gateway.replaceScheduled([reminder(1, at)]);
    expect(scheduleCalls.last['timeZoneName'], 'America/New_York');
    expect(wallTime(1), stamp(at));
    expect(os.keys.toSet(), {1});
  });

  test('wall-clock time survives a daylight-saving change', () async {
    final gateway = LocalReminderGateway();
    zone = 'Europe/Berlin';
    // A winter day and a summer day, both at 17:00 local.
    final now = DateTime.now();
    final winter = DateTime(now.year + 1, 1, 15, 17);
    final summer = DateTime(now.year + 1, 7, 15, 17);
    await gateway.replaceScheduled([reminder(1, winter), reminder(2, summer)]);
    expect(wallTime(1), stamp(winter));
    expect(wallTime(2), stamp(summer));
    // The ISO form carries the real offset: +0100 in winter, +0200 in summer.
    String iso(int id) => scheduleCalls
        .lastWhere((c) => c['id'] == id)['scheduledDateTimeISO8601'] as String;
    expect(iso(1), endsWith('+0100'));
    expect(iso(2), endsWith('+0200'));
  });

  test('a failing plugin never throws into the app', () async {
    throwOnSchedule = true;
    await LocalReminderGateway().replaceScheduled([reminder(1, inDays(2))]);
  });

  test('permission state is read without prompting', () async {
    final gateway = LocalReminderGateway();
    expect(await gateway.areNotificationsAllowed(), isTrue);
    notificationsEnabled = false;
    expect(await gateway.areNotificationsAllowed(), isFalse);
    expect(await gateway.requestPermission(), isFalse);
  });

  test('is unavailable off Android and iOS', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    expect(LocalReminderGateway().isAvailable, isFalse);
  });
}
