import '../models/food_enums.dart';
import '../models/food_item.dart';
import '../models/grocery_list.dart';
import '../models/recipe.dart';
import '../policies/recipe_publication_gate.dart';

/// A recipe in the meal-prep plan and how many batches to cook.
class GroceryRecipePlan {
  final Recipe recipe;

  /// "Cook x4": every ingredient is multiplied by this. 1 is a single batch.
  final double cookMultiplier;

  const GroceryRecipePlan({required this.recipe, this.cookMultiplier = 1});

  /// Portions the plan makes: the recipe's servings times the multiplier.
  double get servingsMade =>
      recipe.servings * GroceryListBuilder.clampMultiplier(cookMultiplier);
}

/// Builds a merged, offline grocery list from a meal-prep plan.
///
/// Ingredients are merged by food id and their grams summed across recipes,
/// after the cook multiplier is applied. Optional ingredients are left out
/// unless asked for. Recipes that are not published are skipped (see
/// [RecipePublicationGate]) and listed in [GroceryList.skippedRecipeIds].
/// Pure Dart: no clock, no network, no I/O.
class GroceryListBuilder {
  const GroceryListBuilder._();

  /// Largest multiplier accepted. Beyond this is almost certainly a typo.
  static const double maxCookMultiplier = 20;

  /// Smallest multiplier accepted (half a batch).
  static const double minCookMultiplier = 0.5;

  /// [value] brought into [minCookMultiplier]..[maxCookMultiplier]. NaN and
  /// infinity become 1.
  static double clampMultiplier(double value) {
    if (!value.isFinite) return 1;
    return value.clamp(minCookMultiplier, maxCookMultiplier).toDouble();
  }

  static GroceryList build({
    required Iterable<GroceryRecipePlan> plan,
    required Map<String, FoodItem> foodsById,
    bool includeOptional = false,
    bool publishedOnly = true,
  }) {
    final grams = <String, double>{};
    final lineCount = <String, int>{};
    final onlyLabel = <String, String?>{};
    final onlyScaled = <String, bool>{};
    final recipeIds = <String, List<String>>{};
    final skipped = <String>[];

    for (final entry in plan) {
      final recipe = entry.recipe;
      if (publishedOnly && !RecipePublicationGate.isVisible(recipe)) {
        if (!skipped.contains(recipe.id)) skipped.add(recipe.id);
        continue;
      }
      final multiplier = clampMultiplier(entry.cookMultiplier);
      for (final line in recipe.ingredients) {
        if (line.optional && !includeOptional) continue;
        if (line.foodId.isEmpty || !line.grams.isFinite || line.grams <= 0) {
          continue;
        }
        final id = line.foodId;
        grams[id] = (grams[id] ?? 0) + line.grams * multiplier;
        lineCount[id] = (lineCount[id] ?? 0) + 1;
        onlyLabel[id] = line.householdUnitLabel;
        onlyScaled[id] = (onlyScaled[id] ?? false) || multiplier != 1;
        final ids = recipeIds.putIfAbsent(id, () => []);
        if (!ids.contains(recipe.id)) ids.add(recipe.id);
      }
    }

    final items = <GroceryItem>[
      for (final e in grams.entries)
        GroceryItem(
          foodId: e.key,
          name: foodsById[e.key]?.name ?? e.key,
          category: foodsById[e.key]?.category ?? FoodCategory.other,
          // Round up so the shopper never buys short; trim float noise first.
          grams: (e.value - 1e-9).ceil().clamp(1, 1 << 30),
          // A label is only true for one line cooked once.
          householdLabel: lineCount[e.key] == 1 && onlyScaled[e.key] == false
              ? onlyLabel[e.key]
              : null,
          recipeIds: List.unmodifiable(recipeIds[e.key] ?? const []),
          unknownFood: foodsById[e.key] == null,
        ),
    ]..sort(_byCategoryThenName);

    return GroceryList(
      items: List.unmodifiable(items),
      skippedRecipeIds: List.unmodifiable(skipped),
    );
  }

  static int _byCategoryThenName(GroceryItem a, GroceryItem b) {
    final byCategory = a.category.index.compareTo(b.category.index);
    if (byCategory != 0) return byCategory;
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.foodId.compareTo(b.foodId);
  }
}
