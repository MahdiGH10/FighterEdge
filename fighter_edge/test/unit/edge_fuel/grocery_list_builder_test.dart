import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/grocery_list_builder.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/grocery_list.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/recipe.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/recipe_publication_gate.dart';
import 'package:flutter_test/flutter_test.dart';

FoodItem _food(String id, String name, FoodCategory category) => FoodItem(
      id: id,
      name: name,
      category: category,
      kcalPer100g: 100,
      proteinPer100g: 10,
      carbsPer100g: 10,
      fatPer100g: 1,
      fibrePer100g: 1,
    );

final _foods = {
  'rice': _food('rice', 'Rice, white', FoodCategory.grain),
  'chicken': _food('chicken', 'Chicken breast', FoodCategory.protein),
  'egg': _food('egg', 'Egg', FoodCategory.protein),
  'spinach': _food('spinach', 'Spinach', FoodCategory.vegetable),
};

Recipe _recipe(
  String id,
  List<RecipeIngredient> ingredients, {
  ContentStatus status = ContentStatus.published,
  int servings = 2,
}) =>
    Recipe(
      id: id,
      title: id,
      description: '',
      servings: servings,
      ingredients: ingredients,
      steps: const ['Cook.'],
      mealType: MealType.lunch,
      status: status,
    );

final _bowl = _recipe('bowl', const [
  RecipeIngredient(foodId: 'rice', grams: 150, householdUnitLabel: '1 cup'),
  RecipeIngredient(foodId: 'chicken', grams: 200),
  RecipeIngredient(foodId: 'spinach', grams: 30, optional: true),
]);

final _scramble = _recipe('scramble', const [
  RecipeIngredient(foodId: 'egg', grams: 150),
  RecipeIngredient(foodId: 'spinach', grams: 40),
  RecipeIngredient(foodId: 'chicken', grams: 50),
]);

GroceryList _build(
  List<GroceryRecipePlan> plan, {
  bool includeOptional = false,
  bool publishedOnly = true,
}) =>
    GroceryListBuilder.build(
      plan: plan,
      foodsById: _foods,
      includeOptional: includeOptional,
      publishedOnly: publishedOnly,
    );

GroceryItem _item(GroceryList list, String id) =>
    list.items.firstWhere((i) => i.foodId == id);

