import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_gap_picker.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_match_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_add_on.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_gap.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/recipe.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/fuel_add_on_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

const _allDiets = {
  DietTag.vegan,
  DietTag.vegetarian,
  DietTag.pescatarian,
  DietTag.halal,
};

FoodItem _food(
  String id, {
  required double kcal,
  required double protein,
  double carbs = 0,
  double fat = 0,
  Set<Allergen> allergens = const {},
  Set<DietTag> diets = const {},
  String? name,
}) =>
    FoodItem(
      id: id,
      name: name ?? id,
      category: FoodCategory.other,
      kcalPer100g: kcal,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      fibrePer100g: 0,
      allergens: allergens,
      dietTags: diets,
    );

final _foods = <String, FoodItem>{
  for (final f in [
    _food('yogurt',
        kcal: 60,
        protein: 10,
        carbs: 4,
        fat: 0.4,
        allergens: {Allergen.milk},
        diets: {DietTag.vegetarian, DietTag.halal}),
    _food('chicken', kcal: 110, protein: 23, fat: 2, diets: {DietTag.halal}),
    _food('tuna',
        kcal: 100,
        protein: 24,
        fat: 1,
        allergens: {Allergen.fish},
        diets: {DietTag.pescatarian, DietTag.halal}),
    _food('tofu',
        kcal: 145,
        protein: 15,
        carbs: 3,
        fat: 9,
        allergens: {Allergen.soy},
        diets: _allDiets),
    _food('rice',
        kcal: 130, protein: 2.7, carbs: 28, fat: 0.3, diets: _allDiets),
    _food('banana',
        kcal: 89, protein: 1.1, carbs: 23, fat: 0.3, diets: _allDiets),
    _food('whey',
        kcal: 370,
        protein: 90,
        carbs: 1,
        fat: 1,
        allergens: {Allergen.milk},
        diets: {DietTag.vegetarian}),
  ])
    f.id: f,
};

FuelAddOn _addOn(
  String id,
  String foodId,
  AddOnGroup group,
  double grams, {
  int prep = 0,
}) =>
    FuelAddOn(
      id: id,
      foodId: foodId,
      group: group,
      grams: grams,
      unit: AddOnUnit.gram,
      unitCount: grams,
      source: FuelAddOn.sourceCurated,
      prepMinutes: prep,
    );

final _addOns = [
  _addOn('yogurt-200', 'yogurt', AddOnGroup.dairy, 200),
  _addOn('yogurt-100', 'yogurt', AddOnGroup.dairy, 100),
  _addOn('chicken-150', 'chicken', AddOnGroup.meat, 150, prep: 20),
  _addOn('tuna-120', 'tuna', AddOnGroup.fish, 120),
  _addOn('tofu-150', 'tofu', AddOnGroup.plantProtein, 150),
  _addOn('rice-180', 'rice', AddOnGroup.grain, 180),
  _addOn('banana-118', 'banana', AddOnGroup.fruit, 118),
  _addOn('whey-30', 'whey', AddOnGroup.supplement, 30),
  _addOn('ghost', 'not-in-catalog', AddOnGroup.meat, 100),
];

FuelGapPick _pick({
  FuelGapMacro macro = FuelGapMacro.protein,
  int gramsLeft = 34,
  int? kcalLeft,
  double? weightKg = 90,
  FuelDayType? dayType,
  NutritionSetupDraft? preferences,
  List<FuelAddOn>? addOns,
  Map<String, FoodItem>? foods,
  List<Recipe> recipes = const [],
}) =>
    FuelGapPicker.pick(
      macro: macro,
      gramsLeft: gramsLeft,
      kcalLeft: kcalLeft,
      weightKg: weightKg,
      dayType: dayType,
      addOns: addOns ?? _addOns,
      foodsById: foods ?? _foods,
      recipes: recipes,
      preferences: preferences,
    );

List<String> _ids(FuelGapPick pick) => [for (final o in pick.options) o.id];

Recipe _recipe(String id, String foodId, {double grams = 100}) => Recipe(
      id: id,
      title: id,
      description: 'Fixture',
      servings: 1,
      ingredients: [RecipeIngredient(foodId: foodId, grams: grams)],
      steps: const ['Cook it.'],
      mealType: MealType.lunch,
      prepMinutes: 10,
    );

Future<Map<String, FoodItem>> _realFoods() async {
  final json = jsonDecode(
    await File('assets/data/edge_fuel_foods_v1.json').readAsString(),
  ) as Map<String, dynamic>;
  return {
    for (final raw in (json['foods'] as List).cast<Map<String, dynamic>>())
      raw['id'] as String: FoodItem.fromJson(raw),
  };
}

