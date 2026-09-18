import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/state/streak_engine.dart';

void main() {
  // A fixed Wednesday so "week" math in these tests never depends on the
  // day the suite happens to run.
  final wednesday = DateTime(2026, 9, 16);

  Set<String> keysFor(List<int> daysAgo, {DateTime? from}) => {
        for (final n in daysAgo)
          StreakEngine.completedDateKeys([
            TrainingSession(
              day: 'x',
              title: 't',
              subtitle: '',
              icon: Icons.circle,
              completed: true,
              completedAt: (from ?? wednesday).subtract(Duration(days: n)),
            ),
          ]).first,
      };

  group('completedDateKeys', () {
    test('only counts completed sessions with a completion date', () {
      final sessions = [
        TrainingSession(
          day: 'Mon',
          title: 'a',
          subtitle: '',
          icon: Icons.circle,
          completed: true,
          completedAt: wednesday,
        ),
        const TrainingSession(
          day: 'Tue',
          title: 'b',
          subtitle: '',
          icon: Icons.circle,
          completed: false,
        ),
      ];
      expect(StreakEngine.completedDateKeys(sessions).length, 1);
    });
  });

  group('streakDays', () {
    test('is zero with nothing completed', () {
      expect(StreakEngine.streakDays({}, now: wednesday), 0);
    });

    test('counts consecutive days ending yesterday when today is empty', () {
      // Today has nothing yet; the three days before it are all completed.
      final keys = keysFor([1, 2, 3]);
      expect(StreakEngine.streakDays(keys, now: wednesday), 3);
    });

    test('today having nothing yet does not break the streak', () {
      // This is the behavior the old AppState.currentStreakDays got wrong:
      // it zeroed the streak the instant "today" had nothing logged.
      final keys = keysFor([1, 2]);
      expect(StreakEngine.streakDays(keys, now: wednesday), greaterThan(0));
    });

    test('counts today too once it is completed', () {
      final keys = keysFor([0, 1, 2]);
      expect(StreakEngine.streakDays(keys, now: wednesday), 3);
    });

    test('stops at the first real gap', () {
      // Completed yesterday and 3 days ago, but not 2 days ago: the gap ends
      // the count at yesterday.
      final keys = keysFor([1, 3]);
      expect(StreakEngine.streakDays(keys, now: wednesday), 1);
    });

    test('a protected date counts as if it were completed', () {
      final keys = keysFor([2]); // yesterday and today both empty
      final withoutFreeze = StreakEngine.streakDays(keys, now: wednesday);
      final protected = {
        StreakEngine.completedDateKeys([
          TrainingSession(
            day: 'x',
            title: 't',
            subtitle: '',
            icon: Icons.circle,
            completed: true,
            completedAt: wednesday.subtract(const Duration(days: 1)),
          ),
        ]).first,
      };
      final withFreeze = StreakEngine.streakDays(
        keys,
        protectedDateKeys: protected,
        now: wednesday,
      );
      expect(withFreeze, greaterThan(withoutFreeze));
      // Protected yesterday bridges the gap to the completed day before it.
      expect(withFreeze, 2);
    });
  });

  group('isAtRisk', () {
    test('false with no streak going', () {
      expect(StreakEngine.isAtRisk({}, now: wednesday), isFalse);
    });

    test('true when yesterday is unlogged but the streak was alive before it',
        () {
      final keys = keysFor([2, 3]); // yesterday missing, day before alive
      expect(StreakEngine.isAtRisk(keys, now: wednesday), isTrue);
    });

    test('false once yesterday is protected', () {
      final keys = keysFor([2, 3]);
      final protected = {
        StreakEngine.completedDateKeys([
          TrainingSession(
            day: 'x',
            title: 't',
            subtitle: '',
            icon: Icons.circle,
            completed: true,
            completedAt: wednesday.subtract(const Duration(days: 1)),
          ),
        ]).first,
      };
      expect(
        StreakEngine.isAtRisk(keys,
            protectedDateKeys: protected, now: wednesday),
        isFalse,
      );
    });

    test('false once today is already logged', () {
      final keys = keysFor([0, 2, 3]);
      expect(StreakEngine.isAtRisk(keys, now: wednesday), isFalse);
    });

    test('false once yesterday is logged too — nothing to protect', () {
      final keys = keysFor([1, 2]);
      expect(StreakEngine.isAtRisk(keys, now: wednesday), isFalse);
    });

    test(
        'false after two full missed days — a freeze covers a slip, not a '
        'return from a break', () {
      final keys = keysFor([3, 4]); // yesterday AND the day before are gone
      expect(StreakEngine.isAtRisk(keys, now: wednesday), isFalse);
    });
  });

  group('week helpers', () {
    test('weekStart lands on Monday for any day of that week', () {
      for (var offset = 0; offset < 7; offset++) {
        final day = wednesday.add(Duration(days: offset - 2)); // Mon..Sun
        expect(StreakEngine.weekStart(day).weekday, DateTime.monday);
      }
    });

    test('weekKey is stable across a week and changes the next', () {
      final monday = StreakEngine.weekStart(wednesday);
      final sunday = monday.add(const Duration(days: 6));
      final nextMonday = monday.add(const Duration(days: 7));
      expect(StreakEngine.weekKey(monday), StreakEngine.weekKey(sunday));
      expect(StreakEngine.weekKey(monday),
          isNot(StreakEngine.weekKey(nextMonday)));
    });

    test('daysCompletedInWeek only counts days inside that week', () {
      final monday = StreakEngine.weekStart(wednesday);
      final keys = {
        for (final n in [0, 1, 6, 7]) // last day counts, next Monday does not
          StreakEngine.completedDateKeys([
            TrainingSession(
              day: 'x',
              title: 't',
              subtitle: '',
              icon: Icons.circle,
              completed: true,
              completedAt: monday.add(Duration(days: n)),
            ),
          ]).first,
      };
      expect(StreakEngine.daysCompletedInWeek(keys, monday), 3);
    });
  });

  group('freezesEarned', () {
    test('nothing below the threshold', () {
      expect(
        StreakEngine.freezesEarned(daysCompleted: 2, isPro: false),
        0,
      );
    });

    test('free accounts earn one at the threshold', () {
      expect(
        StreakEngine.freezesEarned(daysCompleted: 3, isPro: false),
        1,
      );
    });

    test('pro accounts earn two at the threshold', () {
      expect(
        StreakEngine.freezesEarned(daysCompleted: 3, isPro: true),
        2,
      );
    });

    test('a full week does not earn more than the daily threshold implies', () {
      expect(
        StreakEngine.freezesEarned(daysCompleted: 7, isPro: true),
        2,
      );
    });
  });

  group('freezeCap', () {
    test('free is lower than pro', () {
      expect(StreakEngine.freezeCap(isPro: false), StreakEngine.freeFreezeCap);
      expect(StreakEngine.freezeCap(isPro: true), StreakEngine.proFreezeCap);
      expect(
        StreakEngine.freezeCap(isPro: true),
        greaterThan(StreakEngine.freezeCap(isPro: false)),
      );
    });
  });
}
