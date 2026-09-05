import 'food_enums.dart';
import 'nutrition_enums.dart' show enumFromName;

/// A household measure for a food, so a user reads "1 medium egg" instead of
/// "50 g" while the maths still runs on grams (master prompt §5.3).
class HouseholdUnit {
  final String label;
  final double grams;

  const HouseholdUnit({required this.label, required this.grams});

  Map<String, dynamic> toJson() => {'label': label, 'grams': grams};

  factory HouseholdUnit.fromJson(Map<String, dynamic> json) {
    return HouseholdUnit(
      label: (json['label'] as String? ?? '').trim(),
      grams: FoodItem.positiveDouble(json['grams']),
    );
  }

  /// A unit is only usable if it names something and weighs something.
  bool get isValid => label.isNotEmpty && grams > 0;

  @override
  String toString() => '$label (${grams}g)';
}

/// One food in the bundled catalog, with nutrients expressed per 100 g.
///
/// Per-100 g is the single storage convention: every recipe ingredient carries
/// grams, so recipe nutrients are always `grams / 100 * perHundred`. Nothing in
/// the app stores a pre-computed per-serving figure for a food.
///
/// Values are transcribed from USDA FoodData Central (public domain). The whole
/// table ships as [ContentStatus.draft] until a qualified reviewer signs off —
/// see `docs/edge_fuel/SAFETY_AND_EVIDENCE.md`.
class FoodItem {
  static const schemaVersion = 1;

  final String id;
  final String name;
  final FoodCategory category;

  /// Nutrients per 100 g, edible portion.
  final double kcalPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double fibrePer100g;

  final List<HouseholdUnit> householdUnits;

  /// Allergens this food *contains*. An empty set means "none of the tracked
  /// allergens", never "safe for everyone".
  final Set<Allergen> allergens;

  /// Diets this food is compatible with. See [DietTag].
  final Set<DietTag> dietTags;

  /// Provenance, e.g. `USDA FoodData Central`.
  final String source;

  /// Optional upstream identifier (an FDC id) so a value can be re-checked.
  final String? sourceRef;

  final ContentStatus status;

  const FoodItem({
    required this.id,
    required this.name,
    required this.category,
    required this.kcalPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.fibrePer100g,
    this.householdUnits = const [],
    this.allergens = const {},
    this.dietTags = const {},
    this.source = 'USDA FoodData Central',
    this.sourceRef,
    this.status = ContentStatus.draft,
  });

  FoodItem copyWith({
    String? id,
    String? name,
    FoodCategory? category,
    double? kcalPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? fibrePer100g,
    List<HouseholdUnit>? householdUnits,
    Set<Allergen>? allergens,
    Set<DietTag>? dietTags,
    String? source,
    String? sourceRef,
    ContentStatus? status,
  }) {
    return FoodItem(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      kcalPer100g: kcalPer100g ?? this.kcalPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      fibrePer100g: fibrePer100g ?? this.fibrePer100g,
      householdUnits: householdUnits ?? this.householdUnits,
      allergens: allergens ?? this.allergens,
      dietTags: dietTags ?? this.dietTags,
      source: source ?? this.source,
      sourceRef: sourceRef ?? this.sourceRef,
      status: status ?? this.status,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'id': id,
        'name': name,
        'category': category.name,
        'kcalPer100g': kcalPer100g,
        'proteinPer100g': proteinPer100g,
        'carbsPer100g': carbsPer100g,
        'fatPer100g': fatPer100g,
        'fibrePer100g': fibrePer100g,
        'householdUnits': householdUnits.map((u) => u.toJson()).toList(),
        'allergens': allergens.map((a) => a.name).toList(),
        'dietTags': dietTags.map((d) => d.name).toList(),
        'source': source,
        if (sourceRef != null) 'sourceRef': sourceRef,
        'status': status.name,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    return FoodItem(
      id: (json['id'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      category: enumFromName(FoodCategory.values, json['category']) ??
          FoodCategory.other,
      kcalPer100g: positiveDouble(json['kcalPer100g']),
      proteinPer100g: positiveDouble(json['proteinPer100g']),
      carbsPer100g: positiveDouble(json['carbsPer100g']),
      fatPer100g: positiveDouble(json['fatPer100g']),
      fibrePer100g: positiveDouble(json['fibrePer100g']),
      householdUnits: (json['householdUnits'] as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map(HouseholdUnit.fromJson)
          .toList(),
      allergens: _tagSet(json['allergens'], Allergen.values),
      dietTags: _tagSet(json['dietTags'], DietTag.values),
      source: (json['source'] as String? ?? 'USDA FoodData Central').trim(),
      sourceRef: (json['sourceRef'] as String?)?.trim(),
      status: enumFromName(ContentStatus.values, json['status']) ??
          ContentStatus.draft,
    );
  }

  /// Non-negative parse. Nutrient data is never meaningfully negative, and a
  /// bad value silently becoming 0 is safer than it becoming a negative that
  /// would subtract from a recipe total.
  static double positiveDouble(Object? value) {
    final parsed = value is num ? value.toDouble() : double.tryParse('$value');
    if (parsed == null || parsed.isNaN || parsed.isInfinite || parsed < 0) {
      return 0;
    }
    return parsed;
  }

  static Set<T> _tagSet<T extends Enum>(Object? raw, List<T> values) {
    if (raw is! List) return const {};
    final out = <T>{};
    for (final entry in raw) {
      final parsed = enumFromName(values, entry);
      if (parsed != null) out.add(parsed);
    }
    return out;
  }

  @override
  String toString() => 'FoodItem($id)';
}
