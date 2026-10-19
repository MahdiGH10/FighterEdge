import 'weekly_adherence.dart';

/// The weekly streak.
class WeeklyStreak {
  const WeeklyStreak({
    required this.count,
    required this.currentWeekMet,
    required this.currentWeekAlive,
  });

  /// Consecutive weeks that met the target, counting the current week once
  /// it has. 0 when the current week can no longer meet its target.
  final int count;

  /// The open week has already met its target.
  final bool currentWeekMet;

  /// The open week has met, or can still meet, its target.
  final bool currentWeekAlive;

  /// Weeks oldest first, contiguous; the last one may be the open week.
  ///
  /// - A rest-only week (nothing planned) is neutral: it neither extends nor
  ///   breaks the streak.
  /// - A closed week that missed its target resets the streak.
  /// - The open week keeps the streak alive while its target is still
  ///   possible, and adds one once met.
  static WeeklyStreak of(List<WeeklyAdherence> weeks) {
    var run = 0;
    var currentMet = false;
    var currentAlive = true;
    for (final week in weeks) {
      if (week.isRestOnly) continue;
      if (week.closed) {
        run = week.met ? run + 1 : 0;
        continue;
      }
      currentMet = week.met;
      currentAlive = week.alive;
      if (week.met) {
        run++;
      } else if (!week.alive) {
        run = 0;
      }
    }
    return WeeklyStreak(
      count: run,
      currentWeekMet: currentMet,
      currentWeekAlive: currentAlive,
    );
  }
}
