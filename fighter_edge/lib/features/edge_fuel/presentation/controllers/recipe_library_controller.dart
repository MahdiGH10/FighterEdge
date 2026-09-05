import 'package:flutter/foundation.dart';

import '../../data/food_catalog_repository.dart';
import '../../data/recipe_catalog_repository.dart';
import '../../domain/allergen_matching.dart';
import '../../domain/calculators/recipe_nutrient_calculator.dart';
import '../../domain/models/food_enums.dart';
import '../../domain/models/food_item.dart';
import '../../domain/models/recipe.dart';

/// A recipe paired with everything derived from it, computed once per catalog
/// load instead of on every rebuild.
class RecipeListing {
  final Recipe recipe;
  final RecipeNutrients perServing;
  final Set<Allergen> allergens;
  final Set<DietTag> dietTags;

  const RecipeListing({
    required this.recipe,
    required this.perServing,
    required this.allergens,
    required this.dietTags,
  });
}

/// The filters the library screen exposes (master prompt §5.3).
class RecipeFilters {
  final String query;
  final MealType? mealType;
  final TrainingTiming? trainingTiming;
  final DietTag? dietTag;
  final CostBand? costBand;
  final int? maxMinutes;
  final bool noOvenOnly;

  /// When true, recipes conflicting with the user's declared allergens are
  /// shown anyway, each with a warning. Default false — see
  /// `docs/edge_fuel/EF3_PLAN.md` §8 decision 1 (Option B).
  final bool showAllergenConflicts;

  const RecipeFilters({
    this.query = '',
    this.mealType,
    this.trainingTiming,
    this.dietTag,
    this.costBand,
    this.maxMinutes,
    this.noOvenOnly = false,
    this.showAllergenConflicts = false,
  });

  RecipeFilters copyWith({
    String? query,
    MealType? mealType,
    TrainingTiming? trainingTiming,
    DietTag? dietTag,
    CostBand? costBand,
    int? maxMinutes,
    bool? noOvenOnly,
    bool? showAllergenConflicts,
    bool clearMealType = false,
    bool clearTrainingTiming = false,
    bool clearDietTag = false,
    bool clearCostBand = false,
    bool clearMaxMinutes = false,
  }) {
    return RecipeFilters(
      query: query ?? this.query,
      mealType: clearMealType ? null : (mealType ?? this.mealType),
      trainingTiming:
          clearTrainingTiming ? null : (trainingTiming ?? this.trainingTiming),
      dietTag: clearDietTag ? null : (dietTag ?? this.dietTag),
      costBand: clearCostBand ? null : (costBand ?? this.costBand),
      maxMinutes: clearMaxMinutes ? null : (maxMinutes ?? this.maxMinutes),
      noOvenOnly: noOvenOnly ?? this.noOvenOnly,
      showAllergenConflicts:
          showAllergenConflicts ?? this.showAllergenConflicts,
    );
  }

  bool get hasActiveFilter =>
      query.trim().isNotEmpty ||
      mealType != null ||
      trainingTiming != null ||
      dietTag != null ||
      costBand != null ||
      maxMinutes != null ||
      noOvenOnly;
}

/// Read-side state for the recipe library.
///
/// Owns loading/error/empty states so the widgets do not (master prompt §11).
/// Entitlement is *not* handled here — the screen decides what a free user may
/// open, and the server independently verifies anything that matters.
class RecipeLibraryController extends ChangeNotifier {
  final RecipeCatalogRepository _recipes;
  final FoodCatalogRepository _foods;

  RecipeLibraryController({
    required RecipeCatalogRepository recipeCatalog,
    required FoodCatalogRepository foodCatalog,
  })  : _recipes = recipeCatalog,
        _foods = foodCatalog;

  bool _loading = false;
  String? _error;
  List<RecipeListing> _all = const [];
  Map<String, FoodItem> _foodsById = const {};
  RecipeFilters _filters = const RecipeFilters();
  AllergenMatch _allergens = const AllergenMatch();

