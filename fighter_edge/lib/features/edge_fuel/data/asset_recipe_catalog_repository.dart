import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/food_item.dart';
import '../domain/models/recipe.dart';
import '../domain/validation/catalog_validation.dart';
import 'food_catalog_repository.dart';
import 'recipe_catalog_repository.dart';

/// Loads the curated catalog from `assets/data/edge_fuel_recipes_v1.json`.
///
/// Takes a [FoodCatalogRepository] because recipes are only meaningful once
/// their ingredients resolve — validation cannot run without the food table,
/// and neither can any nutrient figure.
class AssetRecipeCatalogRepository implements RecipeCatalogRepository {
  static const String assetPath = 'assets/data/edge_fuel_recipes_v1.json';

  final FoodCatalogRepository _foods;
  final Future<String> Function(String path) _loadString;

  List<Recipe>? _cache;
  Map<String, Recipe>? _byId;
  Future<List<Recipe>>? _inFlight;

  AssetRecipeCatalogRepository({
    required FoodCatalogRepository foodCatalog,
    Future<String> Function(String path)? loadString,
  }) : _foods = foodCatalog,
       _loadString = loadString ?? rootBundle.loadString;

  @override
  Future<List<Recipe>> loadAll() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _inFlight ??= _load();
  }

  Future<List<Recipe>> _load() async {
    try {
      final raw = await _loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('recipe catalog root must be an object');
      }
      final records = decoded['recipes'];
      if (records is! List) {
        throw const FormatException('recipe catalog has no "recipes" array');
      }

      final recipes = records
          .whereType<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList(growable: false);

      final foods = {for (final food in await _foods.loadAll()) food.id: food};
      _assertValid(recipes, foods);

      _cache = recipes;
      _byId = {for (final recipe in recipes) recipe.id: recipe};
      return recipes;
    } finally {
      _inFlight = null;
    }
  }

  /// Fails loudly in debug; release builds tolerate content drift rather than
  /// crashing a user's app. The same checks run in unit tests, which is where
  /// they are meant to bite (master prompt §9.2).
  void _assertValid(List<Recipe> recipes, Map<String, FoodItem> foods) {
    assert(() {
      final issues = [
        ...RecipeCatalogValidator.validate(recipes, foods),
        ...RecipeCatalogValidator.validateComposition(recipes, foods),
      ];
      if (issues.isNotEmpty) {
        debugPrint('EdgeFuel recipe catalog has ${issues.length} issue(s):');
        for (final issue in issues) {
          debugPrint('  $issue');
        }
        throw StateError(
          'Invalid EdgeFuel recipe catalog: ${issues.length} issue(s). '
          'First: ${issues.first}',
        );
      }
      return true;
    }());
  }

  @override
  Future<Recipe?> byId(String id) async {
    await loadAll();
    return _byId?[id];
  }
}
