import '../models/food_enums.dart';
import '../models/recipe.dart';

/// Decides which recipes the app may show.
///
/// Every recipe ships as [ContentStatus.draft] until a qualified reviewer signs
/// it off. A draft, reviewed-only or retired recipe stays hidden: only
/// [ContentStatus.published] is visible. Pure and deterministic, so the same
/// rule can sit in front of the recipe list, the match calculator and the
/// grocery list.
class RecipePublicationGate {
  const RecipePublicationGate._();

  /// True only for a published recipe.
  static bool isVisible(Recipe recipe) =>
      recipe.status == ContentStatus.published;

  /// The visible recipes, in the given order.
  static List<Recipe> visible(Iterable<Recipe> recipes) =>
      List.unmodifiable(recipes.where(isVisible));

  /// The hidden recipes, in the given order. For a content-review checklist.
  static List<Recipe> hidden(Iterable<Recipe> recipes) =>
      List.unmodifiable(recipes.where((r) => !isVisible(r)));
}
