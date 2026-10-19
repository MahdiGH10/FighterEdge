import '../../daily_snapshot/domain/daily_snapshot.dart';
import '../../edge_fuel/domain/calculators/fighter_brief_calculator.dart';
import '../../edge_fuel/domain/models/fighter_brief_preview.dart';
import '../../edge_fuel/domain/models/nutrition_day.dart';
import '../../edge_fuel/domain/models/nutrition_target.dart';
import '../../fight_camp/domain/fight_week_plan.dart';
import '../../fight_camp/domain/weight_path.dart';

/// What the Corner Brief line on Home says: the one thing the app can
/// calculate that matters most today. Safety first, then food.
///
/// Fight week's own steps are not a cue: the fight countdown card above the
/// line on Home already shows them.
enum CornerCue {
  /// The weight path needs supervision or is not safe, or the athlete's
  /// health answers need a professional's review.
  seeProfessional,

  /// No EdgeFuel target yet.
  setUpFuel,

  /// A target, but nothing eaten is logged today.
  firstMeal,

  /// Protein is the day's biggest gap.
  protein,

  /// Carbohydrates are the gap and the planned session is still to come.
  carbsBeforeTraining,

  /// Carbohydrates are the gap.
  carbs,

  /// Calories are the gap.
  calories,

  /// Close to every target.
  onTrack,
}

class CornerLine {
  const CornerLine(this.cue, {this.amount});

  final CornerCue cue;

  /// Grams for [CornerCue.protein] and the carbs cues, kcal for
  /// [CornerCue.calories]; null for the rest.
  final int? amount;

  @override
  bool operator ==(Object other) =>
      other is CornerLine && other.cue == cue && other.amount == amount;

  @override
  int get hashCode => Object.hash(cue, amount);

  @override
  String toString() => 'CornerLine($cue, $amount)';
}

/// Picks the line from facts the app already calculated. Never changes a
/// target.
class CornerBriefCalculator {
  CornerBriefCalculator._();

  static CornerLine line({
    required DailySnapshot today,
    required NutritionTarget? target,
    required NutritionDay? day,
  }) {
    final camp = today.camp;
    final pathStatus = camp?.weightPath.status;
    if (pathStatus == WeightPathStatus.needsSupervision ||
        pathStatus == WeightPathStatus.notSafe ||
        pathStatus == WeightPathStatus.needsProfessionalReview) {
      return const CornerLine(CornerCue.seeProfessional);
    }
    if (target?.isSuccess != true) return const CornerLine(CornerCue.setUpFuel);

    // The thresholds that decide the day's gap live in one place.
    final fuel = FighterBriefCalculator.calculate(target: target, day: day);
    if (!fuel.isReady) return const CornerLine(CornerCue.firstMeal);

    // A fight-week day with fewer carbs has a carb "gap" on purpose.
    final lowerCarbsToday =
        camp?.todaySteps.contains(FightWeekStep.lowerCarbs) ?? false;
    final training = today.training;
    final sessionAhead =
        training.plannedToday != null && !training.plannedTodayDone;
    return switch (fuel.focus) {
      FighterBriefFocus.protein =>
        CornerLine(CornerCue.protein, amount: fuel.proteinRemaining),
      FighterBriefFocus.carbohydrates when lowerCarbsToday =>
        const CornerLine(CornerCue.onTrack),
      FighterBriefFocus.carbohydrates => CornerLine(
          sessionAhead ? CornerCue.carbsBeforeTraining : CornerCue.carbs,
          amount: fuel.carbohydratesRemaining),
      FighterBriefFocus.calories =>
        CornerLine(CornerCue.calories, amount: fuel.caloriesRemaining),
      FighterBriefFocus.onTrack ||
      FighterBriefFocus.firstMeal =>
        const CornerLine(CornerCue.onTrack),
    };
  }
}
