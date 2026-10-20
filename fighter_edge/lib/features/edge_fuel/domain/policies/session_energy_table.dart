import '../models/planned_fuel_session.dart';

/// Energy cost of planned training sessions (policy v2).
///
/// DIETITIAN SIGN-OFF PENDING: every value here is an implementation default
/// taken from the Compendium of Physical Activities (Ainsworth 2011) and then
/// deliberately lowered, so that planned energy is never overstated. The
/// numbers are not reviewed by a qualified dietitian, and
/// [dietitianSignOffPending] stays `true` until one has. Nothing in the app
/// may present the table as clinically validated.
///
/// Method, from `docs/NUTRITION_COMPETITOR_RESEARCH.md` section 10.1:
///
/// ```text
/// session kcal = (MET - 1) x body weight kg x effective hours
/// ```
///
/// The table holds gross METs (as the Compendium does). One MET is removed
/// because the resting part of the session is already inside the
/// RMR x non-training factor base, and counting it twice would inflate every
/// target.
class SessionEnergyTable {
  const SessionEnergyTable._();

  /// Bump when any value below changes.
  static const int tableVersion = 1;

  /// See the class comment. Do not flip without a recorded sign-off.
  static const bool dietitianSignOffPending = true;

  /// Minutes counted at full cost. Beyond this a session is longer and
  /// therefore paced lower, so the extra minutes count at
  /// [longSessionTaperFactor].
  static const int fullCostMinutes = 90;
  static const double longSessionTaperFactor = 0.8;

  /// A session is never costed beyond this, whatever the caller passes.
  static const int maxCountedMinutes = 240;

  // light, moderate, hard (gross METs).
  static const Map<FuelDiscipline, List<double>> _grossMets = {
    // Compendium: boxing bag 5.5, general 7.8, sparring 12.8.
    FuelDiscipline.boxing: [4.5, 7.0, 9.0],
    // Compendium: martial arts, kickboxing 10.3; slower or novice 5.3.
    FuelDiscipline.kickboxing: [5.0, 7.5, 9.5],
    FuelDiscipline.muayThai: [5.0, 7.5, 9.5],
    // Compendium: wrestling 6.0.
    FuelDiscipline.wrestling: [4.5, 6.0, 8.5],
    // Compendium: judo / jujitsu 10.3 is competition pace; live rolling is
    // lower.
    FuelDiscipline.bjj: [4.0, 6.0, 8.0],
    FuelDiscipline.mma: [5.0, 7.5, 9.5],
    // Compendium: resistance training 3.5 (light/moderate), 5.0 (vigorous),
    // 6.0 (powerlifting).
    FuelDiscipline.strength: [3.0, 4.5, 5.5],
    // Compendium: circuit training 4.3 (moderate), 8.0 (vigorous).
    FuelDiscipline.conditioning: [4.5, 7.0, 9.0],
    FuelDiscipline.other: [2.0, 2.5, 3.0],
  };

  /// Gross MET for a discipline and intensity.
  static double grossMet(FuelDiscipline discipline, FuelIntensity intensity) =>
      _grossMets[discipline]![intensity.index];

  /// MET above rest, the value used to cost a session.
  static double netMet(FuelDiscipline discipline, FuelIntensity intensity) =>
      grossMet(discipline, intensity) - 1;

  /// Minutes that count toward the cost: clamped to 0..[maxCountedMinutes],
  /// with minutes beyond [fullCostMinutes] discounted.
  static double effectiveHours(int durationMinutes) {
    final minutes = durationMinutes.clamp(0, maxCountedMinutes);
    final full = minutes < fullCostMinutes ? minutes : fullCostMinutes;
    final extra = minutes - full;
    return (full + extra * longSessionTaperFactor) / 60;
  }

  /// Energy of one session in kcal, unrounded. Zero for a non-positive weight
  /// or duration.
  static double sessionKcal(PlannedFuelSession session, double weightKg) {
    if (!weightKg.isFinite || weightKg <= 0) return 0;
    return netMet(session.discipline, session.intensity) *
        weightKg *
        effectiveHours(session.durationMinutes);
  }
}
