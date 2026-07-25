import '../models/nutrition_enums.dart';

/// Versioned, centrally configured constants for the deterministic nutrition
/// engine (master prompt §7.3–§7.6). Nothing here reads Flutter, Firebase,
/// the clock, or the network — policy values only, plus the pure math that
/// looks them up.
///
/// Bump [version] whenever a constant below changes, so a stored
/// [NutritionTarget.policyVersion] always identifies exactly which rules
/// produced it. All values are implementation defaults pending qualified
/// dietitian review — see `docs/edge_fuel/SAFETY_AND_EVIDENCE.md`.
class NutritionPolicy {
  const NutritionPolicy._();

  static const int version = 1;

  // ---- §7.3 activity coefficients ----
  static const Map<ActivityLevel, double> activityCoefficients = {
    ActivityLevel.veryLow: 1.20,
    ActivityLevel.light: 1.35,
    ActivityLevel.moderate: 1.50,
    ActivityLevel.high: 1.70,
    ActivityLevel.veryHigh: 1.90,
  };

  static double activityCoefficientFor(ActivityLevel level) =>
      activityCoefficients[level]!;

  /// Maintenance-range half-width, e.g. 0.10 == ±10%.
  static const double maintenanceRangeFraction = 0.10;

  // ---- §7.4 goal adjustment (fraction of maintenance calories) ----
  static const double fatLossDeficitDefault = 0.15;
  static const double fatLossDeficitMin = 0.10;
  static const double fatLossDeficitMax = 0.15;

  static const double muscleGainSurplusDefault = 0.08;
  static const double muscleGainSurplusMin = 0.05;
  static const double muscleGainSurplusMax = 0.10;

  /// Fraction for each [GoalPace]. Maintenance always resolves to 0
  /// regardless of pace.
  static double adjustmentFractionFor(GoalPace? pace, NutritionGoal goal) {
    if (goal == NutritionGoal.maintain) return 0;
    switch (goal) {
      case NutritionGoal.loseFat:
        return switch (pace) {
          GoalPace.gentle => 0.10,
          GoalPace.upperLimit => 0.20,
          _ => fatLossDeficitDefault, // standard, or unspecified
        };
      case NutritionGoal.gainMuscle:
        return switch (pace) {
          GoalPace.conservative => 0.05,
          _ => muscleGainSurplusDefault, // gainStandard, or unspecified
        };
      case NutritionGoal.maintain:
        return 0;
    }
  }

  // ---- §7.5 protein ----
  static const double proteinGPerKgLoseOrGain = 1.8;
  static const double proteinGPerKgMaintain = 1.6;
  static const double proteinGPerKgMin = 1.4;
  static const double proteinGPerKgMax = 2.2;

  static double proteinGPerKgFor(NutritionGoal goal) =>
      goal == NutritionGoal.maintain
          ? proteinGPerKgMaintain
          : proteinGPerKgLoseOrGain;

  // ---- §7.5 fat ----
  static const double fatPercentOfEnergyMin = 0.25;
  static const double fatPercentOfEnergyDefault = 0.275;
  static const double fatPercentOfEnergyMax = 0.30;

  // ---- §7.5 fiber ----
  static const double fiberGPer1000KcalLow = 12.0;
  static const double fiberGPer1000KcalDefault = 14.0;
  static const double fiberGPer1000KcalHigh = 16.0;

  // ---- §7.5 carbohydrate performance floor ----
  /// Below this g/kg on a high training load, flag a warning instead of
  /// silently under-fueling training (master prompt §7.5).
  static const double carbPerformanceFloorGPerKg = 3.0;

  // ---- §7.6 rounding ----
  static int roundCaloriesToNearestTen(double kcal) => (kcal / 10).round() * 10;

  static int roundGrams(double grams) => grams.round();

  /// Macro-derived calories must stay within this many kcal of the target.
  static const int macroReconciliationToleranceKcal = 20;

  // ---- §6 age/BMI guardrails ----
  static const int minimumAgeYears = 18;

  /// WHO adult underweight cutoff. Flagged as a placeholder guardrail in
  /// SAFETY_AND_EVIDENCE.md pending sport-specific dietitian review.
  static const double underweightBmiCutoff = 18.5;
}
