import '../allergen_matching.dart';
import '../models/food_enums.dart';
import '../models/food_item.dart';
import '../models/fuel_add_on.dart';
import '../models/nutrition_setup_draft.dart';
import '../models/recipe.dart';

/// The athlete's hard food preferences as one reusable filter: allergens,
/// diet, budget, cooking time and disliked foods.
///
/// Both the calorie-first match and the macro-first gap picker use it, so a
/// rule cannot be loosened in one mode and forgotten in the other. Every rule
/// is a hard exclusion, never a score.
class FuelPreferenceFilter {
  FuelPreferenceFilter._({
    required this.blockedAllergens,
    required this.unmatchedAllergenTerms,
    required this.diet,
    required this.budget,
    required this.maximumMinutes,
    required this.disliked,
  });

  factory FuelPreferenceFilter.from(NutritionSetupDraft? preferences) {
    final allergenMatch = AllergenMatcher.match(preferences?.allergens ?? []);
    return FuelPreferenceFilter._(
      blockedAllergens: allergenMatch.matched,
      unmatchedAllergenTerms: List.unmodifiable(allergenMatch.unmatched),
      diet: _dietFrom(preferences?.dietType),
      budget: _budgetFrom(preferences?.budgetBand),
      maximumMinutes: _maximumMinutesFrom(preferences?.cookingTimeBand),
      disliked: _normalisedTerms(preferences?.dislikedFoods ?? []),
    );
  }

  final Set<Allergen> blockedAllergens;

  /// Allergy terms outside the regulated-allergen catalog. The UI must never
  /// claim a suggestion is safe when this is nonempty.
  final List<String> unmatchedAllergenTerms;
  final DietTag? diet;
  final CostBand? budget;
  final int? maximumMinutes;
  final Set<String> disliked;

  bool allowsAllergens(Set<Allergen> allergens) =>
      allergens.intersection(blockedAllergens).isEmpty;

  bool allowsDiet(Set<DietTag> dietTags) =>
      diet == null || dietTags.contains(diet);

  bool allowsBudget(CostBand costBand) => budget == null || costBand == budget;

  bool allowsMinutes(int totalMinutes) =>
      maximumMinutes == null || totalMinutes <= maximumMinutes!;

  /// True when a recipe passes the allergen set it already derived, the diet
  /// tags, budget, time and dislikes.
  bool allowsRecipe(
    Recipe recipe,
    Map<String, FoodItem> foodsById, {
    required Set<Allergen> allergens,
    required Set<DietTag> dietTags,
  }) {
    if (!allowsAllergens(allergens)) return false;
    if (!allowsDiet(dietTags)) return false;
    if (!allowsBudget(recipe.costBand)) return false;
    if (!allowsMinutes(recipe.totalMinutes)) return false;
    return !_recipeHasDislikedFood(recipe, foodsById);
  }

  /// True when an add-on's food passes allergens, diet, time and dislikes.
  /// Budget does not apply: an add-on carries no cost band.
  bool allowsAddOn(FuelAddOn addOn, FoodItem food) {
    if (!allowsAllergens(food.allergens)) return false;
    if (!allowsDiet(food.dietTags)) return false;
    if (!allowsMinutes(addOn.prepMinutes)) return false;
    if (disliked.isEmpty) return true;
    return !disliked.any(_normalise(food.name).contains);
  }

  bool _recipeHasDislikedFood(
    Recipe recipe,
    Map<String, FoodItem> foodsById,
  ) {
    if (disliked.isEmpty) return false;
    final ingredients = recipe.ingredients
        .map((ingredient) => foodsById[ingredient.foodId]?.name ?? '')
        .join(' ');
    final haystack =
        _normalise('${recipe.title} ${recipe.description} $ingredients');
    // A direct text match, not fuzzy: a fuzzy match could silently remove a
    // dish for an unrelated word.
    return disliked.any(haystack.contains);
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

  static String _normalise(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9 ]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
