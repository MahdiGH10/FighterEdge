class Meal {
  final String id;
  final String name;
  final String items;
  final int calories;
  final int protein;
  final int carbs;
  final int fats;
  bool eaten;

  Meal({
    String? id,
    required this.name,
    required this.items,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    this.eaten = false,
  }) : id = id ?? name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');

  Meal copyWith({bool? eaten}) => Meal(
        id: id,
        name: name,
        items: items,
        calories: calories,
        protein: protein,
        carbs: carbs,
        fats: fats,
        eaten: eaten ?? this.eaten,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': items,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fats': fats,
        'eaten': eaten,
      };

  factory Meal.fromJson(Map<String, dynamic> json) => Meal(
        id: json['id'] as String?,
        name: json['name'] as String? ?? '',
        items: json['items'] as String? ?? '',
        calories: (json['calories'] as num?)?.toInt() ?? 0,
        protein: (json['protein'] as num?)?.toInt() ?? 0,
        carbs: (json['carbs'] as num?)?.toInt() ?? 0,
        fats: (json['fats'] as num?)?.toInt() ?? 0,
        eaten: json['eaten'] as bool? ?? false,
      );
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
