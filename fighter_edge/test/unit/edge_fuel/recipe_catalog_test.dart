import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/recipe_nutrient_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/recipe.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/catalog_validation.dart';
import 'package:flutter_test/flutter_test.dart';

Future<String> _readRealAsset(String path) => File(path).readAsString();

/// Hand-checkable food table for the calculator tests.
const _chicken = FoodItem(
  id: 'chicken',
  name: 'Chicken',
  category: FoodCategory.protein,
  kcalPer100g: 120,
  proteinPer100g: 22.5,
  carbsPer100g: 0,
  fatPer100g: 2.6,
  fibrePer100g: 0,
);

const _rice = FoodItem(
  id: 'rice',
  name: 'Rice',
  category: FoodCategory.grain,
  kcalPer100g: 130,
  proteinPer100g: 2.7,
  carbsPer100g: 28.2,
  fatPer100g: 0.3,
  fibrePer100g: 0.4,
  dietTags: {DietTag.vegan, DietTag.vegetarian},
);

const _milk = FoodItem(
  id: 'milk',
  name: 'Milk',
  category: FoodCategory.dairy,
  kcalPer100g: 50,
  proteinPer100g: 3.4,
  carbsPer100g: 4.8,
  fatPer100g: 1.8,
  fibrePer100g: 0,
  allergens: {Allergen.milk},
  dietTags: {DietTag.vegetarian},
);

const _butter = FoodItem(
  id: 'butter',
  name: 'Butter',
  category: FoodCategory.fat,
  kcalPer100g: 717,
  proteinPer100g: 0.9,
  carbsPer100g: 0.1,
  fatPer100g: 81.1,
  fibrePer100g: 0,
  allergens: {Allergen.milk},
  dietTags: {DietTag.vegetarian},
);

const _foods = <String, FoodItem>{
  'chicken': _chicken,
  'rice': _rice,
  'milk': _milk,
  'butter': _butter,
};

Recipe _recipe({
  String id = 'test',
  int servings = 1,
  List<RecipeIngredient> ingredients = const [],
}) {
  return Recipe(
    id: id,
    title: 'Test recipe',
    description: 'A recipe used only in tests.',
    servings: servings,
    ingredients: ingredients,
    steps: const ['Do the thing.'],
    mealType: MealType.lunch,
    prepMinutes: 5,
  );
}

