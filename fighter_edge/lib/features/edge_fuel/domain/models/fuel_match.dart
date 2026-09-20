import '../calculators/recipe_nutrient_calculator.dart';
import 'food_enums.dart';
import 'recipe.dart';

/// The result of matching a curated meal to an athlete's remaining daily fuel.
///
/// This is intentionally separate from the AI response model. Every macro in
/// a [FuelMatchOption] comes from the versioned food and recipe catalog, so a
/// model can never invent a calorie or portion recommendation.
enum FuelMatchStatus {
  ready,
  needsMoreData,
  noMealNeeded,
  noMatch,
}

class FuelMatchOption {
  final Recipe recipe;
  final RecipeNutrients nutrients;

  /// Number of recipe servings to prepare. Fractional servings are supported
  /// by the recipe detail and logging flows.
  final double servings;
  final Set<Allergen> allergens;
  final Set<DietTag> dietTags;
  final int caloriesRemaining;

  const FuelMatchOption({
    required this.recipe,
    required this.nutrients,
    required this.servings,
    required this.allergens,
    required this.dietTags,
    required this.caloriesRemaining,
  });

  int get calorieCoveragePercent => caloriesRemaining <= 0
      ? 100
      : (nutrients.kcal / caloriesRemaining * 100).round().clamp(0, 999);
}

class FuelMatch {
  final FuelMatchStatus status;
  final int caloriesRemaining;
  final int proteinRemaining;
  final int carbohydratesRemaining;
  final int fatsRemaining;
  final List<FuelMatchOption> options;

  /// Allergy terms that are not covered by the finite regulated-allergen
  /// catalog. The UI must never claim a recipe is safe when this is nonempty.
  final List<String> unmatchedAllergenTerms;

  const FuelMatch({
    required this.status,
    this.caloriesRemaining = 0,
    this.proteinRemaining = 0,
    this.carbohydratesRemaining = 0,
    this.fatsRemaining = 0,
    this.options = const [],
    this.unmatchedAllergenTerms = const [],
  });

  bool get isReady => status == FuelMatchStatus.ready;
}
