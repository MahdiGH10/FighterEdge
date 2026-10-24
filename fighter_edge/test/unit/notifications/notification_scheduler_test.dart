import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/notification_copy.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_scheduler.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';
import 'notification_test_helpers.dart';

/// The reconciler against a fake gateway and a fake clock: `now` is passed in,
/// so every case here is a fixed moment (Monday 1 June 2026, 09:00).
void main() {
  late FakeReminderGateway gateway;
  late NotificationScheduler scheduler;

  final en = NotificationCopy.forLocale(const Locale('en'));
  final de = NotificationCopy.forLocale(const Locale('de'));

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    gateway = FakeReminderGateway(allowed: true);
    scheduler = NotificationScheduler(
      gateway: gateway,
      historyStore: NotificationHistoryStore(),
    );
  });

  Future<ReconcileResult> reconcile({
    DateTime? at,
    NotificationSettings? settings,
    NotificationInputs? inputs,
    NotificationCopy? copy,
    bool signedIn = true,
    bool allowed = true,
  }) =>
      scheduler.reconcile(
        now: at ?? now,
        settings: settings ?? on([NotificationChannel.sessionReminder]),
        inputs: inputs ??
            NotificationInputs(
              sessions: [for (var i = 0; i < 21; i++) session(i)],
              ageYears: 30,
            ),
        copy: copy ?? en,
        signedIn: signedIn,
        systemAllowed: allowed,
      );

  test('schedules the planner output with localized words and a route only',
      () async {
    final result = await reconcile();

    expect(result.scheduled, isNotEmpty);
    expect(
        gateway.pending.keys.toSet(), {for (final n in result.scheduled) n.id});
    final first = gateway.pending.values.first;
    expect(first.channel, NotificationChannel.sessionReminder);
    expect(first.fireAt, day(0, 17));
    expect(first.title, 'Your session is coming up');
    expect(first.body, contains('6:00 PM'));
    expect(first.route, matches(RegExp(r'^/train/session/s-\d+$')));
  });

  test('nothing is scheduled beyond seven days', () async {
    await reconcile();
    final limit = now.add(const Duration(days: 7));
    expect(gateway.pending, isNotEmpty);
    for (final r in gateway.pending.values) {
      expect(r.fireAt.isAfter(now), isTrue);
      expect(r.fireAt.isAfter(limit), isFalse, reason: '${r.fireAt}');
    }
  });

  test('running it again and again leaves exactly the same set', () async {
    await reconcile();
    final first = Map.of(gateway.pending);
    for (var i = 0; i < 4; i++) {
      await reconcile();
    }
    expect(gateway.pending.keys.toSet(), first.keys.toSet());
    expect(gateway.replaceCalls, 5);
  });

  test('turning the channel off, or pausing all, empties the schedule',
      () async {
    await reconcile();
    expect(gateway.pending, isNotEmpty);

    await reconcile(settings: on([]));
    expect(gateway.pending, isEmpty);

    await reconcile();
    expect(gateway.pending, isNotEmpty);
    await reconcile(
      settings: on([NotificationChannel.sessionReminder], pauseAll: true),
    );
    expect(gateway.pending, isEmpty);
  });

  test('a changed usual time or lead moves what is scheduled, same ids',
      () async {
    await reconcile();
    final ids = gateway.pending.keys.toSet();
    final before = gateway.pending.values.first.fireAt;

    await reconcile(
      settings: on(
        [NotificationChannel.sessionReminder],
        usualHour: 19,
        sessionLead: 30,
      ),
    );
    expect(gateway.pending.keys.toSet(), ids);
    expect(gateway.pending.values.first.fireAt, isNot(before));
    expect(gateway.pending.values.first.fireAt, day(0, 18, 30));
  });

  test('quiet hours keep a reminder out of the night', () async {
    await reconcile(
      settings: on(
        [NotificationChannel.sessionReminder],
        usualHour: 22,
        quiet: const QuietHours.hm(21, 0, 7, 0),
      ),
    );
    // A session at 22:00 with a reminder at 21:00 sits inside quiet hours and
    // cannot move to 07:00 the next morning without passing the session.
    expect(gateway.pending, isEmpty);
  });

  test('the words follow the app language', () async {
    await reconcile(copy: de);
    expect(gateway.pending.values.first.title, 'Deine Einheit steht bevor');
    expect(gateway.pending.values.first.body, contains('18:00'));
  });

  test('signed out leaves nothing scheduled and nothing remembered', () async {
    await reconcile();
    expect(gateway.pending, isNotEmpty);

    final result = await reconcile(signedIn: false);
    expect(gateway.pending, isEmpty);
    expect(gateway.cancelAllCalls, 1);
    expect(result.scheduled, isEmpty);
    expect((await NotificationHistoryStore().load()).scheduled, isEmpty);
  });

  test('a refused system permission leaves nothing scheduled', () async {
    await reconcile();
    await reconcile(allowed: false);
    expect(gateway.pending, isEmpty);
  });

  test('a notification that fired is remembered and not planned again',
      () async {
    final first = await reconcile();
    final fired = first.scheduled.first;

    // After its time: it is now history, and today has used its one slot.
    final result =
        await reconcile(at: fired.fireAt.add(const Duration(minutes: 5)));
    expect(result.ledger.delivered.map((d) => d.id), contains(fired.id));
    expect(gateway.pending.keys, isNot(contains(fired.id)));
    expect(
      gateway.pending.values.where((r) => r.fireAt.day == fired.fireAt.day),
      isEmpty,
    );
  });

  // Three days of sessions, then a gap, then one more: the reminders for the
  // first three fire and go unopened.
  final threeThenOne = NotificationInputs(
    sessions: [
      for (final i in [0, 1, 2, 6]) session(i)
    ],
    ageYears: 30,
  );

  test('three unopened in a row pause the channel and flag it', () async {
    await reconcile(inputs: threeThenOne);
    // The latest reminder is still inside its 24 hours: it could yet be
    // opened, so nothing is paused.
    var result = await reconcile(at: day(3, 12), inputs: threeThenOne);
    expect(result.autoPaused, isEmpty);

    result = await reconcile(at: day(4, 18), inputs: threeThenOne);
    expect(result.autoPaused, {NotificationChannel.sessionReminder});
    expect(
      gateway.pending.values.where(
        (r) => r.channel == NotificationChannel.sessionReminder,
      ),
      isEmpty,
    );
  });

  test('opened notifications keep the channel alive', () async {
    final first = await reconcile(inputs: threeThenOne);
    final ids = [for (final n in first.scheduled.take(3)) n.id];
    await reconcile(at: day(3, 12), inputs: threeThenOne);
    for (final id in ids) {
      await scheduler.recordOpened(id, day(3, 12));
    }
    final result = await reconcile(at: day(4, 18), inputs: threeThenOne);
    expect(result.autoPaused, isEmpty);
    expect(gateway.pending, isNotEmpty);
  });

  test('forgetting a channel after the question lets it plan again', () async {
    await reconcile(inputs: threeThenOne);
    await reconcile(at: day(3, 12), inputs: threeThenOne);
    var result = await reconcile(at: day(4, 18), inputs: threeThenOne);
    expect(result.autoPaused, isNotEmpty);

    await scheduler.clearChannel(
        NotificationChannel.sessionReminder, day(4, 18));
    result = await reconcile(at: day(4, 18), inputs: threeThenOne);
    expect(result.autoPaused, isEmpty);
    expect(gateway.pending, isNotEmpty);
  });

  test('no payload ever holds data, only a route', () async {
    await reconcile(
      settings: allOn,
      inputs: NotificationInputs(
        sessions: [for (var i = 0; i < 14; i++) session(i)],
        ageYears: 30,
      ),
    );
    for (final r in gateway.pending.values) {
      expect(r.route, startsWith('/'));
      expect(r.route, isNot(contains('?')));
      expect(r.route, isNot(contains('=')));
    }
  });
}
