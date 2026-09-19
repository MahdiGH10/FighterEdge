import '../../../../../models/meal.dart';

enum FoodLogSource { manual, legacyMeal, recent, savedMeal, recipe, catalog }

class FoodLogEntry {
  static const schemaVersion = 1;

  final String id;
  final String name;
  final String notes;
  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;
  final bool consumed;
  final bool saved;
  final FoodLogSource source;
  final DateTime loggedAt;

  const FoodLogEntry({
    required this.id,
    required this.name,
    required this.notes,
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
    required this.loggedAt,
    this.consumed = true,
    this.saved = false,
    this.source = FoodLogSource.manual,
  });

  FoodLogEntry copyWith({
    String? id,
    String? name,
    String? notes,
    int? calories,
    int? proteinGrams,
    int? carbGrams,
    int? fatGrams,
    bool? consumed,
    bool? saved,
    FoodLogSource? source,
    DateTime? loggedAt,
  }) {
    return FoodLogEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      calories: calories ?? this.calories,
      proteinGrams: proteinGrams ?? this.proteinGrams,
      carbGrams: carbGrams ?? this.carbGrams,
      fatGrams: fatGrams ?? this.fatGrams,
      consumed: consumed ?? this.consumed,
      saved: saved ?? this.saved,
      source: source ?? this.source,
      loggedAt: loggedAt ?? this.loggedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'notes': notes,
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
        'fatGrams': fatGrams,
        'consumed': consumed,
        'saved': saved,
        'source': source.name,
        'loggedAt': loggedAt.toIso8601String(),
      };

  factory FoodLogEntry.fromJson(Map<String, dynamic> json) {
    return FoodLogEntry(
      id: json['id'] as String? ?? _fallbackId(json),
      name: json['name'] as String? ?? 'Food',
      notes: json['notes'] as String? ?? '',
      calories: _nonNegativeInt(json['calories']),
      proteinGrams: _nonNegativeInt(json['proteinGrams'] ?? json['protein']),
      carbGrams: _nonNegativeInt(json['carbGrams'] ?? json['carbs']),
      fatGrams: _nonNegativeInt(json['fatGrams'] ?? json['fats']),
      consumed: json['consumed'] as bool? ?? json['eaten'] as bool? ?? true,
      saved: json['saved'] as bool? ?? false,
      source: _sourceFromName(json['source'] as String?),
      loggedAt: DateTime.tryParse(json['loggedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  factory FoodLogEntry.fromMeal(Meal meal, {required DateTime loggedAt}) {
    final stableMealId = meal.id.trim().isEmpty
        ? meal.name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        : meal.id.trim();
    return FoodLogEntry(
      id: 'legacy-$stableMealId',
      name: meal.name.trim().isEmpty ? 'Imported meal' : meal.name.trim(),
      notes: meal.items.trim(),
      calories: meal.calories < 0 ? 0 : meal.calories,
      proteinGrams: meal.protein < 0 ? 0 : meal.protein,
      carbGrams: meal.carbs < 0 ? 0 : meal.carbs,
      fatGrams: meal.fats < 0 ? 0 : meal.fats,
      consumed: meal.eaten,
      source: FoodLogSource.legacyMeal,
      loggedAt: loggedAt,
    );
  }

  Meal toLegacyMeal() => Meal(
        id: id,
        name: name,
        items: notes,
        calories: calories,
        protein: proteinGrams,
        carbs: carbGrams,
        fats: fatGrams,
        eaten: consumed,
      );

  static int _nonNegativeInt(Object? value) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value') ?? 0;
    return parsed < 0 ? 0 : parsed;
  }

  static String _fallbackId(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? 'food';
    return name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  }

  static FoodLogSource _sourceFromName(String? name) {
    return FoodLogSource.values.firstWhere(
      (source) => source.name == name,
      orElse: () => FoodLogSource.manual,
    );
  }
}

class FoodLogTotals {
  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  const FoodLogTotals({
    this.calories = 0,
    this.proteinGrams = 0,
    this.carbGrams = 0,
    this.fatGrams = 0,
  });

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'proteinGrams': proteinGrams,
        'carbGrams': carbGrams,
        'fatGrams': fatGrams,
      };

  factory FoodLogTotals.fromJson(Map<String, dynamic> json) {
    return FoodLogTotals(
      calories: FoodLogEntry._nonNegativeInt(json['calories']),
      proteinGrams: FoodLogEntry._nonNegativeInt(json['proteinGrams']),
      carbGrams: FoodLogEntry._nonNegativeInt(json['carbGrams']),
      fatGrams: FoodLogEntry._nonNegativeInt(json['fatGrams']),
    );
  }

  static FoodLogTotals fromEntries(Iterable<FoodLogEntry> entries) {
    final consumed = entries.where((entry) => entry.consumed);
    return FoodLogTotals(
      calories: consumed.fold(0, (sum, entry) => sum + entry.calories),
      proteinGrams: consumed.fold(0, (sum, entry) => sum + entry.proteinGrams),
      carbGrams: consumed.fold(0, (sum, entry) => sum + entry.carbGrams),
      fatGrams: consumed.fold(0, (sum, entry) => sum + entry.fatGrams),
    );
  }
}
