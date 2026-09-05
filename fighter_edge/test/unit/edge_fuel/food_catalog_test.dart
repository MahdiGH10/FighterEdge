import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/catalog_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the real shipped asset off disk rather than through `rootBundle`, so
/// the catalog is verified as authored — not as some fixture we wrote to pass.
Future<String> _readRealAsset(String path) => File(path).readAsString();

FoodItem _food({
  String id = 'test-food',
  String name = 'Test food',
  double kcal = 100,
  double protein = 10,
  double carbs = 10,
  double fat = 2,
  double fibre = 0,
  List<HouseholdUnit> units = const [],
  String source = 'USDA FoodData Central',
}) {
  return FoodItem(
    id: id,
    name: name,
    category: FoodCategory.other,
    kcalPer100g: kcal,
    proteinPer100g: protein,
    carbsPer100g: carbs,
    fatPer100g: fat,
    fibrePer100g: fibre,
    householdUnits: units,
    source: source,
  );
}

void main() {
  group('FoodItem JSON', () {
    test('round-trips through toJson/fromJson', () {
      const original = FoodItem(
        id: 'oats-rolled',
        name: 'Oats, rolled, dry',
        category: FoodCategory.grain,
        kcalPer100g: 389,
        proteinPer100g: 16.9,
        carbsPer100g: 66.3,
        fatPer100g: 6.9,
        fibrePer100g: 10.6,
        householdUnits: [HouseholdUnit(label: '1 serving', grams: 40)],
        allergens: {Allergen.gluten},
        dietTags: {DietTag.vegan, DietTag.vegetarian},
        sourceRef: '169705',
        status: ContentStatus.draft,
      );

      final restored = FoodItem.fromJson(original.toJson());

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.category, FoodCategory.grain);
      expect(restored.kcalPer100g, 389);
      expect(restored.fibrePer100g, 10.6);
      expect(restored.householdUnits.single.grams, 40);
      expect(restored.allergens, {Allergen.gluten});
      expect(restored.dietTags, {DietTag.vegan, DietTag.vegetarian});
      expect(restored.sourceRef, '169705');
      expect(restored.status, ContentStatus.draft);
    });

    test('clamps negative nutrients to zero rather than subtracting later', () {
      final food = FoodItem.fromJson({
        'id': 'bad',
        'name': 'Bad record',
        'kcalPer100g': -50,
        'proteinPer100g': -10,
      });

      expect(food.kcalPer100g, 0);
      expect(food.proteinPer100g, 0);
    });

    test('unknown enum names fall back instead of throwing', () {
      final food = FoodItem.fromJson({
        'id': 'x',
        'name': 'X',
        'category': 'not-a-category',
        'status': 'not-a-status',
        'allergens': ['milk', 'not-an-allergen'],
      });

      expect(food.category, FoodCategory.other);
      expect(food.status, ContentStatus.draft);
      expect(food.allergens, {Allergen.milk});
    });
  });

  group('FoodCatalogValidator', () {
    test('accepts a well-formed record', () {
      expect(FoodCatalogValidator.validate([_food()]), isEmpty);
    });

    test('flags a duplicate id', () {
      final issues = FoodCatalogValidator.validate([
        _food(id: 'dup'),
        _food(id: 'dup'),
      ]);
      expect(issues.map((i) => i.message), contains('duplicate id'));
    });

    test('flags macros summing past 100 g per 100 g', () {
      final issues = FoodCatalogValidator.validate([
        _food(protein: 50, carbs: 50, fat: 20, kcal: 580),
      ]);
      expect(issues.single.message, contains('macros sum to'));
    });

    test('flags fibre exceeding carbohydrate', () {
      final issues = FoodCatalogValidator.validate([
        _food(carbs: 5, fibre: 20, kcal: 60),
      ]);
      expect(issues.map((i) => i.message).join(), contains('fibre'));
    });

    test('flags a dropped digit in a calorie-dense record', () {
      // Almonds with kcal mistyped as 57.9 instead of 579.
      final issues = FoodCatalogValidator.validate([
        _food(kcal: 57.9, protein: 21.2, carbs: 21.6, fat: 49.9, fibre: 12.5),
      ]);
      expect(issues.single.message, contains('drift'));
    });

    test('does not flag low-calorie foods over rounding noise', () {
      // Lemon juice: 39% relative drift, but only ~9 kcal absolute. Flagging
      // this would train us to ignore the check.
      final issues = FoodCatalogValidator.validate([
        _food(kcal: 22, protein: 0.4, carbs: 6.9, fat: 0.2, fibre: 0.3),
      ]);
      expect(issues, isEmpty);
    });

    test('does not flag high-fibre foods, which the naive formula would', () {
      // Raw spinach drifts 28% under protein*4 + carbs*4 + fat*9.
      final issues = FoodCatalogValidator.validate([
        _food(kcal: 23, protein: 2.9, carbs: 3.6, fat: 0.4, fibre: 2.2),
      ]);
      expect(issues, isEmpty);
    });

    test('flags a household unit with no weight', () {
      final issues = FoodCatalogValidator.validate([
        _food(units: const [HouseholdUnit(label: '1 scoop', grams: 0)]),
      ]);
      expect(issues.single.message, contains('invalid household unit'));
    });

    test('flags a missing source attribution', () {
      final issues = FoodCatalogValidator.validate([_food(source: '')]);
      expect(issues.single.message, contains('source'));
    });
  });

  group('AssetFoodCatalogRepository', () {
    test('parses, caches, and indexes the catalog', () async {
      var loads = 0;
      final repo = AssetFoodCatalogRepository(
        loadString: (path) async {
          loads++;
          return jsonEncode({
            'foods': [
              {
                'id': 'chicken-breast-raw',
                'name': 'Chicken breast, skinless, raw',
                'category': 'protein',
                'kcalPer100g': 120,
                'proteinPer100g': 22.5,
                'carbsPer100g': 0,
                'fatPer100g': 2.6,
                'fibrePer100g': 0,
              },
            ],
          });
        },
      );

      final all = await repo.loadAll();
      expect(all, hasLength(1));

      await repo.loadAll();
      expect(loads, 1, reason: 'catalog is immutable content — parse once');

      expect(
        (await repo.byId('chicken-breast-raw'))?.name,
        'Chicken breast, skinless, raw',
      );
      expect(
        await repo.byId('nope'),
        isNull,
        reason: 'unknown ids must be detectable, not zero-nutrient foods',
      );
    });

    test('search is case-insensitive and honours limit', () async {
      // Macros must be internally consistent even in fixtures — the repository
      // validates in debug, which is exactly the point of the check.
      final repo = AssetFoodCatalogRepository(
        loadString: (_) async => jsonEncode({
          'foods': [
            {
              'id': 'a',
              'name': 'Brown rice, cooked',
              'kcalPer100g': 123,
              'proteinPer100g': 2.7,
              'carbsPer100g': 25.6,
              'fatPer100g': 1.0,
              'fibrePer100g': 1.6,
            },
            {
              'id': 'b',
              'name': 'White rice, cooked',
              'kcalPer100g': 130,
              'proteinPer100g': 2.7,
              'carbsPer100g': 28.2,
              'fatPer100g': 0.3,
              'fibrePer100g': 0.4,
            },
            {
              'id': 'c',
              'name': 'Almonds, raw',
              'kcalPer100g': 579,
              'proteinPer100g': 21.2,
              'carbsPer100g': 21.6,
              'fatPer100g': 49.9,
              'fibrePer100g': 12.5,
            },
          ],
        }),
      );

      expect((await repo.search('RICE')).map((f) => f.id), ['a', 'b']);
      expect(await repo.search('rice', limit: 1), hasLength(1));
      expect(await repo.search(''), hasLength(3));
      expect(await repo.search('   '), hasLength(3));
    });

    test('rejects a catalog with no foods array', () async {
      final repo = AssetFoodCatalogRepository(
        loadString: (_) async => jsonEncode({'nope': []}),
      );
      expect(repo.loadAll(), throwsA(isA<FormatException>()));
    });

    test('a second attempt after a failure still works', () async {
      var attempt = 0;
      final repo = AssetFoodCatalogRepository(
        loadString: (_) async {
          if (attempt++ == 0) throw Exception('transient read failure');
          return jsonEncode({
            'foods': [
              {'id': 'a', 'name': 'A', 'kcalPer100g': 0},
            ],
          });
        },
      );

      await expectLater(repo.loadAll(), throwsA(isA<Exception>()));
      expect(
        await repo.loadAll(),
        hasLength(1),
        reason: 'a failed load must not poison the in-flight future',
      );
    });
  });

  group('the shipped food catalog', () {
    late List<FoodItem> foods;

    setUpAll(() async {
      final repo = AssetFoodCatalogRepository(loadString: _readRealAsset);
      foods = await repo.loadAll();
    });

    test('passes every content-integrity check', () {
      final issues = FoodCatalogValidator.validate(foods);
      expect(
        issues,
        isEmpty,
        reason: issues.map((i) => i.toString()).join('\n'),
      );
    });

    test('is large enough to build the EF-3 recipe catalog on', () {
      // The 24-recipe floor in master prompt §9.1 needs real breadth. This is a
      // floor, not a target — it exists so the table cannot be gutted silently.
      expect(foods.length, greaterThanOrEqualTo(80));
    });

    test('covers every category a recipe needs', () {
      final categories = foods.map((f) => f.category).toSet();
      for (final required in const [
        FoodCategory.protein,
        FoodCategory.dairy,
        FoodCategory.grain,
        FoodCategory.legume,
        FoodCategory.vegetable,
        FoodCategory.fruit,
        FoodCategory.nutSeed,
        FoodCategory.fat,
        FoodCategory.condiment,
      ]) {
        expect(categories, contains(required));
      }
    });

    test('carries enough vegan foods to build the required vegan recipes', () {
      final vegan = foods
          .where((f) => f.dietTags.contains(DietTag.vegan))
          .toList();
      expect(vegan.length, greaterThanOrEqualTo(40));
    });

    test('ships entirely as draft until a reviewer signs off', () {
      // Master prompt §18: nothing may claim professional review before it has
      // one. If this fails because content was promoted, that promotion must be
      // accompanied by a real reviewer credit in SAFETY_AND_EVIDENCE.md.
      expect(foods.every((f) => f.status == ContentStatus.draft), isTrue);
    });

    test('attributes every record', () {
      expect(foods.every((f) => f.source.isNotEmpty), isTrue);
    });

    test('tags allergens on the foods that carry them', () {
      // Spot-check the mapping rather than trusting the table wholesale — a
      // silently untagged allergen is the most dangerous failure in this file.
      Set<Allergen> allergensOf(String id) =>
          foods.firstWhere((f) => f.id == id).allergens;

      expect(allergensOf('egg-whole-raw'), contains(Allergen.eggs));
      expect(allergensOf('greek-yogurt-nonfat'), contains(Allergen.milk));
      expect(allergensOf('salmon-raw'), contains(Allergen.fish));
      expect(allergensOf('shrimp-raw'), contains(Allergen.shellfish));
      expect(allergensOf('almonds'), contains(Allergen.treeNuts));
      expect(allergensOf('peanut-butter'), contains(Allergen.peanuts));
      expect(allergensOf('tahini'), contains(Allergen.sesame));
      expect(allergensOf('wholemeal-bread'), contains(Allergen.gluten));
      expect(allergensOf('tofu-firm'), contains(Allergen.soy));
      expect(
        allergensOf('soy-sauce'),
        containsAll(<Allergen>[Allergen.soy, Allergen.gluten]),
      );
    });

    test('never tags a dairy or egg food as vegan', () {
      for (final food in foods) {
        if (food.allergens.contains(Allergen.milk) ||
            food.allergens.contains(Allergen.eggs)) {
          expect(
            food.dietTags.contains(DietTag.vegan),
            isFalse,
            reason: '${food.id} is tagged vegan but contains milk or eggs',
          );
        }
      }
    });

    test('never tags meat or fish as vegetarian', () {
      const animalIds = [
        'chicken-breast-raw',
        'chicken-thigh-raw',
        'turkey-breast-raw',
        'beef-mince-lean-raw',
        'beef-steak-lean-raw',
        'lamb-lean-raw',
        'salmon-raw',
        'cod-raw',
        'tuna-canned-water',
        'sardines-canned-oil',
        'shrimp-raw',
      ];
      for (final id in animalIds) {
        final food = foods.firstWhere((f) => f.id == id);
        expect(
          food.dietTags.contains(DietTag.vegetarian),
          isFalse,
          reason: '$id must not be tagged vegetarian',
        );
        expect(
          food.dietTags.contains(DietTag.vegan),
          isFalse,
          reason: '$id must not be tagged vegan',
        );
      }
    });

    test('every household unit weighs something', () {
      for (final food in foods) {
        for (final unit in food.householdUnits) {
          expect(unit.isValid, isTrue, reason: '${food.id}: $unit');
        }
      }
    });
  });
}
