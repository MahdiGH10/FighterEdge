import '../models/food_item.dart';
import '../models/fuel_add_on.dart';
import '../models/fuel_day_plan.dart';
import '../models/fuel_gap.dart';
import '../models/fuel_day_gap.dart';
import '../models/accepted_fuel_week.dart';
import '../models/fuel_match.dart';
import '../models/nutrition_day.dart';
import '../models/nutrition_setup_draft.dart';
import '../models/nutrition_target.dart';
import '../models/recipe.dart';
import '../policies/fuel_add_on_catalog.dart';
import '../policies/fuel_day_policy.dart';
import '../policies/nutrition_policy.dart';
import '../policies/recipe_publication_gate.dart';
import 'fuel_gap_picker.dart';
import 'fuel_preference_filter.dart';
import 'recipe_nutrient_calculator.dart';

/// How [FuelMatchCalculator.calculate] ranks recipe portions.
enum FuelMatchMode {
  /// The original ranking: the calories left lead (kcal 0.48, protein 0.30,
  /// carbs 0.16, fat 0.06).
  calorieFirst,

  /// Protein leads (protein 0.48, kcal 0.30, carbs 0.14, fat 0.08), for
  /// "Protein left" moments.
  macroFirst,
}

/// Finds useful portions from the curated recipe catalog for the athlete's
/// remaining daily nutrition target.
///
/// This is a pure, deterministic ranking engine. It does not call an AI
/// provider, make medical claims, or write to a log. The result is therefore
/// fast, testable, works offline once the catalog is available, and can safely
/// be used as the factual basis for an AI explanation later.
class FuelMatchCalculator {
  FuelMatchCalculator._();

  static const int minimumUsefulCalories = FuelGapPicker.minimumUsefulCalories;
  static const int maxOptions = 3;
  static const List<double> _portionOptions = [0.5, 1, 1.5, 2, 2.5];

  static const Map<FuelMatchMode, _Weights> _weights = {
    FuelMatchMode.calorieFirst:
        _Weights(kcal: .48, protein: .30, carbs: .16, fat: .06),
    FuelMatchMode.macroFirst:
        _Weights(kcal: .30, protein: .48, carbs: .14, fat: .08),
  };

  /// UI entry point for day suggestions. Unknown/minor age and unreviewed
  /// catalog portions/dose assumptions return no amounts or options.
  /// [reviewedAmountsEnabled] must come from a recorded reviewed-build flag,
  /// never billing or a user toggle. Existing pending flags remain unchanged.
  /// [allocatedDay] uses the accepted-week adapter's view numbers without
  /// making a new persisted target. A log from another date is refused.
  static FuelDayGap dayGap({
    required NutritionTarget? target,
    required NutritionDay? day,
    required Map<String, FoodItem> foodsById,
    required int? ageYears,
    AcceptedFuelDay? allocatedDay,
    double? weightKg,
    FuelDayType? dayType,
    Iterable<FuelAddOn> addOns = FuelAddOnCatalog.all,
    NutritionSetupDraft? preferences,
    bool reviewedAmountsEnabled = FuelDayPolicy.amountsEnabledByDefault &&
        !FuelAddOnCatalog.dietitianSignOffPending,
  }) {
    if (ageYears == null || ageYears < NutritionPolicy.minimumAgeYears) {
      return const FuelDayGap.blocked(FuelGapStatus.adultRequired);
    }
    if (!reviewedAmountsEnabled) {
      return const FuelDayGap.blocked(FuelGapStatus.awaitingSignOff);
    }
    final logDate = day == null ? null : DateTime.tryParse(day.localDate);
    if (allocatedDay != null &&
        day != null &&
        (logDate == null ||
            !FuelCalendar.sameDay(logDate, allocatedDay.plan.date))) {
      return const FuelDayGap.blocked(FuelGapStatus.needsMoreData);
    }
    final remaining = _Remaining.from(target, day, allocatedDay: allocatedDay);
    if (ageYears > 120 || remaining == null) {
      return const FuelDayGap.blocked(FuelGapStatus.needsMoreData);
    }
    if (remaining.protein >= FuelGapPicker.minimumGapGrams) {
      return FuelDayGap.protein(FuelGapPicker.pick(
        macro: FuelGapMacro.protein,
        gramsLeft: remaining.protein,
        kcalLeft: remaining.calories,
        foodsById: foodsById,
        addOns: addOns,
        weightKg: weightKg,
        dayType: allocatedDay?.plan.type ?? dayType,
        preferences: preferences,
      ));
    }
    return FuelDayGap.calories(FuelGapPicker.pickCalories(
      kcalLeft: remaining.calories,
      addOns: addOns,
      foodsById: foodsById,
      preferences: preferences,
    ));
  }

