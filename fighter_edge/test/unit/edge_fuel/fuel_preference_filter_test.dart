import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_preference_filter.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_add_on.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/recipe.dart';
import 'package:flutter_test/flutter_test.dart';

const _peanut = FoodItem(
  id: 'pb',
  name: 'Peanut butter, smooth',
  category: FoodCategory.fat,
  kcalPer100g: 590,
  proteinPer100g: 25,
  carbsPer100g: 20,
  fatPer100g: 50,
  fibrePer100g: 6,
  allergens: {Allergen.peanuts},
  dietTags: {DietTag.vegan, DietTag.vegetarian},
);

const _addOn = FuelAddOn(
  id: 'pb-2-tbsp',
  foodId: 'pb',
  group: AddOnGroup.nutSeed,
  grams: 32,
  unit: AddOnUnit.tablespoon,
  unitCount: 2,
  source: FuelAddOn.sourceUsdaHousehold,
  prepMinutes: 20,
);

final _recipe = Recipe(
  id: 'toast',
  title: 'Toast with spread',
  description: 'Crunchy',
  servings: 1,
  ingredients: const [RecipeIngredient(foodId: 'pb', grams: 32)],
  steps: const ['Spread it.'],
  mealType: MealType.breakfast,
  prepMinutes: 5,
  costBand: CostBand.medium,
);

FuelPreferenceFilter _filter(NutritionSetupDraft? draft) =>
    FuelPreferenceFilter.from(draft);

void main() {
  test('no preferences allow everything', () {
    final f = _filter(null);
    expect(f.blockedAllergens, isEmpty);
    expect(f.diet, isNull);
    expect(f.budget, isNull);
    expect(f.maximumMinutes, isNull);
    expect(f.allowsAddOn(_addOn, _peanut), isTrue);
    expect(
      f.allowsRecipe(
        _recipe,
        const {'pb': _peanut},
        allergens: _peanut.allergens,
        dietTags: _peanut.dietTags,
      ),
      isTrue,
    );
  });

  test('maps diet, budget and cooking time', () {
    expect(_filter(const NutritionSetupDraft(dietType: 'vegan')).diet,
        DietTag.vegan);
    expect(_filter(const NutritionSetupDraft(dietType: 'vegetarian')).diet,
        DietTag.vegetarian);
    expect(_filter(const NutritionSetupDraft(dietType: 'pescatarian')).diet,
        DietTag.pescatarian);
    expect(_filter(const NutritionSetupDraft(dietType: ' halal ')).diet,
        DietTag.halal);
    expect(_filter(const NutritionSetupDraft(dietType: 'keto')).diet, isNull);
    expect(_filter(const NutritionSetupDraft(budgetBand: 'low')).budget,
        CostBand.low);
    expect(_filter(const NutritionSetupDraft(budgetBand: 'medium')).budget,
        CostBand.medium);
    expect(_filter(const NutritionSetupDraft(budgetBand: 'high')).budget,
        CostBand.high);
    expect(
        _filter(const NutritionSetupDraft(budgetBand: 'any')).budget, isNull);
    expect(
      _filter(const NutritionSetupDraft(cookingTimeBand: 'quick'))
          .maximumMinutes,
      15,
    );
    expect(
      _filter(const NutritionSetupDraft(cookingTimeBand: 'moderate'))
          .maximumMinutes,
      30,
    );
    expect(
      _filter(const NutritionSetupDraft(cookingTimeBand: 'slow'))
          .maximumMinutes,
      isNull,
    );
  });

  test('an allergy blocks the add-on and the recipe', () {
    final f = _filter(const NutritionSetupDraft(allergens: ['peanut']));
    expect(f.blockedAllergens, contains(Allergen.peanuts));
    expect(f.allowsAddOn(_addOn, _peanut), isFalse);
    expect(
      f.allowsRecipe(
        _recipe,
        const {'pb': _peanut},
        allergens: _peanut.allergens,
        dietTags: _peanut.dietTags,
      ),
      isFalse,
    );
  });

  test('keeps unmatched allergy terms', () {
    expect(
      _filter(const NutritionSetupDraft(allergens: ['kiwi']))
          .unmatchedAllergenTerms,
      ['kiwi'],
    );
  });

  test('diet, time, budget and dislikes are hard exclusions', () {
    final halal = _filter(const NutritionSetupDraft(dietType: 'halal'));
    expect(halal.allowsAddOn(_addOn, _peanut), isFalse);
    final quick = _filter(const NutritionSetupDraft(cookingTimeBand: 'quick'));
    expect(quick.allowsAddOn(_addOn, _peanut), isFalse);
    expect(
      quick.allowsRecipe(
        _recipe,
        const {'pb': _peanut},
        allergens: const {},
        dietTags: const {},
      ),
      isTrue,
    );
    final cheap = _filter(const NutritionSetupDraft(budgetBand: 'low'));
    expect(
      cheap.allowsRecipe(
        _recipe,
        const {'pb': _peanut},
        allergens: const {},
        dietTags: const {},
      ),
      isFalse,
    );
    final dislikes =
        _filter(const NutritionSetupDraft(dislikedFoods: ['PEANUT butter']));
    expect(dislikes.allowsAddOn(_addOn, _peanut), isFalse);
    expect(
      dislikes.allowsRecipe(
        _recipe,
        const {'pb': _peanut},
        allergens: const {},
        dietTags: const {},
      ),
      isFalse,
    );
    final crunchy =
        _filter(const NutritionSetupDraft(dislikedFoods: ['crunchy', ' ']));
    expect(crunchy.disliked, {'crunchy'});
    expect(
      crunchy.allowsRecipe(
        _recipe,
        const {},
        allergens: const {},
        dietTags: const {},
      ),
      isFalse,
    );
    expect(crunchy.allowsAddOn(_addOn, _peanut), isTrue);
  });
}
