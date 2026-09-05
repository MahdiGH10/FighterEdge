import '../domain/models/recipe.dart';

/// Access to the curated recipe catalog (master prompt §9.1).
///
/// V1 is a versioned local asset. Master prompt §12 allows the catalog to move
/// behind a backend later; callers must not depend on it being local.
abstract class RecipeCatalogRepository {
  /// Every recipe in the catalog, premium included. Entitlement filtering is a
  /// presentation concern and does not belong here — the library screen decides
  /// what a free user may open, and the server independently verifies any
  /// entitlement that matters (master prompt §10).
  Future<List<Recipe>> loadAll();

  Future<Recipe?> byId(String id);
}
