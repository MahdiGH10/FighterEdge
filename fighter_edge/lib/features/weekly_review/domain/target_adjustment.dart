import '../../edge_fuel/domain/models/nutrition_target.dart';

/// Applies an accepted calorie step to the target the nutrition policy
/// produced. It never changes the policy: protein and fat stay as they were,
/// and the carbohydrate grams absorb the difference, so the macros still
/// add up to the new calories.
class TargetAdjustment {
  TargetAdjustment._();

  /// The target with [deltaKcal] added to its calories, or null when [target]
  /// has no usable calories or macros to adjust (a failed or unfinished
  /// target is never touched).
  static NutritionTarget? apply(
    NutritionTarget target,
    int deltaKcal, {
    required DateTime now,
  }) {
    final kcal = target.targetCalories;
    final carbs = target.carbGrams;
    if (!target.isSuccess || kcal == null || carbs == null) return null;
    final newKcal = kcal + deltaKcal;
    final newCarbs = carbs + (deltaKcal / 4).round();
    if (newKcal <= 0 || newCarbs < 0) return null;
    return NutritionTarget(
      status: target.status,
      policyVersion: target.policyVersion,
      calculatedAt: now,
      reasons: target.reasons,
      warnings: target.warnings,
      estimatedRmrKcal: target.estimatedRmrKcal,
      maintenanceRangeLowKcal: target.maintenanceRangeLowKcal,
      maintenanceRangeHighKcal: target.maintenanceRangeHighKcal,
      targetCalories: newKcal,
      proteinGrams: target.proteinGrams,
      fatGrams: target.fatGrams,
      carbGrams: newCarbs,
      fiberGramsLow: target.fiberGramsLow,
      fiberGramsHigh: target.fiberGramsHigh,
      proteinReferenceWeightKg: target.proteinReferenceWeightKg,
      equationProfileUsed: target.equationProfileUsed,
      activityCoefficientUsed: target.activityCoefficientUsed,
      appliedGoalAdjustmentPercent: target.appliedGoalAdjustmentPercent,
      confidence: target.confidence,
    );
  }
}
