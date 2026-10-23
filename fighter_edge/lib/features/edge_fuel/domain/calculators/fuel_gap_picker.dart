import 'dart:math' as math;

import '../models/food_item.dart';
import '../models/fuel_add_on.dart';
import '../models/fuel_day_plan.dart';
import '../models/fuel_gap.dart';
import '../models/nutrition_setup_draft.dart';
import '../models/recipe.dart';
import '../policies/fuel_day_policy.dart';
import '../policies/recipe_publication_gate.dart';
import 'fuel_preference_filter.dart';
import 'recipe_nutrient_calculator.dart';

/// The macro-first gap picker: "Protein left: 34 g, 3 options".
///
/// Pure and deterministic, with no clock and no AI. Pool: the curated add-ons
/// plus, optionally, recipe portions. Rules (retention.md, section 3A):
///
/// - The athlete's filters (allergens, diet, time, dislikes) are hard
///   exclusions, shared with the calorie-first match.
/// - An option fits inside the calories left x [kcalCapFactor], shared out
///   over the meals when the gap is split.
/// - Ranked by how much of the gap it covers and how much of its energy is the
///   macro asked for, with a small carbohydrate tie-break on hard and double
///   days.
/// - At most three options, each from a different food group.
/// - A protein gap above 0.4 g/kg (one ISSN dose) is split over two or three
///   meals.
class FuelGapPicker {
  const FuelGapPicker._();

  static const int maxOptions = 3;

  /// Less than this is left: nothing to add.
  static const int minimumGapGrams = 5;

  /// An option must add at least this many grams of the macro.
  static const int minimumUsefulGrams = 5;

  /// And at least this share of the amount it is sized for.
  static const double minimumShareOfPart = 0.25;

  /// Options fit inside calories left x this (the existing overshoot rule).
  static const double kcalCapFactor = 1.1;

  /// Recipe portions the picker tries.
  static const List<double> recipeServings = [0.5, 1, 1.5];

  static FuelGapPick pick({
    required FuelGapMacro macro,
    required int gramsLeft,
    int? kcalLeft,
    double? weightKg,
    FuelDayType? dayType,
    required Iterable<FuelAddOn> addOns,
    required Map<String, FoodItem> foodsById,
    Iterable<Recipe> recipes = const [],
    NutritionSetupDraft? preferences,
  }) {
    if (gramsLeft < 0 || (kcalLeft != null && kcalLeft < 0)) {
      return FuelGapPick(status: FuelGapStatus.needsMoreData, macro: macro);
    }
    if (gramsLeft < minimumGapGrams) {
      return FuelGapPick(
        status: FuelGapStatus.gapClosed,
        macro: macro,
        gramsLeft: gramsLeft,
        kcalLeft: kcalLeft,
        dayType: dayType,
      );
    }

    final split =
        macro == FuelGapMacro.protein ? splitFor(gramsLeft, weightKg) : null;
    final parts = split?.parts ?? 1;
    final partGrams = split?.gramsPerPart ?? gramsLeft;
    final kcalCap = kcalLeft == null ? null : kcalLeft * kcalCapFactor / parts;
    final minGrams = math.max(
      minimumUsefulGrams.toDouble(),
      partGrams * minimumShareOfPart,
    );
    final filter = FuelPreferenceFilter.from(preferences);
    final scorer = _Scorer(
      macro: macro,
      partGrams: partGrams,
      carbTieBreak:
          dayType == FuelDayType.hard || dayType == FuelDayType.doubleDay,
    );

    bool fits(RecipeNutrients n) =>
        n.kcal > 0 &&
        _macroOf(n, macro) >= minGrams &&
        (kcalCap == null || n.kcal <= kcalCap);

    final candidates = <_Candidate>[];
    for (final addOn in addOns) {
      final food = foodsById[addOn.foodId];
      if (food == null || !filter.allowsAddOn(addOn, food)) continue;
      final nutrients = RecipeNutrientCalculator.forFood(food, addOn.grams);
      if (!fits(nutrients)) continue;
      candidates.add(_Candidate(
        id: addOn.id,
        group: addOn.group,
        nutrients: nutrients,
        score: scorer.score(nutrients),
        build: (reason) => FuelGapOption.addOn(
          addOn: addOn,
          food: food,
          nutrients: nutrients,
          reason: reason,
        ),
      ));
    }

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
      _Candidate? best;
      for (final servings in recipeServings) {
        final nutrients = perServing.scaled(servings);
        if (!fits(nutrients)) continue;
        final candidate = _Candidate(
          id: recipe.id,
          group: AddOnGroup.meal,
          nutrients: nutrients,
          score: scorer.score(nutrients),
          build: (reason) => FuelGapOption.recipe(
            recipe: recipe,
            servings: servings,
            nutrients: nutrients,
            allergens: allergens,
            dietTags: diets,
            reason: reason,
          ),
        );
        if (best == null || candidate.compareTo(best) < 0) best = candidate;
      }
      if (best != null) candidates.add(best);
    }

