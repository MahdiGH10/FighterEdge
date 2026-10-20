import '../models/intensity.dart';
import '../models/reason_code.dart';
import '../models/training_phase.dart';

/// How a fight-camp phase changes a day's training.
class PhaseModifier {
  const PhaseModifier({
    required this.volume,
    required this.maxIntensity,
    this.allowsSparring = true,
    this.trainable = true,
    this.forcesRecovery = false,
    this.reason,
  });

  /// Multiplier on session length and rounds.
  final double volume;

  /// Ceiling on a session's intensity.
  final Intensity maxIntensity;
  final bool allowsSparring;

  /// False on days the athlete does not train at all (the fight, the rest
  /// between weigh-in and fight).
  final bool trainable;

  /// Every chosen day becomes a light recovery session.
  final bool forcesRecovery;

  /// Added to the day's reasons when this phase applies.
  final ReasonCode? reason;
}

/// Fight phase to volume / intensity multipliers.
///
/// NEEDS COACH REVIEW. Only the taper's -40% volume and the light weigh-in
/// day come from the proposal (decision 6); every other value is an app
/// default chosen to keep the plan simple until a coach signs off.
class PhaseModifiers {
  PhaseModifiers._();

  /// Taper: volume about -40% (proposal decision 6).
  static const double taperVolume = 0.6;

  /// Weigh-in day and post-fight week: light only.
  static const double lightVolume = 0.5;

  /// Peak: a small trim while intensity stays high.
  static const double peakVolume = 0.9;

  static const PhaseModifier general = PhaseModifier(
    volume: 1,
    maxIntensity: Intensity.hard,
    reason: ReasonCode.generalPhase,
  );

  static const PhaseModifier build = PhaseModifier(
    volume: 1,
    maxIntensity: Intensity.hard,
    reason: ReasonCode.buildPhase,
  );

  static const PhaseModifier peak = PhaseModifier(
    volume: peakVolume,
    maxIntensity: Intensity.hard,
    reason: ReasonCode.peakPhase,
  );

  static const PhaseModifier taper = PhaseModifier(
    volume: taperVolume,
    maxIntensity: Intensity.moderate,
    allowsSparring: false,
    reason: ReasonCode.taperFightWeek,
  );

  static const PhaseModifier weighIn = PhaseModifier(
    volume: lightVolume,
    maxIntensity: Intensity.light,
    allowsSparring: false,
    forcesRecovery: true,
    reason: ReasonCode.weighInLight,
  );

  static const PhaseModifier refuel = PhaseModifier(
    volume: 0,
    maxIntensity: Intensity.light,
    allowsSparring: false,
    trainable: false,
    reason: ReasonCode.refuelDayRest,
  );

  static const PhaseModifier fightDay = PhaseModifier(
    volume: 0,
    maxIntensity: Intensity.light,
    allowsSparring: false,
    trainable: false,
    reason: ReasonCode.fightDayRest,
  );

  static const PhaseModifier postFight = PhaseModifier(
    volume: lightVolume,
    maxIntensity: Intensity.light,
    allowsSparring: false,
    forcesRecovery: true,
    reason: ReasonCode.postFightRecovery,
  );

  static PhaseModifier forPhase(TrainingPhase phase) => switch (phase) {
        TrainingPhase.general => general,
        TrainingPhase.build => build,
        TrainingPhase.peak => peak,
        TrainingPhase.taper => taper,
        TrainingPhase.weighIn => weighIn,
        TrainingPhase.refuel => refuel,
        TrainingPhase.fightDay => fightDay,
        TrainingPhase.postFight => postFight,
      };
}