void main() {
  group('gap picker', () {
    test('"Protein left: 34 g" gives three options from three groups', () {
      final pick = _pick();
      expect(pick.status, FuelGapStatus.ready);
      expect(pick.isReady, isTrue);
      expect(pick.macro, FuelGapMacro.protein);
      expect(pick.gramsLeft, 34);
      expect(pick.split, isNull);
      expect(_ids(pick), ['chicken-150', 'tuna-120', 'whey-30']);
      expect(pick.options.map((o) => o.group).toSet(), hasLength(3));

      final chicken = pick.options.first;
      expect(chicken.isRecipe, isFalse);
      expect(chicken.food!.id, 'chicken');
      expect(chicken.servings, 1);
      expect(chicken.reason.code, FuelGapReasonCode.closesGap);
      expect(chicken.reason.addsGrams, 35);
      expect(chicken.reason.kcal, 165);
      expect(chicken.reason.leavesGrams, 0);

      final tuna = pick.options[1];
      expect(tuna.reason.code, FuelGapReasonCode.addsPart);
      expect(tuna.reason.addsGrams, 29);
      expect(tuna.reason.leavesGrams, 5);
      expect(tuna.allergens, {Allergen.fish});
    });

    test('skips options that add too little of the macro', () {
      final pick = _pick();
      expect(_ids(pick), isNot(contains('rice-180')));
      expect(_ids(pick), isNot(contains('banana-118')));
      for (final o in pick.options) {
        expect(o.nutrients.proteinGrams, greaterThanOrEqualTo(34 * .25));
      }
    });

    test('keeps one option per food group', () {
      final pick = _pick(
        addOns: [
          _addOn('yogurt-200', 'yogurt', AddOnGroup.dairy, 200),
          _addOn('yogurt-100', 'yogurt', AddOnGroup.dairy, 100),
        ],
      );
      expect(_ids(pick), ['yogurt-200']);
    });

    test('fits inside the calories left, with 10% room', () {
      final pick = _pick(kcalLeft: 140);
      expect(pick.kcalLeft, 140);
      expect(_ids(pick), ['tuna-120', 'whey-30', 'yogurt-200']);
      for (final o in pick.options) {
        expect(o.nutrients.kcal, lessThanOrEqualTo(140 * 1.1));
      }
    });

    test('applies diet, allergy, time and dislike filters', () {
      expect(
        _ids(_pick(preferences: const NutritionSetupDraft(dietType: 'vegan'))),
        ['tofu-150'],
      );
      final noMilk =
          _pick(preferences: const NutritionSetupDraft(allergens: ['milk']));
      expect(_ids(noMilk), isNot(contains('whey-30')));
      expect(_ids(noMilk), isNot(contains('yogurt-200')));
      expect(
        _ids(_pick(
          preferences: const NutritionSetupDraft(cookingTimeBand: 'quick'),
        )),
        isNot(contains('chicken-150')),
      );
      expect(
        _ids(_pick(
          preferences: const NutritionSetupDraft(dislikedFoods: ['Tuna']),
        )),
        isNot(contains('tuna-120')),
      );
    });

    test('passes unmatched allergy terms through so the UI never says safe',
        () {
      final pick =
          _pick(preferences: const NutritionSetupDraft(allergens: ['kiwi']));
      expect(pick.unmatchedAllergenTerms, ['kiwi']);
    });

    test('says when nothing fits', () {
      final pick = _pick(
        preferences: const NutritionSetupDraft(dietType: 'vegan'),
        kcalLeft: 50,
      );
      expect(pick.status, FuelGapStatus.noMatch);
      expect(pick.options, isEmpty);
    });

    test('a small gap needs nothing, a negative one needs data', () {
      final closed = _pick(gramsLeft: 4, kcalLeft: 300);
      expect(closed.status, FuelGapStatus.gapClosed);
      expect(closed.gramsLeft, 4);
      expect(closed.kcalLeft, 300);
      expect(closed.options, isEmpty);
      expect(_pick(gramsLeft: -1).status, FuelGapStatus.needsMoreData);
      expect(_pick(kcalLeft: -1).status, FuelGapStatus.needsMoreData);
    });

    test('is deterministic', () {
      expect(_ids(_pick()), _ids(_pick()));
      expect(
        _ids(_pick(addOns: _addOns.reversed.toList())),
        _ids(_pick()),
      );
    });
  });

  group('split above 0.4 g/kg a meal', () {
    test('splits a large protein gap and sizes options for one meal', () {
      final pick = _pick(gramsLeft: 80, weightKg: 70);
      final split = pick.split!;
      expect(split.perMealCapGrams, 28);
      expect(split.parts, 3);
      expect(split.gramsPerPart, 27);
      expect(_ids(pick).first, 'whey-30');
      final whey = pick.options.first.reason;
      expect(whey.code, FuelGapReasonCode.coversOneMeal);
      expect(whey.addsGrams, 27);
      expect(whey.leavesGrams, 53);
    });

    test('shares the calories left between the meals', () {
      // 310 kcal over 3 meals is about 114 each with the 10% room: whey
      // (111 kcal) and the small yogurt fit, tuna (120 kcal) does not.
      final pick = _pick(gramsLeft: 80, weightKg: 70, kcalLeft: 310);
      expect(_ids(pick), ['whey-30', 'yogurt-100']);
    });

    test('caps at three meals of one dose each', () {
      final split = FuelGapPicker.splitFor(200, 70)!;
      expect(split.parts, 3);
      expect(split.gramsPerPart, 28);
    });

    test('uses 40 g a meal when the weight is unknown', () {
      expect(FuelGapPicker.perMealProteinCap(null), 40);
      expect(FuelGapPicker.perMealProteinCap(double.nan), 40);
      expect(FuelGapPicker.perMealProteinCap(0), 40);
      expect(FuelGapPicker.splitFor(40, null), isNull);
      final split = FuelGapPicker.splitFor(60, null)!;
      expect(split.parts, 2);
      expect(split.gramsPerPart, 30);
    });

    test('does not split a gap one meal covers', () {
      expect(FuelGapPicker.splitFor(36, 90), isNull);
      expect(FuelGapPicker.splitFor(37, 90), isNotNull);
    });

    test('never splits a carbohydrate gap', () {
      final pick = _pick(macro: FuelGapMacro.carbohydrate, gramsLeft: 300);
      expect(pick.split, isNull);
    });
  });

  group('carbohydrate gap', () {
    test('ranks by carbohydrate', () {
      final pick = _pick(macro: FuelGapMacro.carbohydrate, gramsLeft: 60);
      expect(pick.macro, FuelGapMacro.carbohydrate);
      expect(_ids(pick), ['rice-180', 'banana-118']);
      expect(pick.options.first.reason.macro, FuelGapMacro.carbohydrate);
      expect(pick.options.first.reason.addsGrams, 50);
      expect(pick.options.first.reason.leavesGrams, 10);
    });
  });

  group('day type tie-break', () {
    final foods = {
      'fatty': _food('fatty', kcal: 200, protein: 20, fat: 13.3),
      'starchy': _food('starchy', kcal: 200, protein: 20, carbs: 20, fat: 4.4),
    };
    final addOns = [
      _addOn('a-fatty', 'fatty', AddOnGroup.nutSeed, 100),
      _addOn('b-starchy', 'starchy', AddOnGroup.grain, 100),
    ];

    test('on a rest day equal options fall back to calories and id', () {
      final pick = _pick(
        foods: foods,
        addOns: addOns,
        dayType: FuelDayType.rest,
      );
      expect(pick.dayType, FuelDayType.rest);
      expect(_ids(pick), ['a-fatty', 'b-starchy']);
    });

    test('on hard and double days the carbohydrate-richer option leads', () {
      for (final type in [FuelDayType.hard, FuelDayType.doubleDay]) {
        final pick = _pick(foods: foods, addOns: addOns, dayType: type);
        expect(_ids(pick), ['b-starchy', 'a-fatty'], reason: type.name);
      }
    });
  });

  group('recipes in the pool', () {
    test('a recipe portion counts as the meal group', () {
      final pick = _pick(
        addOns: const [],
        recipes: [_recipe('chicken-bowl', 'chicken', grams: 150)],
      );
      final option = pick.options.single;
      expect(option.isRecipe, isTrue);
      expect(option.id, 'chicken-bowl');
      expect(option.group, AddOnGroup.meal);
      expect(option.servings, 1);
      expect(option.addOn, isNull);
    });

    test('filters recipes the same way', () {
      final pick = _pick(
        addOns: const [],
        recipes: [_recipe('tuna-bowl', 'tuna', grams: 150)],
        preferences: const NutritionSetupDraft(allergens: ['fish']),
      );
      expect(pick.status, FuelGapStatus.noMatch);
    });

    test('drops a recipe with no portion inside the calories left', () {
      final pick = _pick(
        addOns: const [],
        recipes: [_recipe('rice-bowl', 'rice', grams: 400)],
        macro: FuelGapMacro.carbohydrate,
        gramsLeft: 60,
        kcalLeft: 100,
      );
      expect(pick.status, FuelGapStatus.noMatch);
    });
  });

  group('FuelMatchCalculator.gap', () {
    NutritionTarget target() => NutritionTarget(
          status: NutritionTargetStatus.success,
          policyVersion: 2,
          calculatedAt: DateTime(2026, 1, 1),
          targetCalories: 2400,
          proteinGrams: 160,
          carbGrams: 280,
          fatGrams: 70,
        );

    NutritionDay day({int kcal = 2100, int protein = 126, int carbs = 250}) {
      final entry = FoodLogEntry(
        id: 'logged',
        name: 'Logged',
        notes: '',
        calories: kcal,
        proteinGrams: protein,
        carbGrams: carbs,
        fatGrams: 60,
        loggedAt: DateTime(2026, 1, 1),
      );
      return NutritionDay(
        localDate: '2026-01-01',
        timeZone: 'UTC',
        entries: [entry],
        totals: FoodLogTotals.fromEntries([entry]),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
    }

    test('works out what is left from the target and the log', () {
      final pick = FuelMatchCalculator.gap(
        target: target(),
        day: day(),
        foodsById: _foods,
        addOns: _addOns,
        weightKg: 90,
      );
      expect(pick.gramsLeft, 34);
      expect(pick.kcalLeft, 300);
      expect(pick.options, hasLength(3));
    });

    test('can close a carbohydrate gap', () {
      final pick = FuelMatchCalculator.gap(
        target: target(),
        day: day(carbs: 220),
        foodsById: _foods,
        addOns: _addOns,
        macro: FuelGapMacro.carbohydrate,
      );
      expect(pick.gramsLeft, 60);
      expect(pick.macro, FuelGapMacro.carbohydrate);
    });

    test('needs a usable target', () {
      final pick = FuelMatchCalculator.gap(
        target: null,
        day: day(),
        foodsById: _foods,
      );
      expect(pick.status, FuelGapStatus.needsMoreData);
    });
  });

  group('with the real add-on catalog and food table', () {
    late Map<String, FoodItem> foods;

    setUpAll(() async {
      foods = await _realFoods();
    });

    test('gives three protein options from three groups', () {
      final pick = FuelGapPicker.pick(
        macro: FuelGapMacro.protein,
        gramsLeft: 34,
        kcalLeft: 600,
        weightKg: 90,
        addOns: FuelAddOnCatalog.all,
        foodsById: foods,
      );
      expect(pick.status, FuelGapStatus.ready);
      expect(pick.options, hasLength(3));
      expect(pick.options.map((o) => o.group).toSet(), hasLength(3));
      for (final o in pick.options) {
        expect(o.nutrients.proteinGrams, greaterThanOrEqualTo(8.5));
        expect(o.nutrients.kcal, lessThanOrEqualTo(660));
      }
    });

    test('respects vegan and milk-free filters', () {
      final vegan = FuelGapPicker.pick(
        macro: FuelGapMacro.protein,
        gramsLeft: 30,
        addOns: FuelAddOnCatalog.all,
        foodsById: foods,
        preferences: const NutritionSetupDraft(dietType: 'vegan'),
      );
      expect(vegan.options, isNotEmpty);
      for (final o in vegan.options) {
        expect(o.dietTags, contains(DietTag.vegan), reason: o.id);
      }
      final noMilk = FuelGapPicker.pick(
        macro: FuelGapMacro.protein,
        gramsLeft: 30,
        addOns: FuelAddOnCatalog.all,
        foodsById: foods,
        preferences: const NutritionSetupDraft(allergens: ['milk']),
      );
      expect(noMilk.options, isNotEmpty);
      for (final o in noMilk.options) {
        expect(o.allergens, isNot(contains(Allergen.milk)), reason: o.id);
      }
    });

    test('gives carbohydrate options for a hard day', () {
      final pick = FuelGapPicker.pick(
        macro: FuelGapMacro.carbohydrate,
        gramsLeft: 80,
        dayType: FuelDayType.hard,
        addOns: FuelAddOnCatalog.all,
        foodsById: foods,
      );
      expect(pick.options, hasLength(3));
    });
  });

  test('no reason code or group name labels a food', () {
    const banned = {
      'good', 'bad', 'cheat', 'earn', 'junk', 'clean', 'healthy', //
      'unhealthy', 'treat', 'guilt', 'over', 'burn', 'avoid',
    };
    for (final name in [
      ...FuelGapReasonCode.values.map((v) => v.name),
      ...AddOnGroup.values.map((v) => v.name),
      ...FuelGapStatus.values.map((v) => v.name),
    ]) {
      final words =
          name.split(RegExp(r'(?=[A-Z])')).map((w) => w.toLowerCase()).toSet();
      expect(words.intersection(banned), isEmpty, reason: name);
    }
  });
}
