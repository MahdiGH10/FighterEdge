/// Where a date sits relative to the athlete's fight, as the training plan
/// sees it. Derived from the existing fight-camp phase (`CampPhase`) plus the
/// day counts in `phase_modifiers.dart`; see `FightContext.phaseOn`.
enum TrainingPhase {
  /// No fight, or one far enough away to ignore.
  general,
  build,
  peak,

  /// The last days before the fight: volume and intensity come down.
  taper,

  /// The weigh-in day itself.
  weighIn,

  /// After the weigh-in, before the fight.
  refuel,
  fightDay,

  /// The week after the fight.
  postFight,
}
