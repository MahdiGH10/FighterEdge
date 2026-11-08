import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/recipe_catalog_repository.dart';

/// The shipped recipe catalog with every recipe marked published and given a
/// reviewer, as a test fixture only. The real catalog stays draft until the
/// owner names a reviewer.
///
/// The files are read synchronously here, outside the fake test clock, and
/// handed back as completed futures: a real `File.readAsString()` inside a
/// widget test never completes under the fake clock.
RecipeCatalogRepository publishedRecipeCatalog() {
  final foodsJson =
      File('assets/data/edge_fuel_foods_v1.json').readAsStringSync();
  final catalog = jsonDecode(
    File('assets/data/edge_fuel_recipes_v1.json').readAsStringSync(),
  ) as Map<String, dynamic>;
  for (final recipe in catalog['recipes'] as List<dynamic>) {
    final record = recipe as Map<String, dynamic>;
    record['status'] = 'published';
    record['reviewerCredit'] = 'Test reviewer';
  }
  final recipesJson = jsonEncode(catalog);
  return AssetRecipeCatalogRepository(
    foodCatalog: AssetFoodCatalogRepository(loadString: (_) async => foodsJson),
    loadString: (_) async => recipesJson,
  );
}
