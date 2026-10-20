import '../models/nutrition_enums.dart';

/// A weight-change rate after the safety clamps.
class AppliedWeightRate {
  const AppliedWeightRate({
    required this.percentPerWeek,
    required this.wasClamped,
  });

  /// Magnitude of the weekly change as a percentage of body weight. Zero for
  /// maintenance. The goal gives the direction.
  final double percentPerWeek;

  /// True when the requested rate was above the safe maximum or not usable.
  final bool wasClamped;
}

/// Weight change as a percentage of body weight per week (policy v2), per
/// `docs/NUTRITION_COMPETITOR_RESEARCH.md` section 10.2. Values are
/// implementation defaults pending dietitian review.
class WeightRatePolicy {
  const WeightRatePolicy._();

  /// Approximate energy of 1 kg of body mass change. An approximation; the
  /// weekly check-in corrects it from real data.
  static const double kcalPerKg = 7700;

  /// Fat loss options per week (Helms 2014: 0.5-1%/wk keeps lean mass).
  static const List<double> lossOptionsPercent = [0.25, 0.5, 0.75, 1.0];
  static const double lossDefaultPercent = 0.5;

  /// Muscle gain options per week. Inferred consensus; owner/expert review.
  static const List<double> gainOptionsPercent = [0.1, 0.25, 0.5];
  static const double gainDefaultPercent = 0.25;

  /// Loss is capped at 1% of body weight AND 1 kg per week (ISSN 2025 camp
  /// guidance: 0.5-1 kg/week). The tighter of the two applies.
  static const double maxLossPercentPerWeek = 1.0;
  static const double maxLossKgPerWeek = 1.0;
  static const double maxGainPercentPerWeek = 0.5;

  /// The largest allowed weekly rate for [goal] at [weightKg], as a percent.
  static double maxPercentFor(NutritionGoal goal, double weightKg) {
    switch (goal) {
      case NutritionGoal.maintain:
        return 0;
      case NutritionGoal.gainMuscle:
        return maxGainPercentPerWeek;
      case NutritionGoal.loseFat:
        if (!weightKg.isFinite || weightKg <= 0) return 0;
        final kgCap = maxLossKgPerWeek / weightKg * 100;
        return kgCap < maxLossPercentPerWeek ? kgCap : maxLossPercentPerWeek;
    }
  }

  /// The rate each existing [GoalPace] stands for in policy v2, or null when
  /// the pace does not belong to the goal.
  static double? percentForPace(GoalPace? pace, NutritionGoal goal) {
    switch (goal) {
      case NutritionGoal.maintain:
        return 0;
      case NutritionGoal.loseFat:
        return switch (pace) {
          GoalPace.gentle => 0.25,
          GoalPace.standard => 0.5,
          GoalPace.upperLimit => 0.75,
          _ => null,
        };
      case NutritionGoal.gainMuscle:
        return switch (pace) {
          GoalPace.conservative => 0.1,
          GoalPace.gainStandard => 0.25,
          _ => null,
        };
    }
  }

  static double defaultPercentFor(NutritionGoal goal) => switch (goal) {
        NutritionGoal.maintain => 0,
        NutritionGoal.loseFat => lossDefaultPercent,
        NutritionGoal.gainMuscle => gainDefaultPercent,
      };

  /// Clamps [requestedPercent] into the safe range for [goal] and [weightKg].
  /// A missing, non-finite or negative request falls back to the goal's
  /// default, then to the cap if even that is above it.
  static AppliedWeightRate apply({
    required NutritionGoal goal,
    required double weightKg,
    double? requestedPercent,
  }) {
    if (goal == NutritionGoal.maintain) {
      return const AppliedWeightRate(percentPerWeek: 0, wasClamped: false);
    }
    final cap = maxPercentFor(goal, weightKg);
    final usable = requestedPercent != null &&
        requestedPercent.isFinite &&
        requestedPercent >= 0;
    final wanted = usable ? requestedPercent : defaultPercentFor(goal);
    final applied = wanted > cap ? cap : wanted;
    return AppliedWeightRate(
      percentPerWeek: applied,
      wasClamped: !usable || wanted > cap,
    );
  }

  /// Daily energy gap for a weekly [percentPerWeek] change at [weightKg].
  static double dailyKcalFor(double percentPerWeek, double weightKg) =>
      percentPerWeek / 100 * weightKg * kcalPerKg / 7;
}