  /// The macro-first gap picker against today's target and log: "Protein
  /// left: 34 g, 3 options". See [FuelGapPicker] for the rules. [addOns]
  /// defaults to the curated catalog.
  /// Low-level: presentation code uses [dayGap] for age/review gating.
  static FuelGapPick gap({
    required NutritionTarget? target,
    required NutritionDay? day,
    required Map<String, FoodItem> foodsById,
    FuelGapMacro macro = FuelGapMacro.protein,
    double? weightKg,
    FuelDayType? dayType,
    Iterable<FuelAddOn> addOns = FuelAddOnCatalog.all,
    Iterable<Recipe> recipes = const [],
    NutritionSetupDraft? preferences,
  }) {
    final remaining = _Remaining.from(target, day);
    if (remaining == null) {
      return FuelGapPick(status: FuelGapStatus.needsMoreData, macro: macro);
    }
    return FuelGapPicker.pick(
      macro: macro,
      gramsLeft: switch (macro) {
        FuelGapMacro.protein => remaining.protein,
        FuelGapMacro.carbohydrate => remaining.carbohydrates,
      },
      kcalLeft: remaining.calories,
      weightKg: weightKg,
      dayType: dayType,
      addOns: addOns,
      foodsById: foodsById,
      recipes: recipes,
      preferences: preferences,
    );
  }

  static FuelMatch calculate({
    required NutritionTarget? target,
    required NutritionDay? day,
    required Iterable<Recipe> recipes,
    required Map<String, FoodItem> foodsById,
    NutritionSetupDraft? preferences,
    FuelMatchMode mode = FuelMatchMode.calorieFirst,
  }) {
    final remaining = _Remaining.from(target, day);
    if (remaining == null) {
      return const FuelMatch(status: FuelMatchStatus.needsMoreData);
    }
    if (remaining.calories < minimumUsefulCalories) {
      return FuelMatch(
        status: FuelMatchStatus.noMealNeeded,
        caloriesRemaining: remaining.calories,
        proteinRemaining: remaining.protein,
        carbohydratesRemaining: remaining.carbohydrates,
        fatsRemaining: remaining.fats,
      );
    }

    final filter = FuelPreferenceFilter.from(preferences);
    final candidates = <_Candidate>[];

    for (final recipe in RecipePublicationGate.visible(recipes)) {
      final allergens = RecipeNutrientCalculator.allergensOf(recipe, foodsById);
      final diets = RecipeNutrientCalculator.dietTagsOf(recipe, foodsById);
      if (!filter.allowsRecipe(
        recipe,
        foodsById,
        allergens: allergens,
        dietTags: diets,
      )) {
        continue;
      }

      final perServing = RecipeNutrientCalculator.perServing(recipe, foodsById);
      if (perServing.kcal <= 0) continue;

      _Candidate? bestForRecipe;
      for (final servings in _portionOptions) {
        final nutrients = perServing.scaled(servings);
        final score = _score(nutrients, remaining, mode);
        final candidate = _Candidate(
          option: FuelMatchOption(
            recipe: recipe,
            nutrients: nutrients,
            servings: servings,
            allergens: allergens,
            dietTags: diets,
            caloriesRemaining: remaining.calories,
          ),
          score: score,
        );
        if (bestForRecipe == null || candidate.isBetterThan(bestForRecipe)) {
          bestForRecipe = candidate;
        }
      }
      if (bestForRecipe != null) candidates.add(bestForRecipe);
    }

    candidates.sort((a, b) => a.compareTo(b));
    final options = candidates
        .take(maxOptions)
        .map((candidate) => candidate.option)
        .toList(growable: false);

    return FuelMatch(
      status: options.isEmpty ? FuelMatchStatus.noMatch : FuelMatchStatus.ready,
      caloriesRemaining: remaining.calories,
      proteinRemaining: remaining.protein,
      carbohydratesRemaining: remaining.carbohydrates,
      fatsRemaining: remaining.fats,
      options: options,
      unmatchedAllergenTerms: filter.unmatchedAllergenTerms,
    );
  }

