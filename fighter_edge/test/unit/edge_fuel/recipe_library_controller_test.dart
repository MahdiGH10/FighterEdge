import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/recipe_library_controller.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _readRealAsset(String path) => File(path).readAsString();

RecipeLibraryController _controller() {
  final foods = AssetFoodCatalogRepository(loadString: _readRealAsset);
  return RecipeLibraryController(
    foodCatalog: foods,
    recipeCatalog: AssetRecipeCatalogRepository(
      foodCatalog: foods,
      loadString: _readRealAsset,
    ),
  );
}

void main() {
  group('RecipeLibraryController', () {
    test('loads the catalog and derives listings', () async {
      final controller = _controller();
      await controller.load();

      expect(controller.isLoading, isFalse);
      expect(controller.error, isNull);
      expect(controller.visible, hasLength(24));
      expect(controller.visible.first.perServing.kcalRounded, greaterThan(0));
    });

    test('reports an error state instead of throwing', () async {
      final foods = AssetFoodCatalogRepository(loadString: _readRealAsset);
      final controller = RecipeLibraryController(
        foodCatalog: foods,
        recipeCatalog: AssetRecipeCatalogRepository(
          foodCatalog: foods,
          loadString: (_) async => throw Exception('offline'),
        ),
      );

      await controller.load();

      expect(controller.error, isNotNull);
      expect(controller.visible, isEmpty);
      expect(controller.isLoading, isFalse);
    });

    test('filters by meal type', () async {
      final controller = _controller();
      await controller.load();

      controller.setFilters(const RecipeFilters(mealType: MealType.breakfast));
      expect(controller.visible, isNotEmpty);
      expect(
        controller.visible.every(
          (l) => l.recipe.mealType == MealType.breakfast,
        ),
        isTrue,
      );
    });

    test('filters by training timing', () async {
      final controller = _controller();
      await controller.load();

      controller.setFilters(
        const RecipeFilters(trainingTiming: TrainingTiming.preTraining),
      );
      expect(controller.visible, hasLength(4));
    });

    test('filters by derived diet tag', () async {
      final controller = _controller();
      await controller.load();

      controller.setFilters(const RecipeFilters(dietTag: DietTag.vegan));
      expect(controller.visible, isNotEmpty);
      expect(
        controller.visible.every((l) => l.dietTags.contains(DietTag.vegan)),
        isTrue,
      );
    });

    test('filters by time and equipment', () async {
      final controller = _controller();
      await controller.load();

      controller.setFilters(const RecipeFilters(maxMinutes: 20));
      expect(
        controller.visible.every((l) => l.recipe.totalMinutes <= 20),
        isTrue,
      );

      controller.setFilters(const RecipeFilters(noOvenOnly: true));
      expect(controller.visible.every((l) => !l.recipe.requiresOven), isTrue);
    });

    test('search matches title, description and cuisine', () async {
      final controller = _controller();
      await controller.load();

      controller.setQuery('chickpea');
      expect(controller.visible, isNotEmpty);

      controller.setQuery('tunisian');
      expect(
        controller.visible,
        isNotEmpty,
        reason: 'cuisine tags should be searchable',
      );

      controller.setQuery('zzzzz');
      expect(controller.visible, isEmpty);
    });

    test('clearFilters keeps the allergen escape hatch state', () async {
      final controller = _controller();
      await controller.load();
      controller.toggleAllergenConflicts();
      controller.setQuery('chickpea');

      controller.clearFilters();

      expect(controller.filters.query, isEmpty);
      expect(
        controller.filters.showAllergenConflicts,
        isTrue,
        reason: 'clearing filters must not silently re-hide allergens the '
            'user deliberately chose to see',
      );
    });
  });

  group('allergen filtering (EF3_PLAN §8 decision 1, Option B)', () {
    test('hides conflicting recipes by default and counts them', () async {
      final controller = _controller();
      await controller.load();
      final before = controller.visible.length;

      controller.setDeclaredAllergens(['milk']);

      expect(controller.visible.length, lessThan(before));
      expect(controller.hiddenByAllergens, greaterThan(0));
      expect(
        controller.visible.every((l) => !l.allergens.contains(Allergen.milk)),
        isTrue,
      );
      expect(controller.visible.length + controller.hiddenByAllergens, before);
    });

    test('the escape hatch reveals them again', () async {
      final controller = _controller();
      await controller.load();
      controller.setDeclaredAllergens(['milk']);
      final hidden = controller.hiddenByAllergens;
      expect(hidden, greaterThan(0));

      controller.toggleAllergenConflicts();

      expect(controller.hiddenByAllergens, 0);
      expect(
        controller.visible.any((l) => l.allergens.contains(Allergen.milk)),
        isTrue,
      );
    });

    test('conflictingAllergens names only what the user declared', () async {
      final controller = _controller();
      await controller.load();
      controller.setDeclaredAllergens(['milk']);
      controller.toggleAllergenConflicts();

      final conflicting = controller.visible
          .map(controller.conflictingAllergens)
          .where((s) => s.isNotEmpty);

      expect(conflicting, isNotEmpty);
      // A recipe with milk AND gluten must only report milk — reporting an
      // allergen the user never mentioned would train them to ignore warnings.
      expect(
        conflicting.every((s) => s.every((a) => a == Allergen.milk)),
        isTrue,
      );
    });

    test('hidden count respects the other active filters', () async {
      final controller = _controller();
      await controller.load();
      controller.setDeclaredAllergens(['milk']);
      controller.setFilters(
        const RecipeFilters(
          mealType: MealType.dinner,
          showAllergenConflicts: false,
        ),
      );

      // The banner must not claim to be hiding recipes that the meal-type
      // filter already excluded.
      final hiddenDinners = controller.hiddenByAllergens;
      controller.toggleAllergenConflicts();
      final allDinners = controller.visible.length;
      controller.toggleAllergenConflicts();
      final shownDinners = controller.visible.length;

      expect(shownDinners + hiddenDinners, allDinners);
    });

    test('no declared allergens means nothing is hidden', () async {
      final controller = _controller();
      await controller.load();
      controller.setDeclaredAllergens(const []);

      expect(controller.hiddenByAllergens, 0);
      expect(controller.visible, hasLength(24));
    });

    test('surfaces allergens it could not interpret', () async {
      final controller = _controller();
      await controller.load();
      controller.setDeclaredAllergens(['milk', 'kiwi']);

      expect(controller.allergenMatch.matched, {Allergen.milk});
      expect(controller.allergenMatch.unmatched, ['kiwi']);
    });
  });
}
