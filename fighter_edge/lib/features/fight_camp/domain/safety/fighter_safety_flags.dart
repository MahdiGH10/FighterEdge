/// Switches for fighter-safety content that waits on a sports dietitian
/// (Fuel V2 rule 8). Every switch is off by default, and nothing in the app
/// turns one on until the reviewed numbers and wording are in.
///
/// Rule 3 has no switch: no flag, tier or subscription unlocks advice on
/// fluid or sodium restriction, water loading, sauna, sweat suits,
/// diuretics, laxatives or fasting.
///
/// Pure Dart: no clock, no platform, no network.
// dietitian sign-off pending: keep every default false until review.
class FighterSafetyFlags {
  const FighterSafetyFlags({
    this.refuelVolumes = false,
    this.fightWeekTemplate = false,
  });

  /// Everything off: the release default.
  static const FighterSafetyFlags off = FighterSafetyFlags();

  /// Litres, grams and hours on the refuel timeline. Off: the timeline shows
  /// what to eat and when, with no amounts.
  final bool refuelVolumes;

  /// The day-by-day fight-week information template (D-7 to the week after
  /// the fight).
  final bool fightWeekTemplate;
}
