import '../calculators/recipe_nutrient_calculator.dart';
import 'food_item.dart';
import 'fuel_add_on.dart';
import 'fuel_gap.dart';

/// Energy gaps use kcal fields throughout; they never reuse gram fields.
class FuelCalorieGapReason {
  const FuelCalorieGapReason({
    required this.code,
    required this.addsKcal,
    required this.leavesKcal,
  });

  final FuelGapReasonCode code;
  final int addsKcal;
  final int leavesKcal;
}

class FuelCalorieGapOption {
  const FuelCalorieGapOption({
    required this.addOn,
    required this.food,
    required this.nutrients,
    required this.reason,
  });

  final FuelAddOn addOn;
  final FoodItem food;
  final RecipeNutrients nutrients;
  final FuelCalorieGapReason reason;
}

class FuelCalorieGapPick {
  FuelCalorieGapPick({
    required this.status,
    this.kcalLeft = 0,
    List<FuelCalorieGapOption> options = const [],
    List<String> unmatchedAllergenTerms = const [],
  })  : options = List.unmodifiable(options),
        unmatchedAllergenTerms = List.unmodifiable(unmatchedAllergenTerms);

  final FuelGapStatus status;
  final int kcalLeft;
  final List<FuelCalorieGapOption> options;
  final List<String> unmatchedAllergenTerms;
}
