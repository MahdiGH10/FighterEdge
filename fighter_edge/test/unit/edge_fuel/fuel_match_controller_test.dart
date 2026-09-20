import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/fuel_match_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _readRealAsset(String path) => File(path).readAsString();

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2400,
      proteinGrams: 180,
      carbGrams: 260,
      fatGrams: 75,
    );

NutritionDay _day() => NutritionDay.empty(
      localDate: '2026-01-01',
      timeZone: 'UTC',
      now: DateTime(2026, 1, 1),
    );

void main() {
  test('loads the catalog once and marks an old match stale after logging',
      () async {
    final foods = AssetFoodCatalogRepository(loadString: _readRealAsset);
    final controller = FuelMatchController(
      foodCatalog: foods,
      recipeCatalog: AssetRecipeCatalogRepository(
        foodCatalog: foods,
        loadString: _readRealAsset,
      ),
    );
    final day = _day();

    await controller.build(target: _target(), day: day);

    expect(controller.error, isNull);
    expect(controller.match?.isReady, isTrue);
    expect(controller.foodsById, isNotEmpty);
    expect(controller.isStaleFor(_target(), day), isFalse);

    final logged = day.copyWith(entries: [
      FoodLogEntry(
        id: 'meal',
        name: 'Fixture meal',
        notes: '',
        calories: 500,
        proteinGrams: 30,
        carbGrams: 50,
        fatGrams: 12,
        loggedAt: DateTime(2026, 1, 1),
      ),
    ]);
    expect(controller.isStaleFor(_target(), logged), isTrue);
  });
}
