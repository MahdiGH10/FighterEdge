class Meal {
  final String name;
  final String items;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  bool eaten;

  Meal({
    required this.name,
    required this.items,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.eaten = false,
  });
}

class MacroTarget {
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  const MacroTarget({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
  });
}
