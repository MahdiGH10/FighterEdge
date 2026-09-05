import 'food_enums.dart';
import 'food_item.dart';
import 'nutrition_enums.dart' show enumFromName;

/// One ingredient line in a recipe.
///
/// Grams are the source of truth; [householdUnitLabel] is display only, so a
/// user reads "2 tbsp" while the maths runs on 30 g. The label is *not* used to
/// derive the weight — a mismatch between the two is a content bug the
/// validator catches, not something the calculator silently reconciles.
class RecipeIngredient {
  final String foodId;
  final double grams;

  /// Display text such as `2 tbsp` or `1 medium banana`. Optional.
  final String? householdUnitLabel;

  /// Optional ingredients are excluded from calculated nutrients by default —
  /// see [RecipeNutrientCalculator]. Keep them to garnish-level items so the
  /// difference stays negligible.
  final bool optional;

  /// Free-text preparation note, e.g. `finely chopped`.
  final String note;

  const RecipeIngredient({
    required this.foodId,
    required this.grams,
    this.householdUnitLabel,
    this.optional = false,
    this.note = '',
  });

  Map<String, dynamic> toJson() => {
    'foodId': foodId,
    'grams': grams,
    if (householdUnitLabel != null) 'householdUnitLabel': householdUnitLabel,
    if (optional) 'optional': true,
    if (note.isNotEmpty) 'note': note,
  };

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      foodId: (json['foodId'] as String? ?? '').trim(),
      grams: FoodItem.positiveDouble(json['grams']),
      householdUnitLabel: (json['householdUnitLabel'] as String?)?.trim(),
      optional: json['optional'] as bool? ?? false,
      note: (json['note'] as String? ?? '').trim(),
    );
  }
}

/// A suggested swap for one ingredient, e.g. swap tahini for peanut butter.
class RecipeSubstitution {
  final String forFoodId;
  final String useFoodId;
  final String reason;

  const RecipeSubstitution({
    required this.forFoodId,
    required this.useFoodId,
    this.reason = '',
  });

  Map<String, dynamic> toJson() => {
    'forFoodId': forFoodId,
    'useFoodId': useFoodId,
    if (reason.isNotEmpty) 'reason': reason,
  };

  factory RecipeSubstitution.fromJson(Map<String, dynamic> json) {
    return RecipeSubstitution(
      forFoodId: (json['forFoodId'] as String? ?? '').trim(),
      useFoodId: (json['useFoodId'] as String? ?? '').trim(),
      reason: (json['reason'] as String? ?? '').trim(),
    );
  }
}

/// A curated recipe (master prompt §9.2).
///
/// Two fields the spec lists are deliberately **not** stored here and are
/// derived instead — see `docs/edge_fuel/EF3_PLAN.md`:
///
/// - **Per-serving nutrients** are computed by [RecipeNutrientCalculator] from
///   the ingredient list. Storing them would let the stored figure drift from
///   the ingredients, and §2.4 requires recipe nutrition to be calculated from
///   structured ingredient data.
/// - **Diet and allergen tags** are derived from the ingredients too: a recipe
///   is vegan only if every ingredient is, and it carries the union of its
///   ingredients' allergens. Hand-tagging these is precisely how an allergen
///   gets missed. [extraAllergens] exists for allergens the ingredients cannot
///   express (a shared fryer, a garnish outside the food table).
class Recipe {
  static const schemaVersion = 1;

  final String id;
  final String title;
  final String description;
  final int servings;

  final List<RecipeIngredient> ingredients;
  final List<String> steps;
  final List<RecipeSubstitution> substitutions;

  final int prepMinutes;
  final int cookMinutes;

  final MealType mealType;
  final TrainingTiming trainingTiming;
  final Set<String> cuisineTags;
  final CostBand costBand;
  final List<String> equipment;

  /// Allergens that the ingredient list cannot express on its own.
  final Set<Allergen> extraAllergens;

  /// Null in V1 — see EF3_PLAN.md §8, decision 2.
  final String? imageAsset;

  final bool isPremium;
  final int contentVersion;

