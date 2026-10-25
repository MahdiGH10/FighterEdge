import '../../edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import '../../edge_fuel/domain/models/nutrition_profile.dart';
import '../../edge_fuel/domain/models/nutrition_target.dart';
import '../../edge_fuel/domain/policies/nutrition_policy.dart';

/// Recalculates a proposed weekly step through the nutrition policy. A step
/// that crosses a floor or cannot be expressed exactly is declined.
class TargetAdjustment {
  TargetAdjustment._();

  /// The target with [deltaKcal] added to its calories, or null when [target]
  /// has no usable calories or macros to adjust (a failed or unfinished
  /// target is never touched).
  static NutritionTarget? apply(
    NutritionTarget target,
    int deltaKcal, {
    required NutritionProfile profile,
    required DateTime now,
  }) {
    final kcal = target.targetCalories;
    if (!target.isSuccess ||
        target.policyVersion != NutritionPolicy.v1 ||
        kcal == null ||
        deltaKcal == 0) {
      return null;
    }
    final newKcal = kcal + deltaKcal;
    if (newKcal <= 0) return null;
    final recalculated = NutritionTargetCalculator.calculate(
      profile,
      now: now,
      requestedCalories: newKcal,
    );
    return recalculated.isSuccess && recalculated.targetCalories == newKcal
        ? recalculated
        : null;
  }
}