  bool get isLoading => _loading;
  String? get error => _error;
  bool get isLoaded => !_loading && _error == null && _all.isNotEmpty;
  RecipeFilters get filters => _filters;
  Map<String, FoodItem> get foodsById => _foodsById;

  /// The user's declared allergens, interpreted from the free text they typed
  /// in setup. [AllergenMatch.unmatched] must be surfaced — see the class doc.
  AllergenMatch get allergenMatch => _allergens;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      final foods = await _foods.loadAll();
      final foodsById = {for (final f in foods) f.id: f};
      final recipes = await _recipes.loadAll();

      _foodsById = foodsById;
      _all = [
        for (final recipe in recipes)
          RecipeListing(
            recipe: recipe,
            perServing: RecipeNutrientCalculator.perServing(recipe, foodsById),
            allergens: RecipeNutrientCalculator.allergensOf(recipe, foodsById),
            dietTags: RecipeNutrientCalculator.dietTagsOf(recipe, foodsById),
          ),
      ];
      _error = null;
    } catch (e) {
      _all = const [];
      _error = 'Could not load the recipe library.';
      debugPrint('RecipeLibraryController.load failed: $e');
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Feeds the user's declared allergens in from their nutrition profile.
  void setDeclaredAllergens(Iterable<String> freeText) {
    final next = AllergenMatcher.match(freeText);
    if (setEquals(next.matched, _allergens.matched) &&
        listEquals(next.unmatched, _allergens.unmatched)) {
      return;
    }
    _allergens = next;
    notifyListeners();
  }

  void setFilters(RecipeFilters filters) {
    _filters = filters;
    notifyListeners();
  }

  void setQuery(String query) => setFilters(_filters.copyWith(query: query));

  void toggleAllergenConflicts() => setFilters(
        _filters.copyWith(
            showAllergenConflicts: !_filters.showAllergenConflicts),
      );

  void clearFilters() => setFilters(
        RecipeFilters(showAllergenConflicts: _filters.showAllergenConflicts),
      );

  /// True when this recipe contains one of the user's declared allergens.
  bool conflictsWithAllergens(RecipeListing listing) =>
      listing.allergens.intersection(_allergens.matched).isNotEmpty;

  /// Which of the user's allergens this recipe contains, for the warning copy.
  Set<Allergen> conflictingAllergens(RecipeListing listing) =>
      listing.allergens.intersection(_allergens.matched);

  /// Recipes matching the active filters, allergen rule applied.
  List<RecipeListing> get visible {
    final matches = _all.where(_matchesFilters).toList();
    if (_filters.showAllergenConflicts || _allergens.matched.isEmpty) {
      return matches;
    }
    return matches.where((l) => !conflictsWithAllergens(l)).toList();
  }

  /// How many recipes the allergen filter is currently hiding. Shown to the
  /// user rather than hidden — silently removing most of a small catalog would
  /// read as the app being empty.
  int get hiddenByAllergens {
    if (_filters.showAllergenConflicts || _allergens.matched.isEmpty) return 0;
    return _all.where(_matchesFilters).where(conflictsWithAllergens).length;
  }

  bool _matchesFilters(RecipeListing listing) {
    final recipe = listing.recipe;
    final f = _filters;

    final query = f.query.trim().toLowerCase();
    if (query.isNotEmpty) {
      final haystack =
          '${recipe.title} ${recipe.description} ${recipe.cuisineTags.join(' ')}'
              .toLowerCase();
      if (!haystack.contains(query)) return false;
    }

    if (f.mealType != null && recipe.mealType != f.mealType) return false;
    if (f.trainingTiming != null && recipe.trainingTiming != f.trainingTiming) {
      return false;
    }
    if (f.dietTag != null && !listing.dietTags.contains(f.dietTag)) {
      return false;
    }
    if (f.costBand != null && recipe.costBand != f.costBand) return false;
    if (f.maxMinutes != null && recipe.totalMinutes > f.maxMinutes!) {
      return false;
    }
    if (f.noOvenOnly && recipe.requiresOven) return false;

    return true;
  }
}