void main() {
  group('RecipeNutrientCalculator', () {
    test('hand-verified vector: 200 g chicken + 250 g rice', () {
      // 200 g chicken: 240.0 kcal, 45.0 P, 0.0 C, 5.2 F
      // 250 g rice:    325.0 kcal,  6.75 P, 70.5 C, 0.75 F, 1.0 fibre
      // total:         565.0 kcal, 51.75 P, 70.5 C, 5.95 F, 1.0 fibre
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'chicken', grams: 200),
          RecipeIngredient(foodId: 'rice', grams: 250),
        ],
      );

      final total = RecipeNutrientCalculator.forRecipe(recipe, _foods);

      expect(total.kcal, closeTo(565.0, 0.001));
      expect(total.proteinGrams, closeTo(51.75, 0.001));
      expect(total.carbGrams, closeTo(70.5, 0.001));
      expect(total.fatGrams, closeTo(5.95, 0.001));
      expect(total.fibreGrams, closeTo(1.0, 0.001));
    });

    test('divides by servings', () {
      final recipe = _recipe(
        servings: 4,
        ingredients: const [RecipeIngredient(foodId: 'rice', grams: 400)],
      );
      expect(
        RecipeNutrientCalculator.perServing(recipe, _foods).kcal,
        closeTo(130.0, 0.001),
      );
    });

    test('treats servings of zero as one rather than dividing by zero', () {
      const recipe = Recipe(
        id: 'zero',
        title: 'Zero',
        description: 'd',
        servings: 0,
        ingredients: [RecipeIngredient(foodId: 'rice', grams: 100)],
        steps: ['s'],
        mealType: MealType.lunch,
      );
      expect(
        RecipeNutrientCalculator.perServing(recipe, _foods).kcal,
        closeTo(130.0, 0.001),
      );
    });

    test('scales to fractional servings for the serving stepper', () {
      final recipe = _recipe(
        servings: 2,
        ingredients: const [RecipeIngredient(foodId: 'rice', grams: 200)],
      );
      expect(
        RecipeNutrientCalculator.forServings(recipe, _foods, 1.5).kcal,
        closeTo(195.0, 0.001),
      );
      expect(RecipeNutrientCalculator.forServings(recipe, _foods, 0).kcal, 0);
      expect(RecipeNutrientCalculator.forServings(recipe, _foods, -1).kcal, 0);
    });

    test('rounds once at the boundary, not per ingredient', () {
      // Three ingredients that each round down individually but should not
      // compound: 0.4 + 0.4 + 0.4 = 1.2 -> 1, not 0.
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'rice', grams: 1),
          RecipeIngredient(foodId: 'rice', grams: 1),
          RecipeIngredient(foodId: 'rice', grams: 1),
        ],
      );
      final total = RecipeNutrientCalculator.forRecipe(recipe, _foods);
      expect(total.kcal, closeTo(3.9, 0.001));
      expect(total.kcalRounded, 4);
    });

    test(
      'excludes optional ingredients by default, includes them on request',
      () {
        final recipe = _recipe(
          ingredients: const [
            RecipeIngredient(foodId: 'rice', grams: 100),
            RecipeIngredient(foodId: 'butter', grams: 10, optional: true),
          ],
        );

        expect(
          RecipeNutrientCalculator.forRecipe(recipe, _foods).kcal,
          closeTo(130.0, 0.001),
        );
        expect(
          RecipeNutrientCalculator.forRecipe(
            recipe,
            _foods,
            includeOptional: true,
          ).kcal,
          closeTo(201.7, 0.001),
        );
      },
    );

    test('throws on an unknown food rather than silently counting zero', () {
      final recipe = _recipe(
        ingredients: const [RecipeIngredient(foodId: 'unicorn', grams: 100)],
      );
      expect(
        () => RecipeNutrientCalculator.forRecipe(recipe, _foods),
        throwsA(isA<UnknownFoodException>()),
      );
    });

    test('ignores zero and negative ingredient weights', () {
      final recipe = _recipe(
        ingredients: const [RecipeIngredient(foodId: 'rice', grams: 0)],
      );
      expect(RecipeNutrientCalculator.forRecipe(recipe, _foods).kcal, 0);
    });
  });

  group('derived allergens and diet tags', () {
    test('allergens are the union of the ingredients', () {
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'rice', grams: 100),
          RecipeIngredient(foodId: 'milk', grams: 100),
        ],
      );
      expect(RecipeNutrientCalculator.allergensOf(recipe, _foods), {
        Allergen.milk,
      });
    });

    test('an optional ingredient still declares its allergen', () {
      // Its calories are excluded, but someone allergic still needs the warning.
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'rice', grams: 100),
          RecipeIngredient(foodId: 'butter', grams: 5, optional: true),
        ],
      );
      expect(
        RecipeNutrientCalculator.allergensOf(recipe, _foods),
        contains(Allergen.milk),
      );
    });

    test('extraAllergens are added on top of the ingredients', () {
      const recipe = Recipe(
        id: 'x',
        title: 'X',
        description: 'd',
        servings: 1,
        ingredients: [RecipeIngredient(foodId: 'rice', grams: 100)],
        steps: ['s'],
        mealType: MealType.lunch,
        extraAllergens: {Allergen.sesame},
      );
      expect(RecipeNutrientCalculator.allergensOf(recipe, _foods), {
        Allergen.sesame,
      });
    });

    test(
      'diet tags are the intersection — one dairy ingredient kills vegan',
      () {
        final recipe = _recipe(
          ingredients: const [
            RecipeIngredient(foodId: 'rice', grams: 100),
            RecipeIngredient(foodId: 'milk', grams: 100),
          ],
        );
        final tags = RecipeNutrientCalculator.dietTagsOf(recipe, _foods);
        expect(tags, contains(DietTag.vegetarian));
        expect(tags, isNot(contains(DietTag.vegan)));
      },
    );

    test('an optional non-vegan ingredient still removes the vegan tag', () {
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'rice', grams: 100),
          RecipeIngredient(foodId: 'butter', grams: 5, optional: true),
        ],
      );
      expect(
        RecipeNutrientCalculator.dietTagsOf(recipe, _foods),
        isNot(contains(DietTag.vegan)),
      );
    });

    test('a meat ingredient with no tags empties the whole set', () {
      final recipe = _recipe(
        ingredients: const [
          RecipeIngredient(foodId: 'chicken', grams: 100),
          RecipeIngredient(foodId: 'rice', grams: 100),
        ],
      );
      expect(RecipeNutrientCalculator.dietTagsOf(recipe, _foods), isEmpty);
    });
  });

  group('RecipeCatalogValidator', () {
    test('accepts a well-formed recipe', () {
      final recipe = _recipe(
        ingredients: const [RecipeIngredient(foodId: 'rice', grams: 200)],
      );
      expect(RecipeCatalogValidator.validate([recipe], _foods), isEmpty);
    });

    test('flags an unknown ingredient', () {
      final recipe = _recipe(
        ingredients: const [RecipeIngredient(foodId: 'unicorn', grams: 100)],
      );
      final issues = RecipeCatalogValidator.validate([recipe], _foods);
      expect(issues.map((i) => i.message).join(), contains('unknown food'));
    });

    test('flags an implausible per-serving calorie count', () {
      final recipe = _recipe(
        ingredients: const [RecipeIngredient(foodId: 'butter', grams: 1000)],
      );
      final issues = RecipeCatalogValidator.validate([recipe], _foods);
      expect(issues.map((i) => i.message).join(), contains('implausible'));
    });

    test('flags a status promoted without a reviewer credit', () {
      const recipe = Recipe(
        id: 'promoted',
        title: 'Promoted',
        description: 'd',
        servings: 1,
        ingredients: [RecipeIngredient(foodId: 'rice', grams: 200)],
        steps: ['s'],
        mealType: MealType.lunch,
        prepMinutes: 5,
        status: ContentStatus.reviewed,
      );
      final issues = RecipeCatalogValidator.validate([recipe], _foods);
      expect(issues.map((i) => i.message).join(), contains('no reviewer'));
    });

    test('flags a substitution pointing at an unknown food', () {
      const recipe = Recipe(
        id: 'sub',
        title: 'Sub',
        description: 'd',
        servings: 1,
        ingredients: [RecipeIngredient(foodId: 'rice', grams: 200)],
        steps: ['s'],
        mealType: MealType.lunch,
        prepMinutes: 5,
        substitutions: [
          RecipeSubstitution(forFoodId: 'rice', useFoodId: 'unicorn'),
        ],
      );
      final issues = RecipeCatalogValidator.validate([recipe], _foods);
      expect(issues.map((i) => i.message).join(), contains('unknown food'));
    });

    test('composition check reports what a thin catalog is missing', () {
      final issues = RecipeCatalogValidator.validateComposition([
        _recipe(
          ingredients: const [RecipeIngredient(foodId: 'rice', grams: 200)],
        ),
      ], _foods);
      final text = issues.map((i) => i.message).join('\n');
      expect(text, contains('at least 24 recipes'));
      expect(text, contains('pre-training'));
      expect(text, contains('post-training'));
    });
  });

  group('AssetRecipeCatalogRepository', () {
    test('parses and caches', () async {
      var loads = 0;
      final foods = AssetFoodCatalogRepository(loadString: _readRealAsset);
      final repo = AssetRecipeCatalogRepository(
        foodCatalog: foods,
        loadString: (path) async {
          loads++;
          return _readRealAsset(path);
        },
      );

      final all = await repo.loadAll();
      expect(all, isNotEmpty);
      await repo.loadAll();
      expect(loads, 1);
      expect(await repo.byId('overnight-oats-banana-peanut'), isNotNull);
      expect(await repo.byId('nope'), isNull);
    });

    test('rejects a catalog with no recipes array', () async {
      final repo = AssetRecipeCatalogRepository(
        foodCatalog: AssetFoodCatalogRepository(loadString: _readRealAsset),
        loadString: (_) async => jsonEncode({'nope': []}),
      );
      expect(repo.loadAll(), throwsA(isA<FormatException>()));
    });
  });

  group('the shipped recipe catalog', () {
    late List<Recipe> recipes;
    late Map<String, FoodItem> foods;

    setUpAll(() async {
      final foodRepo = AssetFoodCatalogRepository(loadString: _readRealAsset);
      foods = {for (final f in await foodRepo.loadAll()) f.id: f};
      final repo = AssetRecipeCatalogRepository(
        foodCatalog: foodRepo,
        loadString: _readRealAsset,
      );
      recipes = await repo.loadAll();
    });

    test('passes every per-recipe integrity check', () {
      final issues = RecipeCatalogValidator.validate(recipes, foods);
      expect(
        issues,
        isEmpty,
        reason: issues.map((i) => i.toString()).join('\n'),
      );
    });

    test('meets the master prompt §9.1 composition floor', () {
      final issues = RecipeCatalogValidator.validateComposition(recipes, foods);
      expect(
        issues,
        isEmpty,
        reason: issues.map((i) => i.toString()).join('\n'),
      );
    });

    test('every ingredient resolves against the food table', () {
      for (final recipe in recipes) {
        for (final ingredient in recipe.ingredients) {
          expect(
            foods.containsKey(ingredient.foodId),
            isTrue,
            reason: '${recipe.id} -> ${ingredient.foodId}',
          );
        }
      }
    });

    test('no recipe stores its own nutrients', () {
      // §2.4: recipe nutrition is calculated from structured ingredient data.
      // If a future edit adds a per-serving figure to the JSON, the model will
      // ignore it — this test documents that the model has no such field.
      expect(
        Recipe.fromJson({
          'id': 'x',
          'title': 'X',
          'description': 'd',
          'servings': 1,
          'kcalPerServing': 9999,
          'ingredients': [
            {'foodId': 'rice', 'grams': 100},
          ],
          'steps': ['s'],
        }).toJson().containsKey('kcalPerServing'),
        isFalse,
      );
    });

    test('ships entirely as draft until a reviewer signs off', () {
      expect(recipes.every((r) => r.status == ContentStatus.draft), isTrue);
      expect(recipes.every((r) => r.reviewerCredit == null), isTrue);
    });

    test('carries no image assets in V1', () {
      // EF3_PLAN.md §8 decision 2 — typographic cards, not placeholder stock.
      expect(recipes.every((r) => r.imageAsset == null), isTrue);
    });

    test('every recipe has a plausible per-serving calorie count', () {
      for (final recipe in recipes) {
        final kcal = RecipeNutrientCalculator.perServing(recipe, foods).kcal;
        expect(kcal, greaterThan(150), reason: recipe.id);
        expect(kcal, lessThan(700), reason: recipe.id);
      }
    });

    test('pre-training recipes are low in fat and fibre', () {
      // The whole point of a pre-training meal is that it digests quickly.
      // A "pre-training" recipe loaded with fat would be actively bad advice.
      final pre = recipes
          .where((r) => r.trainingTiming == TrainingTiming.preTraining)
          .toList();
      expect(pre, isNotEmpty);
      for (final recipe in pre) {
        final n = RecipeNutrientCalculator.perServing(recipe, foods);
        expect(n.fatGrams, lessThan(15), reason: '${recipe.id} fat');
        expect(n.fibreGrams, lessThan(12), reason: '${recipe.id} fibre');
      }
    });

    test('post-training recipes carry real protein', () {
      final post = recipes
          .where((r) => r.trainingTiming == TrainingTiming.postTraining)
          .toList();
      expect(post, isNotEmpty);
      for (final recipe in post) {
        final n = RecipeNutrientCalculator.perServing(recipe, foods);
        expect(n.proteinGrams, greaterThanOrEqualTo(20), reason: recipe.id);
      }
    });

    test('the free tier is genuinely useful, not a teaser', () {
      final free = recipes.where((r) => !r.isPremium).toList();
      expect(free.length, greaterThanOrEqualTo(12));
      // Free recipes must span the day, not just be twelve snacks.
      final freeMealTypes = free.map((r) => r.mealType).toSet();
      expect(freeMealTypes, contains(MealType.breakfast));
      expect(
        freeMealTypes,
        anyOf(contains(MealType.lunch), contains(MealType.dinner)),
      );
      // And every free recipe must be complete: steps, times, ingredients.
      for (final recipe in free) {
        expect(recipe.steps.length, greaterThanOrEqualTo(2), reason: recipe.id);
        expect(recipe.totalMinutes, greaterThan(0), reason: recipe.id);
      }
    });

    test('derived diet tags never contradict the ingredients', () {
      for (final recipe in recipes) {
        final tags = RecipeNutrientCalculator.dietTagsOf(recipe, foods);
        final allergens = RecipeNutrientCalculator.allergensOf(recipe, foods);
        if (tags.contains(DietTag.vegan)) {
          expect(
            allergens.contains(Allergen.milk),
            isFalse,
            reason: '${recipe.id} is vegan but contains milk',
          );
          expect(
            allergens.contains(Allergen.eggs),
            isFalse,
            reason: '${recipe.id} is vegan but contains eggs',
          );
        }
        if (tags.contains(DietTag.vegetarian)) {
          expect(
            allergens.contains(Allergen.fish),
            isFalse,
            reason: '${recipe.id} is vegetarian but contains fish',
          );
          expect(
            allergens.contains(Allergen.shellfish),
            isFalse,
            reason: '${recipe.id} is vegetarian but contains shellfish',
          );
        }
      }
    });

    test('every recipe id is a stable slug', () {
      final slug = RegExp(r'^[a-z0-9]+(-[a-z0-9]+)*$');
      for (final recipe in recipes) {
        expect(slug.hasMatch(recipe.id), isTrue, reason: recipe.id);
      }
    });
  });
}
