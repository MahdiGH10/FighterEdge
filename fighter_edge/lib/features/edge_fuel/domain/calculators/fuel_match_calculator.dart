import '../allergen_matching.dart';
import '../models/food_enums.dart';
import '../models/food_item.dart';
import '../models/fuel_match.dart';
import '../models/nutrition_day.dart';
import '../models/nutrition_setup_draft.dart';
import '../models/nutrition_target.dart';
import '../models/recipe.dart';
import 'recipe_nutrient_calculator.dart';

/// Finds useful portions from the curated recipe catalog for the athlete's
/// remaining daily nutrition target.
///
/// This is a pure, deterministic ranking engine. It does not call an AI
/// provider, make medical claims, or write to a log. The result is therefore
/// fast, testable, works offline once the catalog is available, and can safely
/// be used as the factual basis for an AI explanation later.
class FuelMatchCalculator {
  FuelMatchCalculator._();

  static const int minimumUsefulCalories = 150;
  static const int maxOptions = 3;
  static const List<double> _portionOptions = [0.5, 1, 1.5, 2, 2.5];

  static FuelMatch calculate({
    required NutritionTarget? target,
    required NutritionDay? day,
    required Iterable<Recipe> recipes,
    required Map<String, FoodItem> foodsById,
    NutritionSetupDraft? preferences,
  }) {
    final remaining = _Remaining.from(target, day);
    if (remaining == null) {
      return const FuelMatch(status: FuelMatchStatus.needsMoreData);
    }
    if (remaining.calories < minimumUsefulCalories) {
      return FuelMatch(
        status: FuelMatchStatus.noMealNeeded,
        caloriesRemaining: remaining.calories,
        proteinRemaining: remaining.protein,
        carbohydratesRemaining: remaining.carbohydrates,
        fatsRemaining: remaining.fats,
      );
    }

    final allergenMatch = AllergenMatcher.match(preferences?.allergens ?? []);
    final requestedDiet = _dietFrom(preferences?.dietType);
    final requestedBudget = _budgetFrom(preferences?.budgetBand);
    final maximumMinutes = _maximumMinutesFrom(preferences?.cookingTimeBand);
    final disliked = _normalisedTerms(preferences?.dislikedFoods ?? []);
    final candidates = <_Candidate>[];

    for (final recipe in recipes) {
      final allergens = RecipeNutrientCalculator.allergensOf(recipe, foodsById);
      if (allergens.intersection(allergenMatch.matched).isNotEmpty) continue;

      final diets = RecipeNutrientCalculator.dietTagsOf(recipe, foodsById);
      if (requestedDiet != null && !diets.contains(requestedDiet)) continue;
      if (requestedBudget != null && recipe.costBand != requestedBudget) {
        continue;
      }
      if (maximumMinutes != null && recipe.totalMinutes > maximumMinutes) {
        continue;
      }
      if (_containsDislikedFood(recipe, foodsById, disliked)) continue;

      final perServing = RecipeNutrientCalculator.perServing(recipe, foodsById);
      if (perServing.kcal <= 0) continue;

      _Candidate? bestForRecipe;
      for (final servings in _portionOptions) {
        final nutrients = perServing.scaled(servings);
        final score = _score(nutrients, remaining);
        final candidate = _Candidate(
          option: FuelMatchOption(
            recipe: recipe,
            nutrients: nutrients,
            servings: servings,
            allergens: allergens,
            dietTags: diets,
            caloriesRemaining: remaining.calories,
          ),
          score: score,
        );
        if (bestForRecipe == null || candidate.isBetterThan(bestForRecipe)) {
          bestForRecipe = candidate;
        }
      }
      if (bestForRecipe != null) candidates.add(bestForRecipe);
    }

    candidates.sort((a, b) => a.compareTo(b));
    final options = candidates
        .take(maxOptions)
        .map((candidate) => candidate.option)
        .toList(growable: false);

    return FuelMatch(
      status: options.isEmpty ? FuelMatchStatus.noMatch : FuelMatchStatus.ready,
      caloriesRemaining: remaining.calories,
      proteinRemaining: remaining.protein,
      carbohydratesRemaining: remaining.carbohydrates,
      fatsRemaining: remaining.fats,
      options: options,
      unmatchedAllergenTerms: List.unmodifiable(allergenMatch.unmatched),
    );
  }

