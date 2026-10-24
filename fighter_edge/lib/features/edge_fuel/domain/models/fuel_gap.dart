import '../calculators/recipe_nutrient_calculator.dart';
import 'food_enums.dart';
import 'food_item.dart';
import 'fuel_add_on.dart';
import 'fuel_day_plan.dart';
import 'recipe.dart';

/// The macro the gap picker closes: "Protein left: 34 g, 3 options".
enum FuelGapMacro { protein, carbohydrate }

enum FuelGapStatus {
  /// At least one option.
  ready,

  /// No usable target or no amount left to work from.
  needsMoreData,

  /// Less than a useful amount is left. Nothing to add.
  gapClosed,

  /// A gap, but nothing passes the athlete's filters and the calorie room.
  noMatch,
}

/// The one-line reason under an option, as a code plus its numbers. The
/// screen writes the words, for example "Adds 31 g protein for 190 kcal.
/// Leaves 3 g to go." Every code is neutral: it says what an option adds,
/// never that a food is good or bad.
enum FuelGapReasonCode {
  /// What is left is covered, near enough.
  closesGap,

  /// Covers one meal's share of a gap that is split over meals.
  coversOneMeal,

  /// Covers part of what is left.
  addsPart,
}

class FuelGapReason {
  const FuelGapReason({
    required this.code,
    required this.macro,
    required this.addsGrams,
    required this.kcal,
    required this.leavesGrams,
  });

  final FuelGapReasonCode code;
  final FuelGapMacro macro;

  /// Grams of [macro] the option adds.
  final int addsGrams;
  final int kcal;

  /// Grams of [macro] still left for the day after this option. Never
  /// negative.
  final int leavesGrams;
}

/// A suggestion to spread a large protein gap over more than one meal.
///
/// ISSN 2017: one protein dose is 0.25-0.40 g/kg. A gap above the upper end
/// is split rather than met with one very large portion.
class FuelGapSplit {
  const FuelGapSplit({
    required this.parts,
    required this.gramsPerPart,
    required this.perMealCapGrams,
  });

  /// Eating occasions, 2 or 3.
  final int parts;

  /// The amount each option is sized for.
  final int gramsPerPart;

  /// The per-meal amount the split is based on.
  // dietitian sign-off pending
  final int perMealCapGrams;
}

/// One option: an add-on portion or a recipe portion.
class FuelGapOption {
  const FuelGapOption._({
    required this.group,
    required this.nutrients,
    required this.allergens,
    required this.dietTags,
    required this.reason,
    this.addOn,
    this.food,
    this.recipe,
    this.servings = 1,
  });

  factory FuelGapOption.addOn({
    required FuelAddOn addOn,
    required FoodItem food,
    required RecipeNutrients nutrients,
    required FuelGapReason reason,
  }) =>
      FuelGapOption._(
        group: addOn.group,
        nutrients: nutrients,
        allergens: food.allergens,
        dietTags: food.dietTags,
        reason: reason,
        addOn: addOn,
        food: food,
      );

  factory FuelGapOption.recipe({
    required Recipe recipe,
    required double servings,
    required RecipeNutrients nutrients,
    required Set<Allergen> allergens,
    required Set<DietTag> dietTags,
    required FuelGapReason reason,
  }) =>
      FuelGapOption._(
        group: AddOnGroup.meal,
        nutrients: nutrients,
        allergens: allergens,
        dietTags: dietTags,
        reason: reason,
        recipe: recipe,
        servings: servings,
      );

  /// [AddOnGroup.meal] for a recipe.
  final AddOnGroup group;
  final RecipeNutrients nutrients;
  final Set<Allergen> allergens;
  final Set<DietTag> dietTags;
  final FuelGapReason reason;

  /// Set for an add-on, with its [food].
  final FuelAddOn? addOn;
  final FoodItem? food;

  /// Set for a recipe, with its [servings].
  final Recipe? recipe;
  final double servings;

  bool get isRecipe => recipe != null;

  /// The add-on id or the recipe id.
  String get id => addOn?.id ?? recipe!.id;
}

/// The gap picker's answer, with the inputs it used so the screen can show
/// why (retention.md, explainability).
class FuelGapPick {
  const FuelGapPick({
    required this.status,
    required this.macro,
    this.gramsLeft = 0,
    this.kcalLeft,
    this.dayType,
    this.split,
    this.options = const [],
    this.unmatchedAllergenTerms = const [],
  });

  final FuelGapStatus status;
  final FuelGapMacro macro;

  /// Grams of [macro] left today: the "34 g" in "Protein left: 34 g".
  final int gramsLeft;

  /// Calories left today, when known. Options fit inside it.
  final int? kcalLeft;

  /// The day type that set the tie-break, when the caller gave one.
  final FuelDayType? dayType;

  /// Set when the gap is spread over more than one meal.
  final FuelGapSplit? split;

  /// Up to three, each from a different food group.
  final List<FuelGapOption> options;

  /// Allergy terms outside the regulated-allergen catalog. The UI must never
  /// claim an option is safe when this is nonempty.
  final List<String> unmatchedAllergenTerms;

  bool get isReady => status == FuelGapStatus.ready;
}
