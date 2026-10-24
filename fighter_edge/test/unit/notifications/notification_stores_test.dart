import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_history.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/domain/planned_notification.dart';
import 'package:fighter_edge/notifications/notification_history_store.dart';
import 'package:fighter_edge/notifications/notification_settings_store.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime at(int day, [int hour = 0, int minute = 0]) =>
    DateTime(2026, 6, day, hour, minute);

PlannedNotification planned(
  NotificationChannel channel,
  DateTime fireAt, {
  String key = 'x',
}) =>
    PlannedNotification(
      id: PlannedNotification.stableId(channel, fireAt, key),
      channel: channel,
      fireAt: fireAt,
      contentKey: 'notif.review.weekly',
      route: '/review',
    );

void main() {
  group('settings store', () {
    test('a fresh device reads as all off', () async {
      SharedPreferences.setMockInitialValues({});
      final settings = await NotificationSettingsStore().load();
      expect(settings, NotificationSettings());
      expect(settings.enabledChannels, isEmpty);
    });

    test('settings round trip', () async {
      SharedPreferences.setMockInitialValues({});
      final store = NotificationSettingsStore();
      final saved = NotificationSettings(
        enabledChannels: {
          NotificationChannel.sessionReminder,
          NotificationChannel.weeklyReview,
        },
        usualTrainingHour: 6,
        usualTrainingMinute: 45,
        sessionLeadMinutes: 90,
        quietHours: const QuietHours.hm(22, 30, 6, 15),
        pauseAll: true,
        pausedUntil: {NotificationChannel.weeklyReview: at(20, 8)},
      );
      await store.save(saved);
      expect(await store.load(), saved);
    });

    test('camp reminders on becomes the session reminder at 18:00, once',
        () async {
      SharedPreferences.setMockInitialValues({
        NotificationSettingsStore.legacyCampRemindersKey: true,
      });
      final store = NotificationSettingsStore();
      final migrated = await store.load();
      expect(migrated.isEnabled(NotificationChannel.sessionReminder), isTrue);
      expect(migrated.enabledChannels, hasLength(1));
      expect(migrated.usualTrainingHour, 18);
      expect(migrated.usualTrainingMinute, 0);

      // The old switch is gone and never read again.
      final prefs = await SharedPreferences.getInstance();
      expect(
          prefs.containsKey(NotificationSettingsStore.legacyCampRemindersKey),
          isFalse);
      await prefs.setBool(
          NotificationSettingsStore.legacyCampRemindersKey, true);
      await store.save(migrated.withChannel(
        NotificationChannel.sessionReminder,
        false,
      ));
      final later = await NotificationSettingsStore().load();
      expect(later.enabledChannels, isEmpty);
    });

    test('camp reminders off migrates to everything off', () async {
      SharedPreferences.setMockInitialValues({
        NotificationSettingsStore.legacyCampRemindersKey: false,
      });
      final settings = await NotificationSettingsStore().load();
      expect(settings.enabledChannels, isEmpty);
    });

    test('bad, unknown-version or hostile values read as defaults', () async {
      for (final raw in [
        'not json',
        '[]',
        '{"v": 99, "enabled": ["sessionReminder"]}',
        '{"v": 1, "enabled": "nope", "usualHour": "x"}',
      ]) {
        SharedPreferences.setMockInitialValues({
          NotificationSettingsStore.settingsKey: raw,
        });
        final settings = await NotificationSettingsStore().load();
        expect(settings.enabledChannels, isEmpty, reason: raw);
        expect(settings.usualTrainingHour, 18, reason: raw);
      }
    });

    test('out-of-range numbers and unknown channels are ignored', () {
      final settings = NotificationSettingsStore.decode(
        '{"v":1,"enabled":["sessionReminder","teleport"],'
        '"usualHour":99,"usualMinute":-3,"sessionLead":5000,'
        '"quietStart":5000,"quietEnd":7,"pausedUntil":{"nope":"2026-06-01"}}',
      )!;
      expect(settings.enabledChannels, {NotificationChannel.sessionReminder});
      expect(settings.usualTrainingHour, 18);
      expect(settings.usualTrainingMinute, 0);
      expect(settings.sessionLeadMinutes, 60);
      expect(settings.quietHours.startMinute, 21 * 60);
      expect(settings.quietHours.endMinute, 7);
      expect(settings.pausedUntil, isEmpty);
    });

    test('the stored value carries a version and no content', () {
      final raw = NotificationSettingsStore.encode(NotificationSettings());
      expect(raw, contains('"v":1'));
    });

    test('permission asked is remembered', () async {
      SharedPreferences.setMockInitialValues({});
      final store = NotificationSettingsStore();
      expect(await store.loadPermissionRequested(), isFalse);
      await store.savePermissionRequested(true);
      expect(await store.loadPermissionRequested(), isTrue);
    });
  });

  group('ledger', () {
    test('a scheduled notification counts as delivered once its time passes',
        () {
      final ledger = const NotificationLedger().withScheduled([
        planned(NotificationChannel.weeklyReview, at(7, 18)),
      ]);
      expect(ledger.settle(at(7, 17)).delivered, isEmpty);
      expect(ledger.settle(at(7, 17)).scheduled, hasLength(1));
      final after = ledger.settle(at(7, 19));
      expect(after.scheduled, isEmpty);
      expect(after.delivered.single.firedAt, at(7, 18));
      expect(after.delivered.single.ignored, isFalse);
    });

    test('unopened for more than 24 hours is ignored; opened never is', () {
      final plan = [
        planned(NotificationChannel.weeklyReview, at(7, 18), key: 'a'),
        planned(NotificationChannel.sessionReminder, at(7, 18), key: 'b'),
      ];
      var ledger = const NotificationLedger().withScheduled(plan);
      ledger = ledger.settle(at(7, 19));
      ledger = ledger.opened(plan.first.id, at(7, 19));

      final soon = ledger.settle(at(8, 17, 59));
      expect(soon.delivered.where((d) => d.ignored), isEmpty);

      final later = ledger.settle(at(8, 18, 1));
      final byChannel = {for (final d in later.delivered) d.channel: d};
      expect(byChannel[NotificationChannel.weeklyReview]!.ignored, isFalse);
      expect(byChannel[NotificationChannel.weeklyReview]!.opened, isTrue);
      expect(byChannel[NotificationChannel.sessionReminder]!.ignored, isTrue);
    });

    test('a tap that beats the settle still counts as opened', () {
      final n = planned(NotificationChannel.sessionReminder, at(7, 17));
      final ledger = const NotificationLedger()
          .withScheduled([n]).opened(n.id, at(7, 17, 5));
      expect(ledger.scheduled, isEmpty);
      expect(ledger.delivered.single.opened, isTrue);
    });

    test('a tap on an unknown id changes nothing', () {
      final ledger = const NotificationLedger().opened(42, at(7));
      expect(ledger.delivered, isEmpty);
      expect(ledger.scheduled, isEmpty);
    });

    test('three ignored in a row auto-pause the channel; an open resets it',
        () {
      NotificationLedger run(List<bool> opens) {
        final plan = [
          for (var i = 0; i < opens.length; i++)
            planned(NotificationChannel.sessionReminder, at(1 + i, 17),
                key: 's$i'),
        ];
        var ledger = const NotificationLedger().withScheduled(plan);
        ledger = ledger.settle(at(1 + opens.length, 0));
        for (var i = 0; i < opens.length; i++) {
          if (opens[i]) ledger = ledger.opened(plan[i].id, at(1 + i, 17, 5));
        }
        return ledger.settle(at(20));
      }

      final now = at(20);
      expect(
        autoPausedChannels(run([false, false, false]).toHistory(), now),
        {NotificationChannel.sessionReminder},
      );
      expect(
        autoPausedChannels(run([false, false]).toHistory(), now),
        isEmpty,
      );
      expect(
        autoPausedChannels(run([false, false, true, false]).toHistory(), now),
        isEmpty,
      );
    });

    test('forgetting a channel starts its count again', () {
      final plan = [
        for (var i = 0; i < 3; i++)
          planned(NotificationChannel.weeklyReview, at(1 + i, 18), key: '$i'),
      ];
      final ledger = const NotificationLedger()
          .withScheduled(plan)
          .settle(at(10))
          .withoutChannel(NotificationChannel.weeklyReview);
      expect(ledger.delivered, isEmpty);
      expect(autoPausedChannels(ledger.toHistory(), at(10)), isEmpty);
    });

    test('on-device counts say sent, opened and ignored', () {
      final plan = [
        planned(NotificationChannel.weeklyReview, at(1, 18), key: 'a'),
        planned(NotificationChannel.weeklyReview, at(2, 18), key: 'b'),
      ];
      final ledger = const NotificationLedger()
          .withScheduled(plan)
          .settle(at(2, 19))
          .opened(plan.first.id, at(2, 19))
          .settle(at(5));
      final counts = ledger.countsFor(NotificationChannel.weeklyReview);
      expect(counts.sent, 2);
      expect(counts.opened, 1);
      expect(counts.ignored, 1);
    });

    test('old and surplus records are trimmed', () {
      final plan = [
        for (var i = 0; i < 150; i++)
          PlannedNotification(
            id: i,
            channel: NotificationChannel.fighterTip,
            fireAt: DateTime(2026, 6, 1).add(Duration(hours: i)),
            contentKey: 'notif.tip.0',
            route: '/home',
          ),
      ];
      final ledger = const NotificationLedger()
          .withScheduled(plan)
          .settle(DateTime(2026, 6, 20));
      expect(ledger.delivered.length, NotificationLedger.maxDelivered);
      final old = const NotificationLedger().withScheduled([
        planned(NotificationChannel.fighterTip, at(1))
      ]).settle(DateTime(2026, 12, 1));
      expect(old.delivered, isEmpty);
    });
  });

  group('history store', () {
    test('the ledger round trips and keeps only ids, channels and times',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = NotificationHistoryStore();
      final n = planned(NotificationChannel.weeklyReview, at(7, 18));
      final ledger = const NotificationLedger()
          .withScheduled([n])
          .settle(at(8))
          .opened(n.id, at(8))
          .withScheduled(
              [planned(NotificationChannel.sessionReminder, at(12, 17))]);
      await store.save(ledger);

      final raw = (await SharedPreferences.getInstance())
          .getString(NotificationHistoryStore.key)!;
      expect(raw, isNot(contains('notif.')));
      expect(raw, isNot(contains('/review')));

      final loaded = await store.load();
      expect(loaded.delivered.single.opened, isTrue);
      expect(loaded.delivered.single.firedAt, at(7, 18));
      expect(loaded.scheduled.single.fireAt, at(12, 17));
    });

    test('missing, bad or newer values read as empty', () async {
      for (final raw in [null, 'nope', '{"v":9}', '[1]']) {
        SharedPreferences.setMockInitialValues({
          if (raw != null) NotificationHistoryStore.key: raw,
        });
        final ledger = await NotificationHistoryStore().load();
        expect(ledger.delivered, isEmpty, reason: '$raw');
        expect(ledger.scheduled, isEmpty, reason: '$raw');
      }
    });
  });
}
