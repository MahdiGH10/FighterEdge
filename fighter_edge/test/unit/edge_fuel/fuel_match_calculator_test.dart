import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_match_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_match.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

const _balanced = FoodItem(
  id: 'balanced',
  name: 'Chicken rice bowl',
  category: FoodCategory.protein,
  kcalPer100g: 500,
  proteinPer100g: 30,
  carbsPer100g: 60,
  fatPer100g: 10,
  fibrePer100g: 5,
);

const _dairy = FoodItem(
  id: 'dairy',
  name: 'Creamy pasta',
  category: FoodCategory.dairy,
  kcalPer100g: 500,
  proteinPer100g: 30,
  carbsPer100g: 60,
  fatPer100g: 10,
  fibrePer100g: 5,
  allergens: {Allergen.milk},
  dietTags: {DietTag.vegetarian},
);

const _vegan = FoodItem(
  id: 'vegan',
  name: 'Tofu rice bowl',
  category: FoodCategory.protein,
  kcalPer100g: 500,
  proteinPer100g: 30,
  carbsPer100g: 60,
  fatPer100g: 10,
  fibrePer100g: 5,
  dietTags: {
    DietTag.vegan,
    DietTag.vegetarian,
    DietTag.pescatarian,
    DietTag.halal,
  },
);

const _foods = <String, FoodItem>{
  'balanced': _balanced,
  'dairy': _dairy,
  'vegan': _vegan,
};

NutritionTarget _target({int calories = 1000}) => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: calories,
      proteinGrams: 60,
      carbGrams: 120,
      fatGrams: 20,
    );

Recipe _recipe(
  String id,
  String foodId, {
  String? title,
  int minutes = 10,
  CostBand costBand = CostBand.low,
}) =>
    Recipe(
      id: id,
      title: title ?? id,
      description: 'Catalog fixture',
      servings: 1,
      ingredients: [RecipeIngredient(foodId: foodId, grams: 100)],
      steps: const ['Cook it.'],
      mealType: MealType.dinner,
      prepMinutes: minutes,
      costBand: costBand,
    );

NutritionDay _day({
  int calories = 0,
  int protein = 0,
  int carbs = 0,
  int fats = 0,
}) {
  final entry = FoodLogEntry(
    id: 'logged',
    name: 'Logged',
    notes: '',
    calories: calories,
    proteinGrams: protein,
    carbGrams: carbs,
    fatGrams: fats,
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

void main() {
  test('selects a catalog-backed portion for the exact remaining target', () {
    final match = FuelMatchCalculator.calculate(
      target: _target(),
      day: _day(),
      recipes: [_recipe('balanced', _balanced.id)],
      foodsById: _foods,
    );

    expect(match.status, FuelMatchStatus.ready);
    expect(match.options, hasLength(1));
    expect(match.options.single.recipe.id, 'balanced');
    expect(match.options.single.servings, 2);
    expect(match.options.single.nutrients.kcalRounded, 1000);
    expect(match.options.single.nutrients.proteinRounded, 60);
    expect(match.options.single.nutrients.carbsRounded, 120);
    expect(match.options.single.nutrients.fatRounded, 20);
  });

  test('excludes tracked allergens before ranking any match', () {
    final match = FuelMatchCalculator.calculate(
      target: _target(),
      day: _day(),
      recipes: [
        _recipe('creamy', _dairy.id),
        _recipe('balanced', _balanced.id),
      ],
      foodsById: _foods,
      preferences: const NutritionSetupDraft(allergens: ['milk']),
    );

    expect(match.status, FuelMatchStatus.ready);
    expect(match.options.map((option) => option.recipe.id),
        isNot(contains('creamy')));
  });

  test('uses diet, time, budget and explicit dislikes as hard preferences', () {
    final match = FuelMatchCalculator.calculate(
      target: _target(),
      day: _day(),
      recipes: [
        _recipe('meat', _balanced.id),
        _recipe('slow vegan', _vegan.id, minutes: 35),
        _recipe('expensive vegan', _vegan.id, costBand: CostBand.high),
        _recipe('tofu vegan', _vegan.id),
      ],
      foodsById: _foods,
      preferences: const NutritionSetupDraft(
        dietType: 'vegan',
        cookingTimeBand: 'quick',
        budgetBand: 'low',
      ),
    );

    expect(match.status, FuelMatchStatus.ready);
    expect(match.options.map((option) => option.recipe.id), ['tofu vegan']);
  });

  test('does not claim unmatched allergy terms are filtered', () {
    final match = FuelMatchCalculator.calculate(
      target: _target(),
      day: _day(),
      recipes: [_recipe('balanced', _balanced.id)],
      foodsById: _foods,
      preferences: const NutritionSetupDraft(allergens: ['kiwi']),
    );

    expect(match.status, FuelMatchStatus.ready);
    expect(match.unmatchedAllergenTerms, ['kiwi']);
  });

  test('does not suggest a full meal when very little calorie budget remains',
      () {
    final match = FuelMatchCalculator.calculate(
      target: _target(),
      day: _day(calories: 900, protein: 55, carbs: 110, fats: 18),
      recipes: [_recipe('balanced', _balanced.id)],
      foodsById: _foods,
    );

    expect(match.status, FuelMatchStatus.noMealNeeded);
    expect(match.options, isEmpty);
    expect(match.caloriesRemaining, 100);
  });

  test('needs a complete trusted target before it can rank recipes', () {
    final match = FuelMatchCalculator.calculate(
      target: null,
      day: _day(),
      recipes: [_recipe('balanced', _balanced.id)],
      foodsById: _foods,
    );

    expect(match.status, FuelMatchStatus.needsMoreData);
  });
}