  static double _score(RecipeNutrients nutrients, _Remaining remaining) {
    // Calories provide the principal fit. Macros are weighted by their actual
    // remaining gap, so a macro already met cannot distort the ranking.
    final calorieFit = _coverage(nutrients.kcal, remaining.calories);
    final proteinFit = _coverage(nutrients.proteinGrams, remaining.protein);
    final carbFit = _coverage(nutrients.carbGrams, remaining.carbohydrates);
    final fatFit = _coverage(nutrients.fatGrams, remaining.fats);
    final overshoot = nutrients.kcal > remaining.calories * 1.12
        ? (nutrients.kcal - remaining.calories * 1.12) / remaining.calories
        : 0.0;
    return calorieFit * .48 +
        proteinFit * .30 +
        carbFit * .16 +
        fatFit * .06 -
        overshoot * .25;
  }

  static double _coverage(double value, int remaining) {
    if (remaining <= 0) return 1;
    return (value / remaining).clamp(0, 1);
  }

  static DietTag? _dietFrom(String? value) => switch (value?.trim()) {
        'vegetarian' => DietTag.vegetarian,
        'vegan' => DietTag.vegan,
        'pescatarian' => DietTag.pescatarian,
        'halal' => DietTag.halal,
        _ => null,
      };

  static CostBand? _budgetFrom(String? value) => switch (value?.trim()) {
        'low' => CostBand.low,
        'medium' => CostBand.medium,
        'high' => CostBand.high,
        _ => null,
      };

  static int? _maximumMinutesFrom(String? value) => switch (value?.trim()) {
        'quick' => 15,
        'moderate' => 30,
        _ => null,
      };

  static Set<String> _normalisedTerms(Iterable<String> values) =>
      values.map(_normalise).where((value) => value.isNotEmpty).toSet();

  static bool _containsDislikedFood(
    Recipe recipe,
    Map<String, FoodItem> foodsById,
    Set<String> disliked,
  ) {
    if (disliked.isEmpty) return false;
    final ingredients = recipe.ingredients
        .map((ingredient) => foodsById[ingredient.foodId]?.name ?? '')
        .join(' ');
    final haystack =
        _normalise('${recipe.title} ${recipe.description} $ingredients');
    // The preference is a direct text match, rather than fuzzy matching. A
    // fuzzy match could silently remove a dish based on an unrelated word.
    return disliked.any(haystack.contains);
  }

  static String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

class _Remaining {
  final int calories;
  final int protein;
  final int carbohydrates;
  final int fats;

  const _Remaining({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
  });

  static _Remaining? from(NutritionTarget? target, NutritionDay? day) {
    if (target?.isSuccess != true) return null;
    final calories = target!.targetCalories;
    final protein = target.proteinGrams;
    final carbs = target.carbGrams;
    final fats = target.fatGrams;
    if (calories == null ||
        protein == null ||
        carbs == null ||
        fats == null ||
        calories <= 0 ||
        protein <= 0 ||
        carbs <= 0 ||
        fats <= 0) {
      return null;
    }
    final totals = day?.totals;
    return _Remaining(
      calories: (calories - (totals?.calories ?? 0)).clamp(0, calories),
      protein: (protein - (totals?.proteinGrams ?? 0)).clamp(0, protein),
      carbohydrates: (carbs - (totals?.carbGrams ?? 0)).clamp(0, carbs),
      fats: (fats - (totals?.fatGrams ?? 0)).clamp(0, fats),
    );
  }
}

class _Candidate {
  final FuelMatchOption option;
  final double score;

  const _Candidate({required this.option, required this.score});

  bool isBetterThan(_Candidate other) => compareTo(other) < 0;

  int compareTo(_Candidate other) {
    final scoreOrder = other.score.compareTo(score);
    if (scoreOrder != 0) return scoreOrder;
    final kcalOrder = (option.nutrients.kcal - option.caloriesRemaining)
        .abs()
        .compareTo(
            (other.option.nutrients.kcal - other.option.caloriesRemaining)
                .abs());
    if (kcalOrder != 0) return kcalOrder;
    return option.recipe.id.compareTo(other.option.recipe.id);
  }
}
