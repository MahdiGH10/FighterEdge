import '../calculators/recipe_nutrient_calculator.dart';
import '../models/food_enums.dart';
import '../models/food_item.dart';
import '../models/recipe.dart';

/// One problem found in bundled catalog content.
///
/// Catalog content is authored by hand, so it is the most likely thing in the
/// feature to be quietly wrong. Validation runs in unit tests (so a bad record
/// fails CI) and in debug at startup (so it fails loudly in development), per
/// master prompt §9.2.
class CatalogIssue {
  /// Id of the offending record, or `<index N>` when the id itself is missing.
  final String recordId;
  final String message;

  const CatalogIssue(this.recordId, this.message);

  @override
  String toString() => '$recordId: $message';
}

/// Validates the bundled food table.
///
/// These are content-integrity checks, not nutrition science: they catch typos,
/// duplicates, and physically impossible records. They cannot tell you a value
/// is the *wrong* USDA figure — only a reviewer can.
class FoodCatalogValidator {
  FoodCatalogValidator._();

  /// Relative drift allowed between stated and macro-implied energy.
  static const double _kcalTolerance = 0.25;

  /// Absolute drift allowed, in kcal per 100 g. A record is only flagged when
  /// it breaches *both* this and [_kcalTolerance] — on a 22 kcal food (lemon
  /// juice, cucumber) a 25% relative miss is rounding noise, while on a 580 kcal
  /// food a 15 kcal miss is invisible. Requiring both keeps the check meaningful
  /// across three orders of magnitude of energy density.
  static const double _kcalAbsoluteTolerance = 15;

  static List<CatalogIssue> validate(List<FoodItem> foods) {
    final issues = <CatalogIssue>[];
    final seenIds = <String>{};

    for (var i = 0; i < foods.length; i++) {
      final food = foods[i];
      final id = food.id.isEmpty ? '<index $i>' : food.id;

      if (food.id.isEmpty) {
        issues.add(CatalogIssue(id, 'missing id'));
      } else if (!seenIds.add(food.id)) {
        issues.add(CatalogIssue(id, 'duplicate id'));
      }

      if (food.name.isEmpty) {
        issues.add(CatalogIssue(id, 'missing name'));
      }

      // 100 g of anything cannot contain more than 100 g of macronutrients.
      final macroGrams =
          food.proteinPer100g + food.carbsPer100g + food.fatPer100g;
      if (macroGrams > 100.5) {
        issues.add(
          CatalogIssue(
            id,
            'macros sum to ${macroGrams.toStringAsFixed(1)} g per 100 g',
          ),
        );
      }

      // Fibre is a subset of carbohydrate, so it can never exceed it.
      if (food.fibrePer100g > food.carbsPer100g + 0.5) {
        issues.add(
          CatalogIssue(
            id,
            'fibre ${food.fibrePer100g} g exceeds carbs '
            '${food.carbsPer100g} g per 100 g',
          ),
        );
      }

      _checkEnergy(issues, id, food);

      for (final unit in food.householdUnits) {
        if (!unit.isValid) {
          issues.add(CatalogIssue(id, 'invalid household unit "$unit"'));
        }
      }

      if (food.source.isEmpty) {
        issues.add(CatalogIssue(id, 'missing source attribution'));
      }
    }

    return issues;
  }

  static void _checkEnergy(
    List<CatalogIssue> issues,
    String id,
    FoodItem food,
  ) {
    final implied = impliedKcalPer100g(food);

    // A zero-calorie, zero-macro record (water, salt) is legitimate.
    if (implied == 0 && food.kcalPer100g == 0) return;

    final absoluteDrift = (implied - food.kcalPer100g).abs();
    if (absoluteDrift <= _kcalAbsoluteTolerance) return;

    final reference = food.kcalPer100g == 0 ? implied : food.kcalPer100g;
    final relativeDrift = absoluteDrift / reference;
    if (relativeDrift <= _kcalTolerance) return;

    issues.add(
      CatalogIssue(
        id,
        'stated ${food.kcalPer100g} kcal/100 g but macros imply '
        '${implied.toStringAsFixed(0)} kcal '
        '(${(relativeDrift * 100).toStringAsFixed(0)}% drift)',
      ),
    );
  }

  /// Energy implied by a food's macros.
  ///
  /// Uses *net* carbohydrate at 4 kcal/g plus fibre at 2 kcal/g, rather than
  /// treating all carbohydrate as 4. Fibre is only partially metabolised, and
  /// USDA's own energy figures reflect that — scoring fibre at the full 4
  /// kcal/g would over-state leafy greens and high-fibre foods badly enough to
  /// false-flag correct records (raw spinach drifts 28% under the naive
  /// formula, 9% under this one).
  static double impliedKcalPer100g(FoodItem food) {
    final netCarbs = (food.carbsPer100g - food.fibrePer100g).clamp(0, 100);
    return food.proteinPer100g * 4 +
        netCarbs * 4 +
        food.fibrePer100g * 2 +
        food.fatPer100g * 9;
  }
}

/// Validates the bundled recipe catalog against the food table it resolves
/// against (master prompt §9.1 composition floor, §9.2 schema).
class RecipeCatalogValidator {
  RecipeCatalogValidator._();

  /// Sanity bounds for one serving. A recipe outside these is almost certainly
  /// a gram-quantity typo rather than a real dish.
  static const double _minServingKcal = 40;
  static const double _maxServingKcal = 1500;

