import 'weekly_adherence.dart';

/// Streak freezes under the weekly target. A freeze covers one missed
/// planned session in a week, never a rest day, and is only spent when it
/// brings the week up to its target.
class FreezeRules {
  FreezeRules._();

  static const int maxCoveredPerWeek = 1;

  /// How many missed sessions a freeze covers for [adherence]: 0 or
  /// [maxCoveredPerWeek].
  static int covered(WeeklyAdherence adherence,
      {required int freezesAvailable}) {
    if (freezesAvailable < 1 || adherence.missed < 1) return 0;
    if (adherence.completed >= adherence.target) return 0;
    return adherence.completed + maxCoveredPerWeek >= adherence.target
        ? maxCoveredPerWeek
        : 0;
  }

  /// [adherence] with a freeze applied when one helps.
  static WeeklyAdherence apply(
    WeeklyAdherence adherence, {
    required int freezesAvailable,
  }) =>
      adherence.withFreezeCovered(
        covered(adherence, freezesAvailable: freezesAvailable),
      );
}