void main() {
  group('merge by food id', () {
    test('sums the same food across recipes', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl),
        GroceryRecipePlan(recipe: _scramble),
      ]);
      expect(_item(list, 'chicken').grams, 250);
      expect(_item(list, 'chicken').recipeIds, ['bowl', 'scramble']);
      expect(list.items.where((i) => i.foodId == 'chicken'), hasLength(1));
    });

    test('same recipe twice in the plan also merges', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl),
        GroceryRecipePlan(recipe: _bowl),
      ]);
      expect(_item(list, 'rice').grams, 300);
      expect(_item(list, 'rice').recipeIds, ['bowl']);
    });

    test('an empty plan gives an empty list', () {
      final list = _build(const []);
      expect(list.isEmpty, isTrue);
      expect(list.toPlainText(), '');
    });

    test('items sort by category, then name', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl),
        GroceryRecipePlan(recipe: _scramble),
      ]);
      expect(
        list.items.map((i) => i.foodId).toList(),
        ['chicken', 'egg', 'rice', 'spinach'],
      );
    });

    test('ignores lines with no food id or no usable grams', () {
      final odd = _recipe('odd', const [
        RecipeIngredient(foodId: '', grams: 50),
        RecipeIngredient(foodId: 'rice', grams: 0),
        RecipeIngredient(foodId: 'egg', grams: double.nan),
        RecipeIngredient(foodId: 'chicken', grams: 80),
      ]);
      final list = _build([GroceryRecipePlan(recipe: odd)]);
      expect(list.items.map((i) => i.foodId), ['chicken']);
    });

    test('a food missing from the catalog is kept and flagged', () {
      final r = _recipe('mystery', const [
        RecipeIngredient(foodId: 'zzz', grams: 10),
      ]);
      final list = _build([GroceryRecipePlan(recipe: r)]);
      expect(list.items.single.unknownFood, isTrue);
      expect(list.items.single.name, 'zzz');
      expect(list.items.single.category, FoodCategory.other);
    });
  });

  group('optional ingredients', () {
    test('left out by default', () {
      final list = _build([GroceryRecipePlan(recipe: _bowl)]);
      expect(list.items.any((i) => i.foodId == 'spinach'), isFalse);
    });

    test('included on request and merged with required lines', () {
      final list = _build(
        [
          GroceryRecipePlan(recipe: _bowl),
          GroceryRecipePlan(recipe: _scramble),
        ],
        includeOptional: true,
      );
      expect(_item(list, 'spinach').grams, 70);
    });
  });

  group('cook multiplier', () {
    test('x4 multiplies every ingredient', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: 4),
      ]);
      expect(_item(list, 'rice').grams, 600);
      expect(_item(list, 'chicken').grams, 800);
    });

    test('servings made is servings times the multiplier', () {
      expect(
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: 4).servingsMade,
        8,
      );
    });

    test('multipliers differ per recipe and add up', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: 4),
        GroceryRecipePlan(recipe: _scramble, cookMultiplier: 2),
      ]);
      expect(_item(list, 'chicken').grams, 900);
    });

    test('half a batch is allowed', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: 0.5),
      ]);
      expect(_item(list, 'rice').grams, 75);
    });

    test('out-of-range and non-finite multipliers are clamped', () {
      expect(GroceryListBuilder.clampMultiplier(0), 0.5);
      expect(GroceryListBuilder.clampMultiplier(-3), 0.5);
      expect(GroceryListBuilder.clampMultiplier(500), 20);
      expect(GroceryListBuilder.clampMultiplier(double.nan), 1);
      expect(GroceryListBuilder.clampMultiplier(double.infinity), 1);
      expect(GroceryListBuilder.clampMultiplier(4), 4);
      final list = _build([
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: double.nan),
      ]);
      expect(_item(list, 'rice').grams, 150);
    });

    test('fractions round up to a whole gram', () {
      final r = _recipe('odd', const [
        RecipeIngredient(foodId: 'rice', grams: 33.4),
      ]);
      final list = _build([GroceryRecipePlan(recipe: r, cookMultiplier: 3)]);
      // 100.2 g, rounded up.
      expect(_item(list, 'rice').grams, 101);
    });

    test('float noise does not push an exact total up a gram', () {
      final r = _recipe('tenths', const [
        RecipeIngredient(foodId: 'rice', grams: 0.1),
        RecipeIngredient(foodId: 'rice', grams: 0.2),
        RecipeIngredient(foodId: 'rice', grams: 0.7),
      ]);
      final list = _build([GroceryRecipePlan(recipe: r)]);
      expect(_item(list, 'rice').grams, 1);
    });
  });

  group('household label', () {
    test('kept for one line cooked once', () {
      final list = _build([GroceryRecipePlan(recipe: _bowl)]);
      expect(_item(list, 'rice').householdLabel, '1 cup');
      expect(_item(list, 'chicken').householdLabel, isNull);
    });

    test('dropped once the grams are scaled', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl, cookMultiplier: 4),
      ]);
      expect(_item(list, 'rice').householdLabel, isNull);
    });

    test('dropped once the food is merged from several lines', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl),
        GroceryRecipePlan(recipe: _bowl),
      ]);
      expect(_item(list, 'rice').householdLabel, isNull);
    });
  });

  group('publication gate in the list', () {
    final draft = _recipe(
      'draft-bowl',
      const [RecipeIngredient(foodId: 'rice', grams: 999)],
      status: ContentStatus.draft,
    );

    test('draft recipes are skipped and reported', () {
      final list = _build([
        GroceryRecipePlan(recipe: _bowl),
        GroceryRecipePlan(recipe: draft),
        GroceryRecipePlan(recipe: draft),
      ]);
      expect(_item(list, 'rice').grams, 150);
      expect(list.skippedRecipeIds, ['draft-bowl']);
    });

    test('publishedOnly false lets drafts through', () {
      final list = _build(
        [GroceryRecipePlan(recipe: draft)],
        publishedOnly: false,
      );
      expect(_item(list, 'rice').grams, 999);
      expect(list.skippedRecipeIds, isEmpty);
    });

    test('only drafts gives an empty list', () {
      final list = _build([GroceryRecipePlan(recipe: draft)]);
      expect(list.isEmpty, isTrue);
      expect(list.skippedRecipeIds, ['draft-bowl']);
    });
  });

  group('checklist and sharing (offline)', () {
    final base = _build([
      GroceryRecipePlan(recipe: _bowl),
      GroceryRecipePlan(recipe: _scramble),
    ]);

    test('toggle flips one line and leaves the original alone', () {
      final next = base.toggled('rice');
      expect(_item(next, 'rice').checked, isTrue);
      expect(next.checkedCount, 1);
      expect(base.checkedCount, 0);
      expect(next.toggled('rice').checkedCount, 0);
      expect(base.toggled('nope').checkedCount, 0);
    });

    test('checks carry over to a rebuilt list for foods still on it', () {
      final checked = base.toggled('rice').toggled('egg');
      final rebuilt =
          _build([GroceryRecipePlan(recipe: _bowl)]).withChecksFrom(checked);
      expect(_item(rebuilt, 'rice').checked, isTrue);
      expect(rebuilt.items.any((i) => i.foodId == 'egg'), isFalse);
      expect(_item(rebuilt, 'chicken').checked, isFalse);
    });

    test('plain text has one line per food', () {
      final text = base.toggled('egg').toPlainText();
      expect(text.split('\n'), [
        '- [ ] Chicken breast: 250 g',
        '- [x] Egg: 150 g',
        '- [ ] Rice, white: 150 g',
        '- [ ] Spinach: 40 g',
      ]);
    });

    test('json round trip keeps everything', () {
      final list = _build(
        [
          GroceryRecipePlan(recipe: _bowl),
          GroceryRecipePlan(
            recipe: _recipe('draft', const []),
            cookMultiplier: 1,
          ),
        ],
      ).toggled('rice');
      final again = GroceryList.fromJson(
        jsonDecode(jsonEncode(list.toJson())) as Map<String, dynamic>,
      );
      expect(again.toPlainText(), list.toPlainText());
      expect(_item(again, 'rice').householdLabel, '1 cup');
      expect(_item(again, 'rice').recipeIds, ['bowl']);
      expect(_item(again, 'rice').checked, isTrue);
    });

    test('fromJson survives bad data', () {
      final list = GroceryList.fromJson({
        'items': [
          'not a map',
          {'foodId': '', 'grams': 5},
          {'foodId': 'a', 'grams': -3},
          {'foodId': 'b', 'grams': 12.4, 'category': 'nope'},
        ],
        'skippedRecipeIds': [1, 'x'],
      });
      expect(list.items, hasLength(1));
      expect(list.items.single.grams, 12);
      expect(list.items.single.category, FoodCategory.other);
      expect(list.skippedRecipeIds, ['x']);
      expect(GroceryList.fromJson(const {}).isEmpty, isTrue);
    });

    test('unknown food flag survives the round trip', () {
      final r = _recipe('m', const [RecipeIngredient(foodId: 'zzz', grams: 5)]);
      final list = _build([GroceryRecipePlan(recipe: r)]);
      final again = GroceryList.fromJson(list.toJson());
      expect(again.items.single.unknownFood, isTrue);
    });
  });

  group('RecipePublicationGate', () {
    Recipe withStatus(ContentStatus s) =>
        _recipe('r-${s.name}', const [], status: s);

    test('only published is visible', () {
      expect(RecipePublicationGate.isVisible(withStatus(ContentStatus.draft)),
          isFalse);
      expect(
          RecipePublicationGate.isVisible(withStatus(ContentStatus.reviewed)),
          isFalse);
      expect(RecipePublicationGate.isVisible(withStatus(ContentStatus.retired)),
          isFalse);
      expect(
          RecipePublicationGate.isVisible(withStatus(ContentStatus.published)),
          isTrue);
    });

    test('visible and hidden split a list and keep its order', () {
      final all = [
        withStatus(ContentStatus.published),
        withStatus(ContentStatus.draft),
        withStatus(ContentStatus.retired),
      ];
      expect(
          RecipePublicationGate.visible(all).map((r) => r.id), ['r-published']);
      expect(RecipePublicationGate.hidden(all).map((r) => r.id),
          ['r-draft', 'r-retired']);
    });

    test('the shipped recipes are all hidden until a reviewer publishes', () {
      final json = jsonDecode(
        File('assets/data/edge_fuel_recipes_v1.json').readAsStringSync(),
      ) as Map<String, dynamic>;
      final recipes = (json['recipes'] as List<dynamic>)
          .cast<Map<String, dynamic>>()
          .map(Recipe.fromJson)
          .toList();
      expect(recipes, isNotEmpty);
      final published =
          recipes.where((r) => r.status == ContentStatus.published);
      // Nothing but a published recipe is ever visible. Today all shipped
      // recipes are drafts, so the visible list is empty.
      expect(RecipePublicationGate.visible(recipes), published.toList());
      expect(
        RecipePublicationGate.visible(recipes)
            .every((r) => r.status == ContentStatus.published),
        isTrue,
      );
    });
  });
}