  static List<CatalogIssue> validate(
    List<Recipe> recipes,
    Map<String, FoodItem> foods,
  ) {
    final issues = <CatalogIssue>[];
    final seenIds = <String>{};

    for (var i = 0; i < recipes.length; i++) {
      final recipe = recipes[i];
      final id = recipe.id.isEmpty ? '<index $i>' : recipe.id;

      if (recipe.id.isEmpty) {
        issues.add(CatalogIssue(id, 'missing id'));
      } else if (!seenIds.add(recipe.id)) {
        issues.add(CatalogIssue(id, 'duplicate id'));
      }

      if (recipe.title.isEmpty) issues.add(CatalogIssue(id, 'missing title'));
      if (recipe.description.isEmpty) {
        issues.add(CatalogIssue(id, 'missing description'));
      }
      if (recipe.servings < 1) {
        issues.add(CatalogIssue(id, 'servings must be at least 1'));
      }
      if (recipe.ingredients.isEmpty) {
        issues.add(CatalogIssue(id, 'no ingredients'));
      }
      if (recipe.steps.isEmpty) {
        issues.add(CatalogIssue(id, 'no steps'));
      }
      if (recipe.totalMinutes <= 0) {
        issues.add(CatalogIssue(id, 'total time must be greater than zero'));
      }

      // Nothing may claim review it has not had (master prompt §18).
      if (recipe.status != ContentStatus.draft &&
          (recipe.reviewerCredit == null || recipe.reviewerCredit!.isEmpty)) {
        issues.add(
          CatalogIssue(
            id,
            'status is ${recipe.status.name} but no reviewer is credited',
          ),
        );
      }

      var unresolved = false;
      for (final ingredient in recipe.ingredients) {
        if (!foods.containsKey(ingredient.foodId)) {
          issues.add(CatalogIssue(id, 'unknown food "${ingredient.foodId}"'));
          unresolved = true;
        } else if (ingredient.grams <= 0) {
          issues.add(
            CatalogIssue(id, 'ingredient "${ingredient.foodId}" has no weight'),
          );
        }
      }

      for (final substitution in recipe.substitutions) {
        if (!foods.containsKey(substitution.forFoodId)) {
          issues.add(
            CatalogIssue(
              id,
              'substitution targets unknown food '
              '"${substitution.forFoodId}"',
            ),
          );
        }
        if (!foods.containsKey(substitution.useFoodId)) {
          issues.add(
            CatalogIssue(
              id,
              'substitution suggests unknown food '
              '"${substitution.useFoodId}"',
            ),
          );
        }
      }

      if (!unresolved && recipe.ingredients.isNotEmpty) {
        final perServing = RecipeNutrientCalculator.perServing(
          recipe,
          foods,
        ).kcal;
        if (perServing < _minServingKcal || perServing > _maxServingKcal) {
          issues.add(
            CatalogIssue(
              id,
              'implausible ${perServing.toStringAsFixed(0)} kcal per serving '
              '(expected $_minServingKcal-$_maxServingKcal)',
            ),
          );
        }
      }
    }

    return issues;
  }

  /// Checks the catalog-wide composition floor from master prompt §9.1.
  ///
  /// These are contractual minimums, not aspirations: the sprint is not done
  /// until they pass, and they exist so the catalog cannot later be gutted
  /// without CI noticing.
  static List<CatalogIssue> validateComposition(
    List<Recipe> recipes,
    Map<String, FoodItem> foods,
  ) {
    final issues = <CatalogIssue>[];

    void require(bool condition, String message) {
      if (!condition) issues.add(CatalogIssue('<catalog>', message));
    }

    int countWhere(bool Function(Recipe) test) => recipes.where(test).length;

    require(
      recipes.length >= 24,
      'needs at least 24 recipes, has ${recipes.length}',
    );

    final breakfastSnack = countWhere(
      (r) => r.mealType == MealType.breakfast || r.mealType == MealType.snack,
    );
    require(
      breakfastSnack >= 8,
      'needs at least 8 breakfast/snack recipes, has $breakfastSnack',
    );

    final lunchDinner = countWhere(
      (r) => r.mealType == MealType.lunch || r.mealType == MealType.dinner,
    );
    require(
      lunchDinner >= 8,
      'needs at least 8 lunch/dinner recipes, has $lunchDinner',
    );

    final pre = countWhere(
      (r) => r.trainingTiming == TrainingTiming.preTraining,
    );
    require(pre >= 4, 'needs at least 4 pre-training recipes, has $pre');

    final post = countWhere(
      (r) => r.trainingTiming == TrainingTiming.postTraining,
    );
    require(post >= 4, 'needs at least 4 post-training recipes, has $post');

    final vegetarian = countWhere(
      (r) => RecipeNutrientCalculator.dietTagsOf(
        r,
        foods,
      ).contains(DietTag.vegetarian),
    );
    require(
      vegetarian >= 8,
      'needs at least 8 vegetarian recipes, has $vegetarian',
    );

    final vegan = countWhere(
      (r) =>
          RecipeNutrientCalculator.dietTagsOf(r, foods).contains(DietTag.vegan),
    );
    require(vegan >= 4, 'needs at least 4 vegan recipes, has $vegan');

    // Master prompt §9.1: the free tier must be genuinely useful, not a teaser.
    final free = countWhere((r) => !r.isPremium);
    require(
      free >= 12,
      'free tier needs at least 12 complete recipes, has $free',
    );

    final noOven = countWhere((r) => !r.requiresOven);
    require(noOven >= 8, 'needs no-oven options, has $noOven');

    final quick = countWhere((r) => r.totalMinutes <= 20);
    require(quick >= 6, 'needs recipes under 20 minutes, has $quick');

    return issues;
  }
}