    candidates.sort((a, b) => a.compareTo(b));
    final usedGroups = <AddOnGroup>{};
    final options = <FuelGapOption>[];
    for (final candidate in candidates) {
      if (options.length == maxOptions) break;
      if (!usedGroups.add(candidate.group)) continue;
      options.add(candidate.build(
        _reasonFor(
          candidate.nutrients,
          macro: macro,
          gramsLeft: gramsLeft,
          partGrams: partGrams,
          split: split != null,
        ),
      ));
    }

    return FuelGapPick(
      status: options.isEmpty ? FuelGapStatus.noMatch : FuelGapStatus.ready,
      macro: macro,
      gramsLeft: gramsLeft,
      kcalLeft: kcalLeft,
      dayType: dayType,
      split: split,
      options: List.unmodifiable(options),
      unmatchedAllergenTerms: filter.unmatchedAllergenTerms,
    );
  }

  /// The per-meal protein amount: 0.4 g/kg, or 40 g when the weight is not
  /// known.
  // dietitian sign-off pending
  static int perMealProteinCap(double? weightKg) =>
      weightKg != null && weightKg.isFinite && weightKg > 0
          ? (FuelDayPolicy.maxProteinPerMealGPerKg * weightKg).round()
          : FuelDayPolicy.maxProteinPerMealGramsFallback;

  /// The split for a protein gap, or null when one meal covers it.
  static FuelGapSplit? splitFor(int gramsLeft, double? weightKg) {
    final cap = perMealProteinCap(weightKg);
    if (cap <= 0 || gramsLeft <= cap) return null;
    final parts =
        math.min(FuelDayPolicy.maxSplitParts, (gramsLeft / cap).ceil());
    return FuelGapSplit(
      parts: parts,
      gramsPerPart: math.min(cap, (gramsLeft / parts).ceil()),
      perMealCapGrams: cap,
    );
  }

  static FuelGapReason _reasonFor(
    RecipeNutrients nutrients, {
    required FuelGapMacro macro,
    required int gramsLeft,
    required int partGrams,
    required bool split,
  }) {
    final adds = _macroOf(nutrients, macro).round();
    final leaves = math.max(0, gramsLeft - adds);
    final FuelGapReasonCode code;
    if (leaves < minimumGapGrams) {
      code = FuelGapReasonCode.closesGap;
    } else if (split && adds >= partGrams - minimumGapGrams) {
      code = FuelGapReasonCode.coversOneMeal;
    } else {
      code = FuelGapReasonCode.addsPart;
    }
    return FuelGapReason(
      code: code,
      macro: macro,
      addsGrams: adds,
      kcal: nutrients.kcalRounded,
      leavesGrams: leaves,
    );
  }

  static double _macroOf(RecipeNutrients n, FuelGapMacro macro) =>
      switch (macro) {
        FuelGapMacro.protein => n.proteinGrams,
        FuelGapMacro.carbohydrate => n.carbGrams,
      };
}

class _Scorer {
  const _Scorer({
    required this.macro,
    required this.partGrams,
    required this.carbTieBreak,
  });

  final FuelGapMacro macro;
  final int partGrams;
  final bool carbTieBreak;

  /// Higher is better.
  ///
  /// coverage: share of the amount this option is sized for, up to 1.
  /// density:  share of the option's energy that is the macro asked for.
  /// excess:   going well past the amount wastes calories, so it costs.
  double score(RecipeNutrients n) {
    final grams = FuelGapPicker._macroOf(n, macro);
    final coverage = math.min(grams, partGrams) / partGrams;
    final density = (grams * 4 / n.kcal).clamp(0.0, 1.0);
    final excess = math.max(0.0, grams / partGrams - 1.25);
    var score = coverage * .55 + density * .45 - excess * .3;
    if (carbTieBreak && macro == FuelGapMacro.protein) {
      score += (n.carbGrams * 4 / n.kcal).clamp(0.0, 1.0) * .05;
    }
    return score;
  }
}

class _Candidate {
  const _Candidate({
    required this.id,
    required this.group,
    required this.nutrients,
    required this.score,
    required this.build,
  });

  final String id;
  final AddOnGroup group;
  final RecipeNutrients nutrients;
  final double score;
  final FuelGapOption Function(FuelGapReason reason) build;

  /// Best first: higher score, then fewer calories, then id.
  int compareTo(_Candidate other) {
    final byScore = other.score.compareTo(score);
    if (byScore != 0) return byScore;
    final byKcal = nutrients.kcal.compareTo(other.nutrients.kcal);
    if (byKcal != 0) return byKcal;
    return id.compareTo(other.id);
  }
}
