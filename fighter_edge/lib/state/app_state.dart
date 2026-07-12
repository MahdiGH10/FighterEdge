import 'package:flutter/foundation.dart';

import '../data/mock_data.dart';
import '../models/meal.dart';
import '../models/weight_entry.dart';

/// Holds the mutable state for the three interactive features:
/// weight tracking and nutrition. (The round timer keeps local state.)
class AppState extends ChangeNotifier {
  final List<WeightEntry> _weights = MockData.seedWeights();
  final List<Meal> _meals = MockData.seedMeals();

  // ---- Weight ----
  List<WeightEntry> get weights => List.unmodifiable(_sortedByDate);

  double get latestWeight => _weights.isEmpty ? 0 : _sortedByDate.last.kg;

  /// Change vs the previous weigh-in (negative = weight loss).
  double get weeklyDelta {
    final s = _sortedByDate;
    if (s.length < 2) return 0;
    return s.last.kg - s[s.length - 2].kg;
  }

  List<WeightEntry> get _sortedByDate =>
      [..._weights]..sort((a, b) => a.date.compareTo(b.date));

  /// History newest-first for the list view.
  List<WeightEntry> get weightHistoryDesc =>
      [..._weights]..sort((a, b) => b.date.compareTo(a.date));

  void addWeight(DateTime date, double kg) {
    _weights.add(WeightEntry(date, kg));
    notifyListeners();
  }

  // ---- Nutrition ----
  List<Meal> get meals => List.unmodifiable(_meals);
  MacroTarget get target => MockData.macroTarget;

  int get consumedCalories =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.calories);
  int get consumedProtein =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.protein);
  int get consumedCarbs =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.carbs);
  int get consumedFats =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.fats);

  void toggleMeal(Meal meal) {
    meal.eaten = !meal.eaten;
    notifyListeners();
  }
}
