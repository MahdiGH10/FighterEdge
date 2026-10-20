import '../models/nutrition_enums.dart';

/// Constants for nutrition policy version 2 (training-aware targets).
///
/// Policy v1 stays in `NutritionPolicy` and is never edited: a stored v1
/// target must keep reproducing. These values come from
/// `docs/NUTRITION_COMPETITOR_RESEARCH.md` sections 10 and 14 and are
/// implementation defaults pending qualified dietitian review.
class NutritionPolicyV2 {
  const NutritionPolicyV2._();

  /// Bump when any value in this class, the session energy table, or the
  /// weight-rate policy changes.
  static const int version = 2;

  /// RMR multiplier for movement OUTSIDE planned training. Planned sessions
  /// are costed separately by `SessionEnergyTable`, so this deliberately tops
  /// out at 1.55 (research section 10.1) and never double-counts the gym.
  static const Map<ActivityLevel, double> nonTrainingFactors = {
    ActivityLevel.veryLow: 1.20,
    ActivityLevel.light: 1.30,
    ActivityLevel.moderate: 1.40,
    ActivityLevel.high: 1.50,
    ActivityLevel.veryHigh: 1.55,
  };

  static double nonTrainingFactorFor(ActivityLevel level) =>
      nonTrainingFactors[level]!;

  // ---- protein (ISSN 2025 practical 1.6-2.2 g/kg; ACSM 1.2-2.0) ----
  /// Of TARGET weight while losing fat.
  static const double proteinGPerKgLosing = 2.0;

  /// Of current weight while maintaining or gaining.
  static const double proteinGPerKgOther = 1.8;

  /// Hard floor, of current weight, on every day.
  static const double proteinFloorGPerKg = 1.2;

  // ---- fat ----
  static const double fatPercentOfEnergy = 0.275;

  /// Hard floor, of current weight, on every day.
  static const double fatFloorGPerKg = 0.5;

  // ---- carbohydrate ----
  /// Hard floor, of current weight, on every day (ISSN 2025 position 6).
  static const double carbFloorGPerKg = 3.0;

  // ---- training-day / rest-day shift ----
  /// Share of each day's session-energy difference from the weekly mean that
  /// moves into that day's intake. 0 turns the shift off; 1 would eat back
  /// every session. The weekly total never changes.
  static const double trainingDayShiftFraction = 0.5;

  /// A day whose planned sessions cost at least this many kcal per kg of body
  /// weight counts as a hard day even with no hard session in it.
  static const double hardDaySessionKcalPerKg = 6.0;

  // ---- rounding ----
  static int roundToTen(double kcal) => (kcal / 10).round() * 10;

  static int ceilToTen(double kcal) => (kcal / 10).ceil() * 10;
}