  static double _score(
    RecipeNutrients nutrients,
    _Remaining remaining,
    FuelMatchMode mode,
  ) {
    // Calorie-first: calories give the principal fit. Macro-first: protein
    // does. Macros are weighted by their actual remaining gap, so a macro
    // already met cannot distort the ranking.
    final w = _weights[mode]!;
    final calorieFit = _coverage(nutrients.kcal, remaining.calories);
    final proteinFit = _coverage(nutrients.proteinGrams, remaining.protein);
    final carbFit = _coverage(nutrients.carbGrams, remaining.carbohydrates);
    final fatFit = _coverage(nutrients.fatGrams, remaining.fats);
    final overshoot = nutrients.kcal > remaining.calories * 1.12
        ? (nutrients.kcal - remaining.calories * 1.12) / remaining.calories
        : 0.0;
    return calorieFit * w.kcal +
        proteinFit * w.protein +
        carbFit * w.carbs +
        fatFit * w.fat -
        overshoot * .25;
  }

  static double _coverage(double value, int remaining) {
    if (remaining <= 0) return 1;
    return (value / remaining).clamp(0, 1);
  }
}

class _Remaining {
  final int calories;
  final int protein;
  final int carbohydrates;
  final int fats;

  const _Remaining({
    required this.calories,
    required this.protein,
    required this.carbohydrates,
    required this.fats,
  });

  static _Remaining? from(NutritionTarget? target, NutritionDay? day,
      {AcceptedFuelDay? allocatedDay}) {
    if (target?.isSuccess != true) return null;
    final calories = allocatedDay?.calories ?? target!.targetCalories;
    final protein = allocatedDay?.proteinGrams ?? target!.proteinGrams;
    final carbs = allocatedDay?.carbGrams ?? target!.carbGrams;
    final fats = allocatedDay?.fatGrams ?? target!.fatGrams;
    if (calories == null ||
        protein == null ||
        carbs == null ||
        fats == null ||
        calories <= 0 ||
        protein <= 0 ||
        carbs <= 0 ||
        fats <= 0) {
      return null;
    }
    final totals = day?.totals;
    return _Remaining(
      calories: (calories - (totals?.calories ?? 0)).clamp(0, calories),
      protein: (protein - (totals?.proteinGrams ?? 0)).clamp(0, protein),
      carbohydrates: (carbs - (totals?.carbGrams ?? 0)).clamp(0, carbs),
      fats: (fats - (totals?.fatGrams ?? 0)).clamp(0, fats),
    );
  }
}

class _Candidate {
  final FuelMatchOption option;
  final double score;

  const _Candidate({required this.option, required this.score});

  bool isBetterThan(_Candidate other) => compareTo(other) < 0;

  int compareTo(_Candidate other) {
    final scoreOrder = other.score.compareTo(score);
    if (scoreOrder != 0) return scoreOrder;
    final kcalOrder = (option.nutrients.kcal - option.caloriesRemaining)
        .abs()
        .compareTo(
            (other.option.nutrients.kcal - other.option.caloriesRemaining)
                .abs());
    if (kcalOrder != 0) return kcalOrder;
    return option.recipe.id.compareTo(other.option.recipe.id);
  }
}

class _Weights {
  const _Weights({
    required this.kcal,
    required this.protein,
    required this.carbs,
    required this.fat,
  });

  final double kcal;
  final double protein;
  final double carbs;
  final double fat;
}
