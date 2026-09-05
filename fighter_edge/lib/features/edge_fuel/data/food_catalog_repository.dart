import '../domain/models/food_item.dart';

/// Provider-neutral access to food nutrient data (master prompt §9.3).
///
/// V1 is backed by a bundled, reviewed table. V1.5 adds a backend proxy to USDA
/// FoodData Central behind this same interface — callers must not learn where
/// the data came from, and no implementation may return a provider's own types.
///
/// The user-scoped surface from §9.3 (custom foods, recents, favourites) is
/// deliberately absent until the UI that needs it exists; see
/// `docs/edge_fuel/EF3_PLAN.md` §8.1.
abstract class FoodCatalogRepository {
  /// Every food in the catalog. Implementations should cache — callers are
  /// free to call this per rebuild.
  Future<List<FoodItem>> loadAll();

  /// Resolves one food, or null when the id is unknown. Recipe ingredient
  /// resolution goes through here, so an unknown id must be detectable rather
  /// than silently yielding a zero-nutrient food.
  Future<FoodItem?> byId(String id);

  /// Case-insensitive substring match on name. Empty query returns the whole
  /// catalog, capped by [limit].
  Future<List<FoodItem>> search(String query, {int limit});
}
