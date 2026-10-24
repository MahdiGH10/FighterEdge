import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_history.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/domain/planned_notification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_test_helpers.dart';

NotificationRecord _record(
  NotificationChannel channel,
  int dayOffset, {
  bool ignored = true,
  int hour = 17,
}) =>
    NotificationRecord(
      channel: channel,
      notificationId: dayOffset + 100,
      firedAt: day(dayOffset, hour),
      ignored: ignored,
    );

void main() {
  group('NotificationChannel', () {
    test('only fuel window, weigh-in and protein are nutrition channels', () {
      expect(
        NotificationChannel.values.where((c) => c.isNutrition).toSet(),
        {
          NotificationChannel.fuelWindow,
          NotificationChannel.weighIn,
          NotificationChannel.proteinGap,
        },
      );
    });

    test('only the trial notice is transactional', () {
      expect(
        NotificationChannel.values.where((c) => c.isTransactional),
        [NotificationChannel.trialEnding],
      );
    });

    test('priority runs fight, session, review, weigh-in, protein, tip', () {
      const order = [
        NotificationChannel.fightCountdown,
        NotificationChannel.sessionReminder,
        NotificationChannel.weeklyReview,
        NotificationChannel.weighIn,
        NotificationChannel.proteinGap,
        NotificationChannel.fighterTip,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(order[i - 1].priority, lessThan(order[i].priority));
      }
      expect(
        NotificationChannel.fuelWindow.priority,
        NotificationChannel.sessionReminder.priority,
      );
    });
  });

  group('NotificationSettings', () {
    test('the default object is all off with the documented defaults', () {
      final s = NotificationSettings();
      expect(s.enabledChannels, isEmpty);
      for (final c in NotificationChannel.values) {
        expect(s.isEnabled(c), isFalse);
      }
      expect(s.usualTrainingHour, 18);
      expect(s.usualTrainingMinute, 0);
      expect(s.sessionLeadMinutes, 60);
      expect(s.fuelWindowLeadMinutes, 150);
      expect(s.quietHours, const QuietHours.hm(21, 0, 7, 0));
      expect(s.pauseAll, isFalse);
      expect(s.pauseNutrition, isFalse);
      expect(s.pausedUntil, isEmpty);
    });

    test('copyWith changes only what it is given', () {
      final base = NotificationSettings();
      final changed = base.copyWith(
        enabledChannels: {NotificationChannel.weeklyReview},
        usualTrainingHour: 6,
        usualTrainingMinute: 45,
        sessionLeadMinutes: 30,
        fuelWindowLeadMinutes: 120,
        quietHours: const QuietHours.hm(22, 30, 6, 0),
        pauseAll: true,
        pauseNutrition: true,
        pausedUntil: {NotificationChannel.fighterTip: day(3)},
      );
      expect(changed.isEnabled(NotificationChannel.weeklyReview), isTrue);
      expect(changed.usualTrainingHour, 6);
      expect(changed.usualTrainingMinute, 45);
      expect(changed.sessionLeadMinutes, 30);
      expect(changed.fuelWindowLeadMinutes, 120);
      expect(changed.quietHours.startMinute, 22 * 60 + 30);
      expect(changed.pauseAll, isTrue);
      expect(changed.pauseNutrition, isTrue);
      expect(changed.pausedUntil[NotificationChannel.fighterTip], day(3));
      expect(base.copyWith(), base);
      expect(base.pauseAll, isFalse, reason: 'the original is untouched');
    });

    test('withChannel switches a channel on and off', () {
      final on1 = NotificationSettings()
          .withChannel(NotificationChannel.sessionReminder, true)
          .withChannel(NotificationChannel.fightCountdown, true);
      expect(on1.enabledChannels, {
        NotificationChannel.sessionReminder,
        NotificationChannel.fightCountdown,
      });
      final off = on1.withChannel(NotificationChannel.sessionReminder, false);
      expect(off.enabledChannels, {NotificationChannel.fightCountdown});
    });

    test('withPausedUntil sets and clears one channel', () {
      final paused = NotificationSettings()
          .withPausedUntil(NotificationChannel.weighIn, day(2))
          .withPausedUntil(NotificationChannel.proteinGap, day(3));
      expect(paused.pausedUntil, hasLength(2));
      final resumed = paused.withPausedUntil(NotificationChannel.weighIn, null);
      expect(resumed.pausedUntil, {NotificationChannel.proteinGap: day(3)});
      final moved = paused.withPausedUntil(NotificationChannel.weighIn, day(9));
      expect(moved.pausedUntil[NotificationChannel.weighIn], day(9));
    });

    test('it cannot be mutated through its collections', () {
      final s = NotificationSettings(
        enabledChannels: {NotificationChannel.weeklyReview},
        pausedUntil: {NotificationChannel.weighIn: day(1)},
      );
      expect(() => s.enabledChannels.add(NotificationChannel.fighterTip),
          throwsUnsupportedError);
      expect(() => s.pausedUntil.remove(NotificationChannel.weighIn),
          throwsUnsupportedError);
    });

    test('equal settings are equal and hash alike', () {
      NotificationSettings build() => NotificationSettings(
            enabledChannels: {
              NotificationChannel.weeklyReview,
              NotificationChannel.fighterTip,
            },
            pausedUntil: {NotificationChannel.weighIn: day(2)},
          );
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
    });

    test('any single difference makes settings unequal', () {
      final base = NotificationSettings();
      final variants = [
        base.copyWith(enabledChannels: {NotificationChannel.weighIn}),
        base.copyWith(usualTrainingHour: 19),
        base.copyWith(usualTrainingMinute: 5),
        base.copyWith(sessionLeadMinutes: 61),
        base.copyWith(fuelWindowLeadMinutes: 151),
        base.copyWith(quietHours: const QuietHours.hm(22, 0, 7, 0)),
        base.copyWith(pauseAll: true),
        base.copyWith(pauseNutrition: true),
        base.copyWith(pausedUntil: {NotificationChannel.weighIn: day(1)}),
      ];
      for (final v in variants) {
        expect(v, isNot(base));
      }
      expect(base == Object(), isFalse);
      final a =
          base.copyWith(pausedUntil: {NotificationChannel.weighIn: day(1)});
      final b =
          base.copyWith(pausedUntil: {NotificationChannel.weighIn: day(2)});
      final c =
          base.copyWith(pausedUntil: {NotificationChannel.proteinGap: day(1)});
      expect(a, isNot(b));
      expect(a, isNot(c));
    });
  });

  group('QuietHours', () {
    test('a same-day window includes its start and excludes its end', () {
      const q = QuietHours.hm(13, 0, 15, 0);
      expect(q.wraps, isFalse);
      expect(q.contains(13 * 60), isTrue);
      expect(q.contains(14 * 60 + 59), isTrue);
      expect(q.contains(15 * 60), isFalse);
      expect(q.contains(12 * 60 + 59), isFalse);
    });

    test('equality and hash', () {
      expect(const QuietHours(), const QuietHours.hm(21, 0, 7, 0));
      expect(const QuietHours().hashCode,
          const QuietHours.hm(21, 0, 7, 0).hashCode);
      expect(const QuietHours() == Object(), isFalse);
    });
  });

  group('autoPausedChannels', () {
    test('three ignored in a row pause the channel', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, -3),
        _record(NotificationChannel.fighterTip, -2),
        _record(NotificationChannel.fighterTip, -1),
      ]);
      expect(autoPausedChannels(h, now), {NotificationChannel.fighterTip});
    });

    test('records may arrive in any order', () {
      final h = NotificationHistory([
        _record(NotificationChannel.weeklyReview, -1),
        _record(NotificationChannel.weeklyReview, -3),
        _record(NotificationChannel.weeklyReview, -2),
      ]);
      expect(autoPausedChannels(h, now), {NotificationChannel.weeklyReview});
    });

    test('two ignored are not enough', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, -2),
        _record(NotificationChannel.fighterTip, -1),
      ]);
      expect(autoPausedChannels(h, now), isEmpty);
    });

    test('an opened notification in the middle resets the run', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, -4),
        _record(NotificationChannel.fighterTip, -3),
        _record(NotificationChannel.fighterTip, -2, ignored: false),
        _record(NotificationChannel.fighterTip, -1),
      ]);
      expect(autoPausedChannels(h, now), isEmpty);
    });

    test('only the newest run counts: opened last means not paused', () {
      final h = NotificationHistory([
        _record(NotificationChannel.proteinGap, -4),
        _record(NotificationChannel.proteinGap, -3),
        _record(NotificationChannel.proteinGap, -2),
        _record(NotificationChannel.proteinGap, -1, ignored: false),
      ]);
      expect(autoPausedChannels(h, now), isEmpty);
    });

    test('channels are counted separately', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, -3),
        _record(NotificationChannel.weighIn, -2),
        _record(NotificationChannel.fighterTip, -1),
        _record(NotificationChannel.weighIn, -1),
        _record(NotificationChannel.fighterTip, -2),
      ]);
      expect(autoPausedChannels(h, now), {NotificationChannel.fighterTip});
    });

    test('records from the future are ignored', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, 1),
        _record(NotificationChannel.fighterTip, 2),
        _record(NotificationChannel.fighterTip, 3),
      ]);
      expect(autoPausedChannels(h, now), isEmpty);
    });

    test('the trial notice is never auto-paused', () {
      final h = NotificationHistory([
        for (var i = 1; i <= 5; i++)
          _record(NotificationChannel.trialEnding, -i),
      ]);
      expect(autoPausedChannels(h, now), isEmpty);
    });

    test('an empty history pauses nothing', () {
      expect(autoPausedChannels(NotificationHistory(), now), isEmpty);
    });

    test('withoutChannel drops one channel and add appends', () {
      final h = NotificationHistory([
        _record(NotificationChannel.fighterTip, -1),
        _record(NotificationChannel.weighIn, -1),
      ]);
      expect(h.withoutChannel(NotificationChannel.fighterTip).records,
          hasLength(1));
      expect(h.add(_record(NotificationChannel.weighIn, -2)).records,
          hasLength(3));
      expect(() => h.records.add(_record(NotificationChannel.weighIn, -3)),
          throwsUnsupportedError);
    });

    test('records compare by value', () {
      final a = _record(NotificationChannel.weighIn, -1);
      final b = _record(NotificationChannel.weighIn, -1);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(
          a, isNot(_record(NotificationChannel.weighIn, -1, ignored: false)));
      expect(a == Object(), isFalse);
    });
  });

  group('PlannedNotification', () {
    PlannedNotification build({String key = 'notif.x', String arg = 'a'}) =>
        PlannedNotification(
          id: 1,
          channel: NotificationChannel.weeklyReview,
          fireAt: day(1, 10),
          contentKey: key,
          args: {'k': arg},
          route: '/review',
        );

    test('equal by value, unequal when any field differs', () {
      expect(build(), build());
      expect(build().hashCode, build().hashCode);
      expect(build(), isNot(build(key: 'notif.y')));
      expect(build(), isNot(build(arg: 'b')));
      expect(
        build(),
        isNot(PlannedNotification(
          id: 1,
          channel: NotificationChannel.weeklyReview,
          fireAt: day(1, 10),
          contentKey: 'notif.x',
          args: const {'other': 'a'},
          route: '/review',
        )),
      );
      expect(build() == Object(), isFalse);
    });

    test('args cannot be changed afterwards', () {
      expect(() => build().args['k'] = 'z', throwsUnsupportedError);
    });

    test('toString names the channel and key', () {
      expect(build().toString(), contains('weeklyReview'));
      expect(build().toString(), contains('notif.x'));
    });

    test('the same inputs give the same id and any change differs', () {
      final base = PlannedNotification.stableId(
        NotificationChannel.sessionReminder,
        day(1),
        'abc',
      );
      expect(
        PlannedNotification.stableId(
          NotificationChannel.sessionReminder,
          day(1, 23),
          'abc',
        ),
        base,
        reason: 'time of day is not part of the id',
      );
      expect(
        PlannedNotification.stableId(
          NotificationChannel.sessionReminder,
          day(2),
          'abc',
        ),
        isNot(base),
      );
      expect(
        PlannedNotification.stableId(
            NotificationChannel.sessionReminder, day(1)),
        isNot(base),
      );
    });
  });
}
