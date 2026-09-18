import '../data/data_repository.dart';
import '../models/training_session.dart';

/// Pure streak and streak-freeze math, kept apart from [AppState] and
/// [StreakController] for the same reason [VerificationGate] is kept apart
/// from [AuthController]: the rules should be testable without a widget tree,
/// a clock that can't be moved, or a persisted account.
class StreakEngine {
  StreakEngine._();

  /// Days completed in a week before a freeze is earned.
  static const int freezeEarnThreshold = 3;

  /// Freezes a free account may hold at once. Earning past this is wasted —
  /// deliberately, so a freeze stays an emergency cover for a missed day
  /// rather than something to hoard for a planned break.
  static const int freeFreezeCap = 2;

  /// Pro holds double: the harder training a subscriber is often doing
  /// justifies a little more slack, and it is a real, visible perk.
  static const int proFreezeCap = 4;

  static int freezeCap({required bool isPro}) =>
      isPro ? proFreezeCap : freeFreezeCap;

  /// The date keys (see [mealDateKey]) on which a session was completed.
  static Set<String> completedDateKeys(List<TrainingSession> sessions) => {
        for (final session in sessions)
          if (session.completed && session.completedAt != null)
            mealDateKey(session.completedAt!),
      };

  /// Consecutive days with a completed session, walking back from today.
  /// A day with nothing logged yet (today, before the user trains) does not
  /// break the streak — only a day that has fully passed with nothing on it
  /// does. [protectedDateKeys] are treated as if they had been completed.
  static int streakDays(
    Set<String> completedDateKeys, {
    Set<String> protectedDateKeys = const {},
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    var cursor = today;
    var streak = 0;
    while (true) {
      final key = mealDateKey(cursor);
      final counted =
          completedDateKeys.contains(key) || protectedDateKeys.contains(key);
      if (!counted) {
        // Today not having anything yet is not a break; every earlier day
        // still needs to count.
        if (cursor == today) {
          cursor = cursor.subtract(const Duration(days: 1));
          continue;
        }
        break;
      }
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// Whether an active streak is one missed day from breaking: yesterday has
  /// nothing logged and is not already protected, today has nothing logged
  /// yet either, and the streak through the day before yesterday is still
  /// alive. False once yesterday is genuinely gone (two clean days missed) —
  /// a freeze covers a slip, not a return from a break.
  static bool isAtRisk(
    Set<String> completedDateKeys, {
    Set<String> protectedDateKeys = const {},
    DateTime? now,
  }) {
    final today = _dateOnly(now ?? DateTime.now());
    final yesterday = today.subtract(const Duration(days: 1));
    final todayKey = mealDateKey(today);
    final yesterdayKey = mealDateKey(yesterday);
    if (completedDateKeys.contains(todayKey)) return false;
    if (completedDateKeys.contains(yesterdayKey)) return false;
    if (protectedDateKeys.contains(yesterdayKey)) return false;
    // Alive through the day before yesterday means there is a real streak
    // riding on protecting yesterday, not just an empty week starting late.
    return streakDays(
          completedDateKeys,
          protectedDateKeys: protectedDateKeys,
          now: yesterday,
        ) >
        0;
  }

  /// Monday 00:00 of the week containing [date].
  static DateTime weekStart(DateTime date) {
    final day = _dateOnly(date);
    return day.subtract(Duration(days: day.weekday - DateTime.monday));
  }

  /// A key stable for one calendar week, for de-duplicating the weekly
  /// freeze-earn check. Not a real ISO week number — just needs to change
  /// exactly once a week, which a Monday date key already does.
  static String weekKey(DateTime date) => mealDateKey(weekStart(date));

  static int daysCompletedInWeek(
    Set<String> completedDateKeys,
    DateTime weekStartDate,
  ) {
    var count = 0;
    for (var i = 0; i < 7; i++) {
      final key = mealDateKey(weekStartDate.add(Duration(days: i)));
      if (completedDateKeys.contains(key)) count++;
    }
    return count;
  }

  /// Freezes earned for a week with [daysCompleted] logged days.
  static int freezesEarned({
    required int daysCompleted,
    required bool isPro,
  }) {
    if (daysCompleted < freezeEarnThreshold) return 0;
    return isPro ? 2 : 1;
  }

  static DateTime _dateOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}
