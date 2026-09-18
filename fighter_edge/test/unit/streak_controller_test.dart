import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/state/streak_controller.dart';
import 'package:fighter_edge/state/streak_engine.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<StreakController> loaded(String userId) async {
    final controller = StreakController()..setUser(userId);
    await pumpEventQueue();
    return controller;
  }

  // Anchor the "current week" inside syncWeeklyEarn's own now: fixed so the
  // suite is not sensitive to the day it happens to run on. Wednesday, so
  // there is a full week both before and after it in the same month.
  final wednesday = DateTime(2026, 9, 16);
  final priorWeekStart =
      StreakEngine.weekStart(wednesday).subtract(const Duration(days: 7));

  String dateKey(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    return '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
  }

  Set<String> priorWeekDays(int count) => {
        for (var i = 0; i < count; i++)
          dateKey(priorWeekStart.add(Duration(days: i))),
      };

  test('starts empty for a brand-new user', () async {
    final controller = await loaded('rookie');
    expect(controller.freezesAvailable, 0);
    expect(controller.protectedDateKeys, isEmpty);
  });

  test('state is kept per user', () async {
    final a = await loaded('a');
    a.syncWeeklyEarn(
      completedDateKeys: priorWeekDays(3),
      isPro: false,
      now: wednesday,
    );
    expect(a.freezesAvailable, 1);

    final b = await loaded('b');
    expect(b.freezesAvailable, 0);
  });

  group('syncWeeklyEarn', () {
    test('earns a freeze when last week hit the threshold', () async {
      final controller = await loaded('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      expect(controller.freezesAvailable, 1);
    });

    test('earns nothing below the threshold', () async {
      final controller = await loaded('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(2),
        isPro: false,
        now: wednesday,
      );
      expect(controller.freezesAvailable, 0);
    });

    test('pro earns two instead of one', () async {
      final controller = await loaded('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: true,
        now: wednesday,
      );
      expect(controller.freezesAvailable, 2);
    });

    test('never earns twice for the same week', () async {
      final controller = await loaded('rookie');
      final args = (
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      controller.syncWeeklyEarn(
        completedDateKeys: args.completedDateKeys,
        isPro: args.isPro,
        now: args.now,
      );
      controller.syncWeeklyEarn(
        completedDateKeys: args.completedDateKeys,
        isPro: args.isPro,
        now: args.now.add(const Duration(hours: 1)),
      );
      expect(controller.freezesAvailable, 1);
    });

    test('stops banking once the cap is reached', () async {
      final controller = await loaded('rookie');
      // Three separate weeks, each qualifying, for a free account capped at
      // StreakEngine.freeFreezeCap.
      for (var week = 0; week < 3; week++) {
        final start = priorWeekStart.add(Duration(days: 7 * week));
        final days = {
          for (var i = 0; i < 3; i++) dateKey(start.add(Duration(days: i)))
        };
        controller.syncWeeklyEarn(
          completedDateKeys: days,
          isPro: false,
          now: wednesday.add(Duration(days: 7 * week)),
        );
      }
      expect(controller.freezesAvailable, StreakEngine.freeFreezeCap);
    });

    test('does nothing before the initial load finishes', () {
      // Not awaited: the controller has not loaded yet.
      final controller = StreakController()..setUser('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      expect(controller.freezesAvailable, 0);
    });

    test('persists the earned freeze across a restart', () async {
      final first = await loaded('rookie');
      first.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      await pumpEventQueue();

      final restarted = await loaded('rookie');
      expect(restarted.freezesAvailable, 1);
    });
  });

  group('useFreezeForYesterday', () {
    test('fails with nothing banked', () async {
      final controller = await loaded('rookie');
      final used = await controller.useFreezeForYesterday(now: wednesday);
      expect(used, isFalse);
      expect(controller.protectedDateKeys, isEmpty);
    });

    test('spends one and protects yesterday', () async {
      final controller = await loaded('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      final used = await controller.useFreezeForYesterday(now: wednesday);
      expect(used, isTrue);
      expect(controller.freezesAvailable, 0);
      final yesterday = wednesday.subtract(const Duration(days: 1));
      expect(controller.protectedDateKeys, contains(dateKey(yesterday)));
    });

    test('refuses to protect the same day twice', () async {
      final controller = await loaded('rookie');
      controller.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: true, // two freezes banked
        now: wednesday,
      );
      expect(await controller.useFreezeForYesterday(now: wednesday), isTrue);
      expect(await controller.useFreezeForYesterday(now: wednesday), isFalse);
      // The second call did not spend a freeze it could not apply.
      expect(controller.freezesAvailable, 1);
    });

    test('persists the protected day across a restart', () async {
      final first = await loaded('rookie');
      first.syncWeeklyEarn(
        completedDateKeys: priorWeekDays(3),
        isPro: false,
        now: wednesday,
      );
      await first.useFreezeForYesterday(now: wednesday);

      final restarted = await loaded('rookie');
      final yesterday = wednesday.subtract(const Duration(days: 1));
      expect(restarted.protectedDateKeys, contains(dateKey(yesterday)));
      expect(restarted.freezesAvailable, 0);
    });
  });
}
