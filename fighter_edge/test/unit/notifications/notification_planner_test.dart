import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/domain/notification_history.dart';
import 'package:fighter_edge/notifications/domain/notification_settings.dart';
import 'package:fighter_edge/notifications/domain/planned_notification.dart';
import 'package:flutter_test/flutter_test.dart';

import 'notification_test_helpers.dart';

const _session = NotificationChannel.sessionReminder;
const _fuel = NotificationChannel.fuelWindow;
const _review = NotificationChannel.weeklyReview;
const _fight = NotificationChannel.fightCountdown;
const _weigh = NotificationChannel.weighIn;
const _protein = NotificationChannel.proteinGap;
const _tip = NotificationChannel.fighterTip;
const _trial = NotificationChannel.trialEnding;

NotificationSettings _only(
  List<NotificationChannel> channels, {
  int usualHour = 18,
  int usualMinute = 0,
  int sessionLead = 60,
  int fuelLead = 150,
  QuietHours quiet = const QuietHours(),
}) =>
    on(
      channels,
      usualHour: usualHour,
      usualMinute: usualMinute,
      sessionLead: sessionLead,
      fuelLead: fuelLead,
      quiet: quiet,
    );

void main() {
  group('nothing is planned by default', () {
    test('default settings are all off, so the plan is empty', () {
      final plan = run(
        settings: NotificationSettings(),
        sessions: [session(1)],
        fightDate: day(10),
        trialEndsAt: day(4, 15),
        weighInWeekdays: {DateTime.wednesday},
      );
      // trialEnding is off by default too.
      expect(plan, isEmpty);
    });

    test('no sessions and nothing else switched on gives an empty plan', () {
      expect(run(settings: _only([_session])), isEmpty);
    });
  });

  group('session reminder', () {
    test('fires at the usual time minus the lead time', () {
      final plan = run(settings: _only([_session]), sessions: [session(1)]);
      expect(plan, hasLength(1));
      final n = plan.single;
      expect(n.channel, _session);
      expect(n.fireAt, day(1, 17));
      expect(n.contentKey, 'notif.session.soon');
      expect(n.route, '/train/session/s-1');
      expect(n.args, {
        'discipline': 'boxing',
        'weekday': 'tuesday',
        'sessionAt': '18:00',
      });
    });

    test('a session without a discipline has no discipline arg', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(1, discipline: null)],
      );
      expect(plan.single.args.containsKey('discipline'), isFalse);
    });

    final leadCases = <({int hour, int minute, int lead, DateTime expected})>[
      (hour: 18, minute: 0, lead: 60, expected: day(1, 17, 0)),
      (hour: 18, minute: 0, lead: 30, expected: day(1, 17, 30)),
      (hour: 18, minute: 0, lead: 120, expected: day(1, 16, 0)),
      (hour: 19, minute: 30, lead: 45, expected: day(1, 18, 45)),
      (hour: 12, minute: 15, lead: 75, expected: day(1, 11, 0)),
      (hour: 18, minute: 0, lead: 0, expected: day(1, 18, 0)),
    ];
    for (final c in leadCases) {
      test(
          'usual ${c.hour}:${c.minute} with ${c.lead} minutes lead fires '
          'at ${c.expected.hour}:${c.expected.minute}', () {
        final plan = run(
          settings: _only(
            [_session],
            usualHour: c.hour,
            usualMinute: c.minute,
            sessionLead: c.lead,
          ),
          sessions: [session(1)],
        );
        expect(plan.single.fireAt, c.expected);
      });
    }

    final silentStatuses = <SessionStatus>[
      SessionStatus.completed,
      SessionStatus.skipped,
      SessionStatus.moved,
      SessionStatus.missed,
      SessionStatus.rest,
      SessionStatus.beforeStart,
    ];
    for (final status in silentStatuses) {
      test('a ${status.name} session stays silent', () {
        final plan = run(
          settings: _only([_session, _fuel]),
          sessions: [session(1, status: status)],
          fuel: {day(1): FuelDayType.hard},
        );
        expect(plan, isEmpty);
      });
    }

    test('rest days with no session stay silent', () {
      final plan = run(
        settings: _only([_session, _fuel]),
        sessions: const [],
        fuel: {day(1): FuelDayType.rest, day(2): FuelDayType.hard},
      );
      expect(plan, isEmpty);
    });

    test('a session today whose reminder time has passed is dropped', () {
      final plan = run(
        at: day(0, 17, 30),
        settings: _only([_session]),
        sessions: [session(0, status: SessionStatus.today)],
      );
      expect(plan, isEmpty);
    });

    test('a session today with the reminder still ahead is planned', () {
      final plan = run(
        at: day(0, 15),
        settings: _only([_session]),
        sessions: [session(0, status: SessionStatus.today)],
      );
      expect(plan.single.fireAt, day(0, 17));
    });

    test('a moved session reminds on its new date only', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [
          session(1, status: SessionStatus.moved, id: 'mv'),
          session(3, id: 'mv'),
        ],
      );
      expect(plan.single.fireAt, day(3, 17));
    });

    test('two sessions on one day give one reminder, the first by id', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(1, id: 'b'), session(1, id: 'a')],
      );
      expect(plan, hasLength(1));
      expect(plan.single.route, '/train/session/a');
    });
  });

  group('quiet hours', () {
    test('default quiet hours wrap midnight', () {
      const quiet = QuietHours();
      expect(quiet.wraps, isTrue);
      for (final minute in [21 * 60, 23 * 60 + 59, 0, 6 * 60 + 59]) {
        expect(quiet.contains(minute), isTrue, reason: '$minute');
      }
      for (final minute in [7 * 60, 12 * 60, 20 * 60 + 59]) {
        expect(quiet.contains(minute), isFalse, reason: '$minute');
      }
    });

    test('a reminder inside quiet hours moves to their end if still early', () {
      // Session 07:30, reminder wanted 06:30 (quiet), moved to 07:00.
      final plan = run(
        settings: _only([_session], usualHour: 7, usualMinute: 30),
        sessions: [session(1)],
      );
      expect(plan.single.fireAt, day(1, 7));
    });

    test('a reminder moved to exactly the session start is kept', () {
      final plan = run(
        settings: _only([_session], usualHour: 7),
        sessions: [session(1)],
      );
      expect(plan.single.fireAt, day(1, 7));
    });

    test('a reminder is dropped when quiet hours end after the session', () {
      // Session 06:30, reminder 05:30 (quiet), quiet ends 07:00.
      final plan = run(
        settings: _only([_session], usualHour: 6, usualMinute: 30),
        sessions: [session(1)],
      );
      expect(plan, isEmpty);
    });

    test('a late session whose reminder is in the evening quiet window', () {
      // Session 22:00, reminder 21:00 (quiet). The window ends tomorrow at
      // 07:00, long after the session, so nothing is planned.
      final plan = run(
        settings: _only([_session], usualHour: 22),
        sessions: [session(1)],
      );
      expect(plan, isEmpty);
    });

    test('a non-wrapping window moves a reminder to its end', () {
      final plan = run(
        settings: _only(
          [_session],
          usualHour: 15,
          usualMinute: 30,
          quiet: const QuietHours.hm(13, 0, 15, 0),
        ),
        sessions: [session(1)],
      );
      expect(plan.single.fireAt, day(1, 15));
    });

    test('equal start and end means no quiet hours', () {
      const none = QuietHours.hm(7, 0, 7, 0);
      expect(none.isEmpty, isTrue);
      expect(none.contains(3 * 60), isFalse);
      final plan = run(
        settings: _only(
          [_session],
          usualHour: 4,
          sessionLead: 30,
          quiet: none,
        ),
        sessions: [session(1)],
      );
      expect(plan.single.fireAt, day(1, 3, 30));
    });

    test('release returns the same moment outside quiet hours', () {
      expect(const QuietHours().release(day(1, 12)), day(1, 12));
    });

    test('release after midnight stays on the same day', () {
      expect(const QuietHours().release(day(1, 2)), day(1, 7));
    });

    test('release before midnight goes to the next morning', () {
      expect(const QuietHours().release(day(1, 23)), day(2, 7));
    });

    test('a non-session channel pushed into the next day is dropped', () {
      // Protein slot 17:00 inside a quiet window 16:00 to 02:00 would move to
      // 02:00 tomorrow. It is dropped, not moved to another day.
      final plan = run(
        settings: _only(
          [_protein],
          quiet: const QuietHours.hm(16, 0, 2, 0),
        ),
        sessions: [session(1)],
      );
      expect(plan, isEmpty);
    });

    test('a non-session channel pushed later the same day is kept', () {
      final plan = run(
        settings: _only(
          [_weigh],
          quiet: const QuietHours.hm(22, 0, 9, 30),
        ),
        weighInWeekdays: {DateTime.wednesday},
      );
      expect(plan.single.fireAt, day(2, 9, 30));
    });

    test('the trial notice also respects the user quiet hours', () {
      final plan = run(
        settings: _only(
          [_trial],
          quiet: const QuietHours.hm(8, 0, 11, 0),
        ),
        trialEndsAt: day(6, 15),
      );
      expect(plan.single.fireAt, day(4, 11));
    });
  });

  group('fuel window', () {
    test('a hard day merges the fuel window into one session notification', () {
      final plan = run(
        settings: _only([_session, _fuel]),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan, hasLength(1));
      final n = plan.single;
      expect(n.channel, _session);
      expect(n.contentKey, 'notif.session.soonFuel');
      expect(n.fireAt, day(1, 15, 30));
      expect(n.args['fuelWindowAt'], '15:30');
      expect(n.args['sessionAt'], '18:00');
    });

    test('a double day also merges', () {
      final plan = run(
        settings: _only([_session, _fuel]),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.doubleDay},
      );
      expect(plan.single.args['fuelWindowAt'], '15:30');
    });

    for (final type in [
      FuelDayType.rest,
      FuelDayType.easy,
      FuelDayType.fightWeek,
    ]) {
      test('a ${type.name} fuel day gets a plain session reminder', () {
        final plan = run(
          settings: _only([_session, _fuel]),
          sessions: [session(1)],
          fuel: {day(1): type},
        );
        expect(plan.single.contentKey, 'notif.session.soon');
        expect(plan.single.args.containsKey('fuelWindowAt'), isFalse);
      });
    }

    test('a fuel type with a time of day still matches its date', () {
      final plan = run(
        settings: _only([_session, _fuel]),
        sessions: [session(1)],
        fuel: {day(1, 13, 45): FuelDayType.hard},
      );
      expect(plan.single.args['fuelWindowAt'], '15:30');
    });

    test('with the session reminder off, the fuel window stands alone', () {
      final plan = run(
        settings: _only([_fuel]),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      final n = plan.single;
      expect(n.channel, _fuel);
      expect(n.contentKey, 'notif.fuel.window');
      expect(n.fireAt, day(1, 15, 30));
      expect(n.route, '/train/session/s-1');
    });

    test('an off fuel window leaves a plain reminder', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan.single.contentKey, 'notif.session.soon');
    });

    test('a fuel window that has already passed leaves the reminder', () {
      final plan = run(
        at: day(1, 16),
        settings: _only([_session, _fuel]),
        sessions: [session(1, status: SessionStatus.planned)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan.single.contentKey, 'notif.session.soon');
      expect(plan.single.fireAt, day(1, 17));
    });

    test('a hard day with no session gets no fuel window', () {
      final plan = run(
        settings: _only([_fuel]),
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan, isEmpty);
    });

    test('a fuel window in quiet hours before the session is dropped', () {
      // Session 08:00, fuel window 05:30 (quiet) moves to 07:00, before the
      // session, so it is kept and merged with the 07:00 reminder.
      final plan = run(
        settings: _only([_session, _fuel], usualHour: 8),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan.single.fireAt, day(1, 7));
      expect(plan.single.args['fuelWindowAt'], '07:00');
      // Session 06:30: neither can be placed.
      final early = run(
        settings: _only([_session, _fuel], usualHour: 6, usualMinute: 30),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(early, isEmpty);
    });

    test('a paused fuel window leaves the plain reminder', () {
      final plan = run(
        settings: on(
          [_session, _fuel],
          pausedUntil: {_fuel: day(5)},
        ),
        sessions: [session(1)],
        fuel: {day(1): FuelDayType.hard},
      );
      expect(plan.single.contentKey, 'notif.session.soon');
    });
  });

  group('age and nutrition pause', () {
    final ageCases = <({int? age, bool shown})>[
      (age: null, shown: false),
      (age: 12, shown: false),
      (age: 17, shown: false),
      (age: 18, shown: true),
      (age: 35, shown: true),
    ];
    for (final c in ageCases) {
      test(
          'age ${c.age ?? 'unknown'}: nutrition channels '
          '${c.shown ? 'shown' : 'hidden'}', () {
        final plan = run(
          age: c.age,
          settings: _only([_session, _fuel, _weigh, _protein]),
          sessions: [session(1), session(3)],
          fuel: {day(1): FuelDayType.hard},
          weighInWeekdays: {DateTime.wednesday},
        );
        final channels = channelsOf(plan).toSet();
        if (c.shown) {
          expect(channels, contains(_session));
          expect(plan.any((n) => n.args.containsKey('fuelWindowAt')), isTrue);
          expect(channels, contains(_weigh));
        } else {
          expect(plan.any((n) => n.args.containsKey('fuelWindowAt')), isFalse);
          expect(channels, isNot(contains(_weigh)));
          expect(channels, isNot(contains(_protein)));
          expect(channels, isNot(contains(_fuel)));
          // Session reminders are not nutrition and still go out.
          expect(channels, contains(_session));
        }
      });
    }

    test('fight countdown and review are not hidden for a minor', () {
      final plan = run(
        age: 16,
        settings: _only([_fight, _review]),
        fightDate: day(2),
      );
      expect(channelsOf(plan), containsAll([_fight, _review]));
    });

    test('pauseNutrition hides fuel window, weigh-in and protein only', () {
      final plan = run(
        settings: on(
          [_session, _fuel, _weigh, _protein, _review],
          pauseNutrition: true,
        ),
        sessions: [session(1), session(3)],
        fuel: {day(1): FuelDayType.hard},
        weighInWeekdays: {DateTime.wednesday},
      );
      final channels = channelsOf(plan).toSet();
      expect(channels, {_session, _review});
      expect(plan.any((n) => n.args.containsKey('fuelWindowAt')), isFalse);
    });
  });

  group('weekly review', () {
    test('fires Sunday 18:00 and nowhere else', () {
      final plan = run(settings: _only([_review]), horizonDays: 14);
      expect(plan, hasLength(2));
      expect(plan.first.fireAt, day(6, 18));
      expect(plan.last.fireAt, day(13, 18));
      expect(plan.first.contentKey, 'notif.review.weekly');
      expect(plan.first.route, '/review');
      expect(plan.first.fireAt.weekday, DateTime.sunday);
    });

    test('is off when the channel is off', () {
      expect(run(settings: _only([_session])), isEmpty);
    });

    test('sits out of quiet hours the same day', () {
      final plan = run(
        settings: _only([_review], quiet: const QuietHours.hm(17, 0, 19, 0)),
      );
      expect(plan.single.fireAt, day(6, 19));
    });
  });

  group('fight countdown', () {
    // Offsets are days from Monday 1 June 09:00. The milestones are 09:00 on
    // day-7 and day-1 of the fight, only when strictly after now.
    final cases = <({int offset, List<String> keys})>[
      (offset: -3, keys: const []),
      (offset: 0, keys: const []),
      (offset: 1, keys: const []),
      (offset: 2, keys: ['notif.fight.tomorrow']),
      (offset: 6, keys: ['notif.fight.tomorrow']),
      (offset: 7, keys: ['notif.fight.tomorrow']),
      (offset: 8, keys: ['notif.fight.week', 'notif.fight.tomorrow']),
      (offset: 9, keys: ['notif.fight.week']),
      (offset: 20, keys: const []),
    ];
    for (final c in cases) {
      test('fight ${c.offset} days away plans ${c.keys.length} milestone(s)',
          () {
        final plan = run(
          settings: _only([_fight]),
          fightDate: day(c.offset),
        );
        expect([for (final n in plan) n.contentKey], c.keys);
      });
    }

    test('milestones carry only the number of days and a home route', () {
      final plan = run(
        settings: _only([_fight]),
        fightDate: day(8, 20),
        horizonDays: 10,
      );
      expect(plan, hasLength(2));
      expect(plan.first.fireAt, day(1, 9));
      expect(plan.first.args, {'daysToFight': '7'});
      expect(plan.last.fireAt, day(7, 9));
      expect(plan.last.args, {'daysToFight': '1'});
      expect(plan.every((n) => n.route == '/home'), isTrue);
    });

    test('fight day itself and the days between get nothing', () {
      final plan = run(
        settings: _only([_fight]),
        fightDate: day(14),
        horizonDays: 20,
      );
      expect([for (final n in plan) n.fireAt], [day(7, 9), day(13, 9)]);
    });

    test('no fight date means no countdown', () {
      expect(run(settings: _only([_fight])), isEmpty);
    });

    test('works for an athlete of unknown age', () {
      final plan = run(
        age: null,
        settings: _only([_fight]),
        fightDate: day(2),
      );
      expect(plan, hasLength(1));
    });
  });

  group('weigh-in', () {
    test('only on the weekdays the caller supplies', () {
      final plan = run(
        settings: _only([_weigh]),
        weighInWeekdays: {DateTime.monday, DateTime.wednesday},
      );
      // Monday 08:00 has passed. Wednesday and next Monday 08:00 are ahead.
      expect([for (final n in plan) n.fireAt], [day(2, 8), day(7, 8)]);
      expect(plan.first.contentKey, 'notif.weighIn.reminder');
      expect(plan.first.route, '/fuel');
      expect(plan.first.args, isEmpty);
    });

    test('no weekdays means none (the default)', () {
      expect(run(settings: _only([_weigh])), isEmpty);
    });

    test('is off when the channel is off', () {
      expect(
        run(
          settings: _only([_review]),
          weighInWeekdays: {DateTime.wednesday},
        ).where((n) => n.channel == _weigh),
        isEmpty,
      );
    });
  });

  group('protein gap', () {
    test('one 17:00 slot on training days only', () {
      final plan = run(
        settings: _only([_protein]),
        sessions: [session(1), session(3)],
      );
      expect([for (final n in plan) n.fireAt], [day(1, 17), day(3, 17)]);
      expect(plan.first.contentKey, 'notif.protein.evening');
      expect(plan.first.route, '/fuel');
      expect(plan.first.args, isEmpty);
    });

    test('a completed session day still counts as a training day', () {
      final plan = run(
        at: day(1, 8),
        settings: _only([_protein]),
        sessions: [session(1, status: SessionStatus.completed)],
      );
      expect(plan.single.fireAt, day(1, 17));
    });

    test('skipped, rest and moved days are not training days', () {
      final plan = run(
        settings: _only([_protein]),
        sessions: [
          session(1, status: SessionStatus.skipped),
          session(2, status: SessionStatus.rest),
          session(3, status: SessionStatus.moved),
        ],
      );
      expect(plan, isEmpty);
    });
  });

  group('fighter tips', () {
    test('at most two in a rolling week and three days apart', () {
      final plan = run(settings: _only([_tip]));
      expect([for (final n in plan) n.fireAt], [day(0, 12), day(3, 12)]);
    });

    test('over a long horizon no seven-day window holds more than two', () {
      final plan = run(settings: _only([_tip]), horizonDays: 56);
      final days = [for (final n in plan) n.fireAt];
      expect(days.length, greaterThan(10));
      for (var start = -10; start < 70; start++) {
        final inWindow = days.where(
          (d) => !d.isBefore(day(start)) && d.isBefore(day(start + 7)),
        );
        expect(inWindow.length, lessThanOrEqualTo(2), reason: 'window $start');
      }
      for (var i = 1; i < days.length; i++) {
        expect(days[i].difference(days[i - 1]).inDays, greaterThanOrEqualTo(3));
      }
      expect(
        {for (final d in days) '${d.year}-${d.month}-${d.day}'}.length,
        days.length,
        reason: 'one per day',
      );
    });

    test('tips already delivered this week use up the allowance', () {
      final history = NotificationHistory([
        NotificationRecord(
          channel: _tip,
          notificationId: 1,
          firedAt: day(-3, 12),
        ),
        NotificationRecord(
          channel: _tip,
          notificationId: 2,
          firedAt: day(-6, 12),
        ),
      ]);
      final plan = run(settings: _only([_tip]), history: history);
      // Window of the first candidate days still holds two delivered tips.
      expect(plan.first.fireAt.isAfter(day(0, 23)), isTrue);
      for (final n in plan) {
        final recent = [day(-3, 12), day(-6, 12)]
            .where((t) => n.fireAt.difference(t).inDays < 7)
            .length;
        expect(recent, lessThan(2), reason: '${n.fireAt}');
      }
    });

    test('a tip never takes a day that another channel owns', () {
      final plan = run(
        settings: _only([_tip, _review]),
        horizonDays: 10,
      );
      final sunday = plan.where((n) => n.fireAt.weekday == DateTime.sunday);
      expect(sunday.every((n) => n.channel == _review), isTrue);
    });

    test('content keys come from the small list', () {
      final plan = run(settings: _only([_tip]), horizonDays: 56);
      for (final n in plan) {
        final index = int.parse(n.contentKey.split('.').last);
        expect(n.contentKey, startsWith('notif.tip.'));
        expect(index, inInclusiveRange(0, 5));
        expect(n.args, isEmpty);
      }
    });

    test('tips are off unless enabled', () {
      expect(run(settings: _only([_review])).where((n) => n.channel == _tip),
          isEmpty);
    });
  });

  group('trial ending', () {
    test('fires once, two days before the trial ends at 10:00', () {
      final plan = run(settings: _only([_trial]), trialEndsAt: day(6, 15));
      final n = plan.single;
      expect(n.channel, _trial);
      expect(n.fireAt, day(4, 10));
      expect(n.contentKey, 'notif.trial.ending');
      expect(n.route, '/home');
    });

    test('does not use up the daily cap', () {
      final plan = run(
        settings: _only([_trial, _session]),
        sessions: [session(4)],
        trialEndsAt: day(6, 15),
      );
      expect(channelsOf(plan), [_trial, _session]);
      expect(plan.map((n) => n.fireAt), [day(4, 10), day(4, 17)]);
    });

    test('is not blocked by a notification already delivered that day', () {
      final history = NotificationHistory([
        NotificationRecord(
          channel: _session,
          notificationId: 3,
          firedAt: day(4, 8),
        ),
      ]);
      final plan = run(
        settings: _only([_trial]),
        trialEndsAt: day(6, 15),
        history: history,
      );
      expect(plan, hasLength(1));
    });

    test('pauseAll silences everything except the billing notice', () {
      final plan = run(
        settings: on(
          NotificationChannel.values,
          pauseAll: true,
        ),
        sessions: [session(1)],
        trialEndsAt: day(6, 15),
        fightDate: day(9),
      );
      expect(channelsOf(plan), [_trial]);
    });

    test('its own channel switch still applies', () {
      final plan = run(
        settings: _only([_session]),
        trialEndsAt: day(6, 15),
      );
      expect(plan, isEmpty);
    });

    test('pausedUntil after the fire time suppresses it', () {
      final plan = run(
        settings: on([_trial], pausedUntil: {_trial: day(5)}),
        trialEndsAt: day(6, 15),
      );
      expect(plan, isEmpty);
    });

    test('it is sent once: an earlier delivery means no second one', () {
      final plan = run(
        settings: _only([_trial]),
        trialEndsAt: day(6, 15),
        history: NotificationHistory([
          NotificationRecord(
            channel: _trial,
            notificationId: 9,
            firedAt: day(-1, 10),
          ),
        ]),
      );
      expect(plan, isEmpty);
    });

    test('auto-pause never applies to it', () {
      final history = NotificationHistory([
        for (var i = 0; i < 4; i++)
          NotificationRecord(
            channel: _trial,
            notificationId: i,
            firedAt: day(-10 + i),
            ignored: true,
          ),
      ]);
      expect(autoPausedChannels(history, now), isNot(contains(_trial)));
    });

    test('nothing when the notice time is already past', () {
      expect(
        run(
          at: day(0, 11),
          settings: _only([_trial]),
          trialEndsAt: day(2, 15),
        ),
        isEmpty,
      );
    });

    test('nothing when the notice is beyond the horizon', () {
      expect(
        run(settings: _only([_trial]), trialEndsAt: day(20, 15)),
        isEmpty,
      );
    });

    test('no trial date means no notice', () {
      expect(run(settings: _only([_trial])), isEmpty);
    });
  });

  group('daily cap and priority', () {
    // Sunday 7 June has a session (reminder 17:00, protein 17:00), the weekly
    // review (18:00) and a weigh-in (08:00).
    final sunday = day(6);
    final channelsWanting = <NotificationChannel>[
      _fight,
      _session,
      _review,
      _weigh,
      _protein,
    ];

    test('priority order picks one winner per day', () {
      for (var i = 0; i < channelsWanting.length; i++) {
        final enabled = channelsWanting.sublist(i);
        final plan = run(
          settings: _only(enabled),
          sessions: [session(6)],
          fightDate: day(13), // day-7 milestone is Sunday 7 June
          weighInWeekdays: {DateTime.sunday},
        );
        final onSunday = plan.where(
          (n) => n.fireAt.isAfter(sunday) && n.fireAt.isBefore(day(7)),
        );
        expect(onSunday, hasLength(1), reason: enabled.toString());
        expect(onSunday.single.channel, channelsWanting[i],
            reason: enabled.toString());
      }
    });

    test('no day ever holds two non-transactional notifications', () {
      final plan = run(
        settings: allOn,
        sessions: [for (var i = 0; i < 14; i++) session(i)],
        fuel: {for (var i = 0; i < 14; i++) day(i): FuelDayType.hard},
        fightDate: day(13),
        weighInWeekdays: {1, 2, 3, 4, 5, 6, 7},
        horizonDays: 14,
      );
      final perDay = <String, int>{};
      for (final n in plan) {
        final key = '${n.fireAt.year}-${n.fireAt.month}-${n.fireAt.day}';
        perDay[key] = (perDay[key] ?? 0) + 1;
      }
      expect(perDay.values.every((c) => c == 1), isTrue, reason: '$perDay');
    });

    test('a dropped notification is not moved to another day', () {
      final plan = run(
        settings: _only([_session, _review]),
        sessions: [session(6)],
      );
      expect(plan, hasLength(1));
      expect(plan.single.channel, _session);
    });

    test('a merged session and fuel notification counts once', () {
      final plan = run(
        settings: _only([_session, _fuel, _review]),
        sessions: [session(6)],
        fuel: {day(6): FuelDayType.hard},
      );
      expect(plan, hasLength(1));
      expect(plan.single.contentKey, 'notif.session.soonFuel');
    });

    test('a loser still plans on other days', () {
      final plan = run(
        settings: _only([_session, _protein]),
        sessions: [session(1), session(2)],
      );
      expect(channelsOf(plan), [_session, _session]);
    });

    test('a notification already delivered today blocks the rest of today', () {
      final history = NotificationHistory([
        NotificationRecord(
          channel: _review,
          notificationId: 1,
          firedAt: day(0, 8),
        ),
      ]);
      final plan = run(
        settings: _only([_session]),
        sessions: [session(0, status: SessionStatus.today), session(1)],
        history: history,
      );
      expect([for (final n in plan) n.fireAt], [day(1, 17)]);
    });
  });

  group('channel switches', () {
    test('pauseAll silences every non-billing channel', () {
      final plan = run(
        settings: on(NotificationChannel.values, pauseAll: true),
        sessions: [session(1)],
        fightDate: day(9),
        weighInWeekdays: {DateTime.wednesday},
      );
      expect(plan, isEmpty);
    });

    test('a channel paused until after the fire time is silent', () {
      final settings = on(
        [_session],
        pausedUntil: {_session: day(1, 18)},
      );
      final plan = run(
        settings: settings,
        sessions: [session(1), session(2)],
      );
      expect([for (final n in plan) n.fireAt], [day(2, 17)]);
    });

    test('a pause ending exactly at the fire time lets it through', () {
      final plan = run(
        settings: on([_session], pausedUntil: {_session: day(1, 17)}),
        sessions: [session(1)],
      );
      expect(plan, hasLength(1));
    });

    test('a pause that already ended changes nothing', () {
      final plan = run(
        settings: on([_session], pausedUntil: {_session: day(-1)}),
        sessions: [session(1)],
      );
      expect(plan, hasLength(1));
    });

    test('pausing one channel leaves the others alone', () {
      final plan = run(
        settings: on(
          [_session, _review],
          pausedUntil: {_session: day(9)},
        ),
        sessions: [session(1)],
      );
      expect(channelsOf(plan), [_review]);
    });

    group('auto-pause', () {
      NotificationHistory ignored(int count, {int startOffset = -5}) =>
          NotificationHistory([
            for (var i = 0; i < count; i++)
              NotificationRecord(
                channel: _session,
                notificationId: i,
                firedAt: day(startOffset + i, 17),
                ignored: true,
              ),
          ]);

      test('three ignored in a row silence the channel', () {
        final plan = run(
          settings: _only([_session, _review]),
          sessions: [session(1)],
          history: ignored(3),
        );
        expect(channelsOf(plan), [_review]);
      });

      test('two ignored do not', () {
        final plan = run(
          settings: _only([_session]),
          sessions: [session(1)],
          history: ignored(2),
        );
        expect(channelsOf(plan), [_session]);
      });

      test('an opened notification resets the count', () {
        final history = ignored(3).add(
          NotificationRecord(
            channel: _session,
            notificationId: 99,
            firedAt: day(-1, 17),
          ),
        );
        final plan = run(
          settings: _only([_session]),
          sessions: [session(1)],
          history: history,
        );
        expect(channelsOf(plan), [_session]);
      });

      test('the user keeping the channel starts the count again', () {
        final plan = run(
          settings: _only([_session]),
          sessions: [session(1)],
          history: ignored(4).withoutChannel(_session),
        );
        expect(channelsOf(plan), [_session]);
      });

      test('a paused session reminder still lets a fuel window through', () {
        final plan = run(
          settings: _only([_session, _fuel]),
          sessions: [session(1)],
          fuel: {day(1): FuelDayType.hard},
          history: ignored(3),
        );
        expect(channelsOf(plan), [_fuel]);
      });
    });
  });

  group('time and window', () {
    test('nothing is planned at or before now', () {
      final atFire = run(
        at: day(1, 17),
        settings: _only([_session]),
        sessions: [session(1)],
      );
      expect(atFire, isEmpty);
      final justBefore = run(
        at: day(1, 16, 59),
        settings: _only([_session]),
        sessions: [session(1)],
      );
      expect(justBefore, hasLength(1));
    });

    test('the end of the horizon is inclusive', () {
      // Weekly review is Sunday 18:00 (day 6).
      expect(
        run(at: day(0, 18), settings: _only([_review]), horizonDays: 6),
        hasLength(1),
      );
      expect(
        run(at: day(0, 17, 59), settings: _only([_review]), horizonDays: 6),
        isEmpty,
      );
    });

    test('a bigger horizon includes later days', () {
      final seven = run(settings: _only([_review]));
      final fourteen = run(settings: _only([_review]), horizonDays: 14);
      expect(seven, hasLength(1));
      expect(fourteen, hasLength(2));
    });

    test('a horizon of zero is an empty window', () {
      final plan = run(
        at: day(0, 8),
        settings: _only([_session]),
        sessions: [session(0, status: SessionStatus.today), session(1)],
        horizonDays: 0,
      );
      expect(plan, isEmpty);
    });

    test('sessions outside the horizon are ignored', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(9)],
      );
      expect(plan, isEmpty);
    });

    test(
        'a reminder for a session just after midnight can fire the night '
        'before only outside quiet hours', () {
      final plan = run(
        settings: _only(
          [_session],
          usualHour: 0,
          usualMinute: 30,
          quiet: const QuietHours.hm(1, 0, 6, 0),
        ),
        sessions: [session(2)],
      );
      // Reminder wanted 23:30 on day 1, outside the 01:00-06:00 window.
      expect(plan.single.fireAt, day(1, 23, 30));
    });
  });

  group('stable ids', () {
    test('the same input gives the same ids', () {
      final a = run(settings: _only([_session]), sessions: [session(1)]);
      final b = run(settings: _only([_session]), sessions: [session(1)]);
      expect(a.single.id, b.single.id);
    });

    test('re-planning later the same day keeps the id', () {
      final early = run(
        at: day(0, 8),
        settings: _only([_session]),
        sessions: [session(1)],
      );
      final late = run(
        at: day(0, 20),
        settings: _only([_session]),
        sessions: [session(1)],
      );
      expect(early.single.id, late.single.id);
    });

    test('a different day gives a different id', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(1, id: 'x'), session(2, id: 'x')],
      );
      expect(plan[0].id, isNot(plan[1].id));
    });

    test('a different session id gives a different id', () {
      final a = run(
        settings: _only([_session]),
        sessions: [session(1, id: 'a')],
      );
      final b = run(
        settings: _only([_session]),
        sessions: [session(1, id: 'b')],
      );
      expect(a.single.id, isNot(b.single.id));
    });

    test('a different channel gives a different id', () {
      final ids = {
        for (final c in NotificationChannel.values)
          PlannedNotification.stableId(c, day(1), 's'),
      };
      expect(ids, hasLength(NotificationChannel.values.length));
    });

    test('ids are positive 31-bit numbers', () {
      final plan = run(
        settings: allOn,
        sessions: [for (var i = 0; i < 14; i++) session(i)],
        horizonDays: 14,
        fightDate: day(13),
        trialEndsAt: day(10, 12),
      );
      expect(plan, isNotEmpty);
      for (final n in plan) {
        expect(n.id, inInclusiveRange(0, 0x7fffffff));
      }
    });

    test('ids are unique across a busy plan', () {
      final plan = run(
        settings: allOn,
        sessions: [for (var i = 0; i < 30; i++) session(i)],
        horizonDays: 30,
        weighInWeekdays: {DateTime.wednesday},
        fightDate: day(25),
        trialEndsAt: day(20, 12),
      );
      expect({for (final n in plan) n.id}, hasLength(plan.length));
    });
  });

  group('determinism and ordering', () {
    test('the same input twice gives equal output', () {
      List<PlannedNotification> go() => run(
            settings: allOn,
            sessions: [for (var i = 0; i < 8; i++) session(i)],
            fuel: {for (var i = 0; i < 8; i++) day(i): FuelDayType.hard},
            fightDate: day(9),
            trialEndsAt: day(6, 12),
            weighInWeekdays: {DateTime.friday},
          );
      final a = go();
      final b = go();
      expect(a, equals(b));
      expect([for (final n in a) n.hashCode], [for (final n in b) n.hashCode]);
    });

    test('the order of the input sessions does not matter', () {
      final sessions = [for (var i = 0; i < 6; i++) session(i)];
      final forward = run(settings: allOn, sessions: sessions);
      final backward = run(
        settings: allOn,
        sessions: sessions.reversed.toList(),
      );
      expect(forward, equals(backward));
    });

    test('output is sorted by fire time', () {
      final plan = run(
        settings: allOn,
        sessions: [for (var i = 0; i < 8; i++) session(i)],
        trialEndsAt: day(5, 12),
        horizonDays: 14,
        fightDate: day(9),
      );
      final times = [for (final n in plan) n.fireAt];
      expect([...times]..sort(), times);
    });

    test('a moved discipline name is a plain key', () {
      final plan = run(
        settings: _only([_session]),
        sessions: [session(1, discipline: Discipline.muayThai)],
      );
      expect(plan.single.args['discipline'], 'muayThai');
    });
  });
}
