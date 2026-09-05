import '../models/food_enums.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';

/// Nutrients for a recipe, a serving, or any scaled portion of one.
class RecipeNutrients {
  final double kcal;
  final double proteinGrams;
  final double carbGrams;
  final double fatGrams;
  final double fibreGrams;

  const RecipeNutrients({
    this.kcal = 0,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
    this.fibreGrams = 0,
  });

  RecipeNutrients operator +(RecipeNutrients other) => RecipeNutrients(
    kcal: kcal + other.kcal,
    proteinGrams: proteinGrams + other.proteinGrams,
    carbGrams: carbGrams + other.carbGrams,
    fatGrams: fatGrams + other.fatGrams,
    fibreGrams: fibreGrams + other.fibreGrams,
  );

  RecipeNutrients scaled(double factor) => RecipeNutrients(
    kcal: kcal * factor,
    proteinGrams: proteinGrams * factor,
    carbGrams: carbGrams * factor,
    fatGrams: fatGrams * factor,
    fibreGrams: fibreGrams * factor,
  );

  /// Rounded for display and for writing into a food log, which stores ints.
  /// Rounding happens once, at the boundary — never mid-aggregation, where it
  /// would compound across a dozen ingredients.
  int get kcalRounded => kcal.round();
  int get proteinRounded => proteinGrams.round();
  int get carbsRounded => carbGrams.round();
  int get fatRounded => fatGrams.round();
  int get fibreRounded => fibreGrams.round();

  @override
  String toString() =>
      '$kcalRounded kcal / P$proteinRounded '
      'C$carbsRounded F$fatRounded';
}

/// Thrown when a recipe references a food that is not in the catalog.
///
/// This is deliberately loud. Silently treating an unresolvable ingredient as
/// zero would under-state a recipe's calories — the most dangerous direction to
/// be wrong in for a user cutting weight.
class UnknownFoodException implements Exception {
  final String recipeId;
  final String foodId;

  const UnknownFoodException(this.recipeId, this.foodId);

  @override
  String toString() => 'Recipe "$recipeId" references unknown food "$foodId"';
}

/// The single authority for recipe nutrition (master prompt §2.4, §9.2).
///
/// Mirrors `NutritionTargetCalculator`'s role: nothing else in the app may
/// derive a recipe's macros, and no recipe stores them. Pure Dart, no clock, no
/// I/O — hand it a recipe and a resolved food table.
class RecipeNutrientCalculator {
  RecipeNutrientCalculator._();

  /// Nutrients for the whole recipe as written, across all [Recipe.servings].
  ///
  /// Optional ingredients are excluded unless [includeOptional] is true. They
  /// are garnish-level by content policy, so the difference is small, and
  /// excluding keeps the figure describing the recipe as most people make it.
  static RecipeNutrients forRecipe(
    Recipe recipe,
    Map<String, FoodItem> foods, {
    bool includeOptional = false,
  }) {
    var total = const RecipeNutrients();
    for (final ingredient in recipe.ingredients) {
      if (ingredient.optional && !includeOptional) continue;
      final food = foods[ingredient.foodId];
      if (food == null) {
        throw UnknownFoodException(recipe.id, ingredient.foodId);
      }
      total = total + _forIngredientGrams(food, ingredient.grams);
    }
    return total;
  }

  /// Nutrients for one serving.
  static RecipeNutrients perServing(
    Recipe recipe,
    Map<String, FoodItem> foods, {
    bool includeOptional = false,
  }) {
    final servings = recipe.servings < 1 ? 1 : recipe.servings;
    return forRecipe(
      recipe,
      foods,
      includeOptional: includeOptional,
    ).scaled(1 / servings);
  }

  /// Nutrients for an arbitrary number of servings — what the detail screen's
  /// serving stepper renders. Fractional servings are supported.
  static RecipeNutrients forServings(
    Recipe recipe,
    Map<String, FoodItem> foods,
    double servings, {
    bool includeOptional = false,
  }) {
    if (servings <= 0) return const RecipeNutrients();
    return perServing(
      recipe,
      foods,
      includeOptional: includeOptional,
    ).scaled(servings);
  }

  /// Nutrients contributed by a weight of a single food.
  static RecipeNutrients forFood(FoodItem food, double grams) =>
      _forIngredientGrams(food, grams);

  static RecipeNutrients _forIngredientGrams(FoodItem food, double grams) {
    if (grams <= 0) return const RecipeNutrients();
    final factor = grams / 100.0;
    return RecipeNutrients(
      kcal: food.kcalPer100g * factor,
      proteinGrams: food.proteinPer100g * factor,
      carbGrams: food.carbsPer100g * factor,
      fatGrams: food.fatPer100g * factor,
      fibreGrams: food.fibrePer100g * factor,
    );
  }

  /// Allergens a recipe carries: the union of its ingredients' allergens plus
  /// any the ingredient list cannot express.
  ///
  /// Derived rather than hand-authored — hand-tagging is how an allergen gets
  /// missed. Optional ingredients are **always** included here regardless of
  /// [RecipeNutrientCalculator.forRecipe]'s `includeOptional`: an allergen the
  /// user might encounter must be declared even if its calories are not
  /// counted.
  static Set<Allergen> allergensOf(Recipe recipe, Map<String, FoodItem> foods) {
    final out = <Allergen>{...recipe.extraAllergens};
    for (final ingredient in recipe.ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) {
        throw UnknownFoodException(recipe.id, ingredient.foodId);
      }
      out.addAll(food.allergens);
    }
    return out;
  }

  /// Diets a recipe is compatible with: the intersection of its ingredients'
  /// diet tags. A recipe is vegan only if every ingredient is.
  ///
  /// Optional ingredients count — an optional knob of butter still makes the
  /// dish non-vegan for anyone who follows the recipe as written.
  static Set<DietTag> dietTagsOf(Recipe recipe, Map<String, FoodItem> foods) {
    if (recipe.ingredients.isEmpty) return const {};
    Set<DietTag>? intersection;
    for (final ingredient in recipe.ingredients) {
      final food = foods[ingredient.foodId];
      if (food == null) {
        throw UnknownFoodException(recipe.id, ingredient.foodId);
      }
      intersection = intersection == null
          ? {...food.dietTags}
          : intersection.intersection(food.dietTags);
      if (intersection.isEmpty) return const {};
    }
    return intersection ?? const {};
  }
}
