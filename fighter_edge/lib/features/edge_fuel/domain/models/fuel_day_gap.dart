import 'fuel_calorie_gap.dart';
import 'fuel_gap.dart';

/// Exactly one typed gap, or a refusal with no amounts/options. Protein is
/// preferred; energy is considered once less than a useful protein gap remains.
class FuelDayGap {
  const FuelDayGap.blocked(this.status)
      : protein = null,
        calories = null;

  FuelDayGap.protein(FuelGapPick pick)
      : status = pick.status,
        protein = pick,
        calories = null;

  FuelDayGap.calories(FuelCalorieGapPick pick)
      : status = pick.status,
        protein = null,
        calories = pick;

  final FuelGapStatus status;
  final FuelGapPick? protein;
  final FuelCalorieGapPick? calories;
}