  /// Null until a qualified reviewer signs off. [status] must stay
  /// [ContentStatus.draft] while this is null.
  final String? reviewerCredit;
  final DateTime? reviewedAt;

  final ContentStatus status;

  const Recipe({
    required this.id,
    required this.title,
    required this.description,
    required this.servings,
    required this.ingredients,
    required this.steps,
    required this.mealType,
    this.substitutions = const [],
    this.prepMinutes = 0,
    this.cookMinutes = 0,
    this.trainingTiming = TrainingTiming.any,
    this.cuisineTags = const {},
    this.costBand = CostBand.low,
    this.equipment = const [],
    this.extraAllergens = const {},
    this.imageAsset,
    this.isPremium = false,
    this.contentVersion = 1,
    this.reviewerCredit,
    this.reviewedAt,
    this.status = ContentStatus.draft,
  });

  int get totalMinutes => prepMinutes + cookMinutes;

  bool get requiresOven =>
      equipment.any((e) => e.toLowerCase().contains('oven'));

  Map<String, dynamic> toJson() => {
    'schemaVersion': schemaVersion,
    'id': id,
    'title': title,
    'description': description,
    'servings': servings,
    'ingredients': ingredients.map((i) => i.toJson()).toList(),
    'steps': steps,
    'substitutions': substitutions.map((s) => s.toJson()).toList(),
    'prepMinutes': prepMinutes,
    'cookMinutes': cookMinutes,
    'mealType': mealType.name,
    'trainingTiming': trainingTiming.name,
    'cuisineTags': cuisineTags.toList(),
    'costBand': costBand.name,
    'equipment': equipment,
    'extraAllergens': extraAllergens.map((a) => a.name).toList(),
    if (imageAsset != null) 'imageAsset': imageAsset,
    'isPremium': isPremium,
    'contentVersion': contentVersion,
    if (reviewerCredit != null) 'reviewerCredit': reviewerCredit,
    if (reviewedAt != null) 'reviewedAt': reviewedAt!.toIso8601String(),
    'status': status.name,
  };

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: (json['id'] as String? ?? '').trim(),
      title: (json['title'] as String? ?? '').trim(),
      description: (json['description'] as String? ?? '').trim(),
      servings: _positiveInt(json['servings'], fallback: 1),
      ingredients: (json['ingredients'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RecipeIngredient.fromJson)
          .toList(),
      steps: (json['steps'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      substitutions: (json['substitutions'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(RecipeSubstitution.fromJson)
          .toList(),
      prepMinutes: _positiveInt(json['prepMinutes']),
      cookMinutes: _positiveInt(json['cookMinutes']),
      mealType:
          enumFromName(MealType.values, json['mealType']) ?? MealType.lunch,
      trainingTiming:
          enumFromName(TrainingTiming.values, json['trainingTiming']) ??
          TrainingTiming.any,
      cuisineTags: (json['cuisineTags'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toSet(),
      costBand: enumFromName(CostBand.values, json['costBand']) ?? CostBand.low,
      equipment: (json['equipment'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      extraAllergens: _allergenSet(json['extraAllergens']),
      imageAsset: (json['imageAsset'] as String?)?.trim(),
      isPremium: json['isPremium'] as bool? ?? false,
      contentVersion: _positiveInt(json['contentVersion'], fallback: 1),
      reviewerCredit: (json['reviewerCredit'] as String?)?.trim(),
      reviewedAt: DateTime.tryParse(json['reviewedAt'] as String? ?? ''),
      status:
          enumFromName(ContentStatus.values, json['status']) ??
          ContentStatus.draft,
    );
  }

  static int _positiveInt(Object? value, {int fallback = 0}) {
    final parsed = value is num ? value.toInt() : int.tryParse('$value');
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  static Set<Allergen> _allergenSet(Object? raw) {
    if (raw is! List) return const {};
    final out = <Allergen>{};
    for (final entry in raw) {
      final parsed = enumFromName(Allergen.values, entry);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  @override
  String toString() => 'Recipe($id)';
}
