import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/recipe_nutrient_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/recipe_library_controller.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/recipe_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

late String _foodsJson;
late String _recipesJson;

/// Builds a listing for one shipped recipe, using the real catalog content.
Future<(RecipeListing, Map<String, FoodItem>)> _listing(String recipeId) async {
  final foods = AssetFoodCatalogRepository(loadString: (_) async => _foodsJson);
  final recipes = AssetRecipeCatalogRepository(
    foodCatalog: foods,
    loadString: (_) async => _recipesJson,
  );
  final foodsById = {for (final f in await foods.loadAll()) f.id: f};
  final recipe = (await recipes.byId(recipeId))!;
  return (
    RecipeListing(
      recipe: recipe,
      perServing: RecipeNutrientCalculator.perServing(recipe, foodsById),
      allergens: RecipeNutrientCalculator.allergensOf(recipe, foodsById),
      dietTags: RecipeNutrientCalculator.dietTagsOf(recipe, foodsById),
    ),
    foodsById,
  );
}

/// Scrolls until [finder] is on screen.
///
/// The detail screen is a `ListView`, which only mounts what fits the viewport
/// plus cache extent — the gotcha recorded in `docs/edge_fuel/HANDOFF.md` §2.
/// Anything below the method steps needs scrolling to before it can be found.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _foodsJson = File('assets/data/edge_fuel_foods_v1.json').readAsStringSync();
    _recipesJson = File(
      'assets/data/edge_fuel_recipes_v1.json',
    ).readAsStringSync();
  });

  testWidgets('renders ingredients, method and allergen statement', (
    tester,
  ) async {
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(listing: listing, foodsById: foods),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INGREDIENTS'), findsOneWidget);
    await _scrollTo(tester, find.text('METHOD'));
    expect(find.text('METHOD'), findsOneWidget);
    await _scrollTo(tester, find.text('ALLERGENS'));
    expect(find.text('ALLERGENS'), findsOneWidget);
    expect(find.textContaining('Eggs'), findsWidgets);
  });

  testWidgets('the serving stepper rescales the macros', (tester) async {
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);
    final single = listing.perServing.kcalRounded;

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(listing: listing, foodsById: foods),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 serving'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More servings'));
    await tester.pumpAndSettle();

    expect(find.text('1.5 servings'), findsOneWidget);
    // The macro figure animates, so settle before reading it.
    expect(find.text('${(single * 1.5).round()}'), findsOneWidget);
  });

  testWidgets('the stepper will not go below its minimum', (tester) async {
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(listing: listing, foodsById: foods),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Fewer servings'));
    await tester.pumpAndSettle();
    expect(find.text('0.5 servings'), findsOneWidget);

    // Already at the floor. Tapping again must not move the value — and the
    // control is rendered disabled rather than silently swallowing the tap.
    await tester.tap(find.bySemanticsLabel('Fewer servings'));
    await tester.pumpAndSettle();
    expect(find.text('0.5 servings'), findsOneWidget);

    final decrease = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.byIcon(Icons.remove),
            matching: find.byType(InkWell),
          )
          .first,
    );
    expect(decrease.onTap, isNull);
  });

  testWidgets('add to today writes a scaled entry into the day', (
    tester,
  ) async {
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);
    final edgeFuelRepo = InMemoryEdgeFuelRepository();

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(listing: listing, foodsById: foods),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('More servings'));
    await tester.pumpAndSettle();
    await _scrollTo(tester, find.text('ADD TO TODAY'));
    await tester.tap(find.text('ADD TO TODAY'));
    await tester.pumpAndSettle();

    final userId = repo.currentUser!.id;
    final day = await edgeFuelRepo
        .watchNutritionDay(userId, DateTime.now())
        .first;
    expect(day.entries, hasLength(1));
    final entry = day.entries.single;
    expect(entry.name, 'Three-egg scramble with spinach');
    expect(entry.source, FoodLogSource.recipe);
    expect(entry.notes, '1.5 servings');
    expect(entry.calories, (listing.perServing.kcal * 1.5).round());
  });

  testWidgets('a conflicting allergen is called out on the detail screen', (
    tester,
  ) async {
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(
          listing: listing,
          foodsById: foods,
          conflictingAllergens: const {Allergen.eggs},
        ),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.text('ALLERGENS'));
    expect(find.textContaining('which you told us to avoid'), findsOneWidget);
  });

  testWidgets('household units are hidden once the recipe is rescaled', (
    tester,
  ) async {
    // "3 medium eggs" stops being true at 1.5x. A wrong household measure is
    // worse than none.
    final (listing, foods) = await _listing('three-egg-veg-scramble');
    final repo = await makeRepo(signedIn: true);

    await tester.pumpWidget(
      wrapApp(
        RecipeDetailScreen(listing: listing, foodsById: foods),
        repo: repo,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('3 medium eggs'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('More servings'));
    await tester.pumpAndSettle();
    expect(find.textContaining('3 medium eggs'), findsNothing);
  });

  testWidgets('every recipe in the catalog renders without overflowing', (
    tester,
  ) async {
    // Cheap guard against a content edit (a very long title, a 12-step method)
    // breaking a layout nobody re-opens.
    final foods = AssetFoodCatalogRepository(
      loadString: (_) async => _foodsJson,
    );
    final recipes = AssetRecipeCatalogRepository(
      foodCatalog: foods,
      loadString: (_) async => _recipesJson,
    );
    final foodsById = {for (final f in await foods.loadAll()) f.id: f};
    final repo = await makeRepo(signedIn: true);

    for (final recipe in await recipes.loadAll()) {
      await tester.pumpWidget(
        wrapApp(
          RecipeDetailScreen(
            listing: RecipeListing(
              recipe: recipe,
              perServing: RecipeNutrientCalculator.perServing(
                recipe,
                foodsById,
              ),
              allergens: RecipeNutrientCalculator.allergensOf(
                recipe,
                foodsById,
              ),
              dietTags: RecipeNutrientCalculator.dietTagsOf(recipe, foodsById),
            ),
            foodsById: foodsById,
          ),
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: recipe.id);
    }
  });
}
