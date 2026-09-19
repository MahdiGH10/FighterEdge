import '../models/food_item.dart';

/// Nutrients for an eaten portion of a catalog food, rounded the way the log
/// stores them (whole kcal and whole grams).
class PortionNutrients {
  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  const PortionNutrients({
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
  });
}

/// Turns "150 g of chicken breast" into log-ready numbers.
///
/// The catalog stores everything per 100 g, so this is the only place that
/// scales it — the same convention recipes use.
class PortionCalculator {
  PortionCalculator._();

  /// Largest portion a single log entry accepts. Far above any real meal; it
  /// only exists so a typo ("15000") cannot swamp a day's totals.
  static const maxGrams = 2000.0;

  static PortionNutrients forGrams(FoodItem food, double grams) {
    final g = grams.clamp(0, maxGrams).toDouble();
    double scale(double per100) => per100 * g / 100;
    return PortionNutrients(
      calories: scale(food.kcalPer100g).round(),
      proteinGrams: scale(food.proteinPer100g).round(),
      carbGrams: scale(food.carbsPer100g).round(),
      fatGrams: scale(food.fatPer100g).round(),
    );
  }

  /// A readable label for a portion: "150 g", "1 slice (35 g)", or
  /// "1 slice ×2 (70 g)" when it came from a household unit.
  static String label(double grams, {String? unitLabel, double? units}) {
    final g = grams.round();
    if (unitLabel == null || units == null) return '$g g';
    if (units == 1) return '$unitLabel ($g g)';
    final count = units == units.roundToDouble()
        ? units.toInt().toString()
        : units.toStringAsFixed(1);
    return '$unitLabel ×$count ($g g)';
  }
}
