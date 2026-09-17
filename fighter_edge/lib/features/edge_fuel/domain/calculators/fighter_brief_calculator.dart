import '../models/fighter_brief_preview.dart';
import '../models/nutrition_day.dart';
import '../models/nutrition_target.dart';

/// Produces the free Fighter Brief preview from trusted local facts.
///
/// The calculator never changes a target and never calls an AI provider. A
/// premium AI brief can use this output as its factual foundation later.
class FighterBriefCalculator {
  FighterBriefCalculator._();

  static FighterBriefPreview calculate({
    required NutritionTarget? target,
    required NutritionDay? day,
  }) {
    if (target?.isSuccess != true || !_hasConsumedEntry(day)) {
      return FighterBriefPreview.needsMoreData();
    }

    final targetCalories = target!.targetCalories;
    final targetProtein = target.proteinGrams;
    final targetCarbs = target.carbGrams;
    final targetFats = target.fatGrams;
    if (targetCalories == null ||
        targetProtein == null ||
        targetCarbs == null ||
        targetFats == null ||
        targetCalories <= 0 ||
        targetProtein <= 0 ||
        targetCarbs <= 0 ||
        targetFats <= 0) {
      return FighterBriefPreview.needsMoreData();
    }

    final totals = day!.totals;
    final caloriesRemaining = _remaining(targetCalories, totals.calories);
    final proteinRemaining = _remaining(targetProtein, totals.proteinGrams);
    final carbohydratesRemaining = _remaining(targetCarbs, totals.carbGrams);
    final fatsRemaining = _remaining(targetFats, totals.fatGrams);

    final proteinGap = proteinRemaining / targetProtein;
    final carbohydratesGap = carbohydratesRemaining / targetCarbs;
    final caloriesGap = caloriesRemaining / targetCalories;

    final focus = proteinGap >= .25
        ? FighterBriefFocus.protein
        : carbohydratesGap >= .35
            ? FighterBriefFocus.carbohydrates
            : caloriesGap >= .30
                ? FighterBriefFocus.calories
                : FighterBriefFocus.onTrack;

    return FighterBriefPreview(
      status: FighterBriefStatus.ready,
      focus: focus,
      summary: switch (focus) {
        FighterBriefFocus.protein =>
          'Protein is the main gap in today\'s target.',
        FighterBriefFocus.carbohydrates =>
          'Carbohydrates are the main gap before hard work.',
        FighterBriefFocus.calories => 'You still have fuel to cover today.',
        FighterBriefFocus.onTrack => 'You are close to today\'s target.',
        FighterBriefFocus.firstMeal =>
          'Log a meal to see your first Fighter Brief.',
      },
      nextAction: switch (focus) {
        FighterBriefFocus.protein => 'Prioritize a protein-rich meal next.',
        FighterBriefFocus.carbohydrates =>
          'Add carbohydrates around your next session.',
        FighterBriefFocus.calories =>
          'Plan your next meal before the day gets away.',
        FighterBriefFocus.onTrack =>
          'Keep your next meal balanced and protect recovery.',
        FighterBriefFocus.firstMeal =>
          'Log a meal to unlock your personalized next step.',
      },
      caloriesRemaining: caloriesRemaining,
      proteinRemaining: proteinRemaining,
      carbohydratesRemaining: carbohydratesRemaining,
      fatsRemaining: fatsRemaining,
    );
  }

  static bool _hasConsumedEntry(NutritionDay? day) {
    return day?.entries.any((entry) => entry.consumed) ?? false;
  }

  static int _remaining(int target, int consumed) =>
      (target - consumed).clamp(0, target);
}
