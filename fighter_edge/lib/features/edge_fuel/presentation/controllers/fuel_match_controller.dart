import 'package:flutter/foundation.dart';

import '../../data/food_catalog_repository.dart';
import '../../data/recipe_catalog_repository.dart';
import '../../domain/calculators/fuel_match_calculator.dart';
import '../../domain/models/fuel_match.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';

/// Read-side state for the deterministic premium Fuel Match experience.
///
/// It owns only asset loading and presentation state. The ranking itself stays
/// pure in [FuelMatchCalculator], which makes the result reproducible in unit
/// tests and prevents a rebuild from triggering I/O or inference.
class FuelMatchController extends ChangeNotifier {
  final RecipeCatalogRepository _recipes;
  final FoodCatalogRepository _foods;

  FuelMatchController({
    required RecipeCatalogRepository recipeCatalog,
    required FoodCatalogRepository foodCatalog,
  })  : _recipes = recipeCatalog,
        _foods = foodCatalog;

  bool _loading = false;
  String? _error;
  FuelMatch? _match;
  Map<String, FoodItem> _foodsById = const {};
  _FuelMatchBasis? _basis;
  bool _disposed = false;

  bool get isLoading => _loading;
  String? get error => _error;
  FuelMatch? get match => _match;
  Map<String, FoodItem> get foodsById => _foodsById;

  /// A match is a snapshot of the daily log. Once the athlete logs a recipe,
  /// the old portions must not still be presented as today's exact answer.
  bool isStaleFor(NutritionTarget? target, NutritionDay? day) =>
      _basis != null && _basis != _FuelMatchBasis.of(target, day);

  Future<void> build({
    required NutritionTarget? target,
    required NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      // Start both asset reads before awaiting either one. The repositories
      // cache internally, so subsequent matches are effectively pure work.
      final foodsFuture = _foods.loadAll();
      final recipesFuture = _recipes.loadAll();
      final foods = await foodsFuture;
      final recipes = await recipesFuture;
      _foodsById = {
        for (final food in foods) food.id: food,
      };
      _match = FuelMatchCalculator.calculate(
        target: target,
        day: day,
        preferences: preferences,
        foodsById: _foodsById,
        recipes: recipes,
      );
      _basis = _FuelMatchBasis.of(target, day);
    } catch (error) {
      _match = null;
      _foodsById = const {};
      _basis = null;
      _error = 'Could not build your Fuel Match. Please try again.';
      debugPrint('FuelMatchController.build failed: $error');
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class _FuelMatchBasis {
  final int targetCalories;
  final int targetProtein;
  final int targetCarbs;
  final int targetFats;
  final int consumedCalories;
  final int consumedProtein;
  final int consumedCarbs;
  final int consumedFats;

  const _FuelMatchBasis({
    required this.targetCalories,
    required this.targetProtein,
    required this.targetCarbs,
    required this.targetFats,
    required this.consumedCalories,
    required this.consumedProtein,
    required this.consumedCarbs,
    required this.consumedFats,
  });

  factory _FuelMatchBasis.of(NutritionTarget? target, NutritionDay? day) =>
      _FuelMatchBasis(
        targetCalories: target?.targetCalories ?? 0,
        targetProtein: target?.proteinGrams ?? 0,
        targetCarbs: target?.carbGrams ?? 0,
        targetFats: target?.fatGrams ?? 0,
        consumedCalories: day?.totals.calories ?? 0,
        consumedProtein: day?.totals.proteinGrams ?? 0,
        consumedCarbs: day?.totals.carbGrams ?? 0,
        consumedFats: day?.totals.fatGrams ?? 0,
      );

  @override
  bool operator ==(Object other) =>
      other is _FuelMatchBasis &&
      targetCalories == other.targetCalories &&
      targetProtein == other.targetProtein &&
      targetCarbs == other.targetCarbs &&
      targetFats == other.targetFats &&
      consumedCalories == other.consumedCalories &&
      consumedProtein == other.consumedProtein &&
      consumedCarbs == other.consumedCarbs &&
      consumedFats == other.consumedFats;

  @override
  int get hashCode => Object.hash(
        targetCalories,
        targetProtein,
        targetCarbs,
        targetFats,
        consumedCalories,
        consumedProtein,
        consumedCarbs,
        consumedFats,
      );
}
