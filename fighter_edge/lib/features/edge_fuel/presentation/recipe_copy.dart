import '../domain/models/food_enums.dart';

/// Human-readable copy for the recipe/food domain enums.
///
/// Separate from `NutritionCopy` only because that file is already long and
/// these labels belong to a different sprint's vocabulary — same principle:
/// the domain layer stays pure Dart and localization-agnostic, screens share
/// one source of wording.
class RecipeCopy {
  RecipeCopy._();

  static String mealTypeLabel(MealType type) => switch (type) {
    MealType.breakfast => 'Breakfast',
    MealType.snack => 'Snack',
    MealType.lunch => 'Lunch',
    MealType.dinner => 'Dinner',
  };

  static String timingLabel(TrainingTiming timing) => switch (timing) {
    TrainingTiming.any => 'Any time',
    TrainingTiming.preTraining => 'Before training',
    TrainingTiming.postTraining => 'After training',
  };

  static String dietLabel(DietTag tag) => switch (tag) {
    DietTag.vegan => 'Vegan',
    DietTag.vegetarian => 'Vegetarian',
    DietTag.pescatarian => 'Pescatarian',
    DietTag.halal => 'Halal-friendly',
  };

  static String costLabel(CostBand band) => switch (band) {
    CostBand.low => 'Budget',
    CostBand.medium => 'Mid',
    CostBand.high => 'Pricey',
  };

  static String allergenLabel(Allergen allergen) => switch (allergen) {
    Allergen.milk => 'Milk',
    Allergen.eggs => 'Eggs',
    Allergen.fish => 'Fish',
    Allergen.shellfish => 'Shellfish',
    Allergen.treeNuts => 'Tree nuts',
    Allergen.peanuts => 'Peanuts',
    Allergen.gluten => 'Gluten',
    Allergen.soy => 'Soy',
    Allergen.sesame => 'Sesame',
    Allergen.mustard => 'Mustard',
    Allergen.celery => 'Celery',
    Allergen.sulphites => 'Sulphites',
  };

  static String allergenList(Iterable<Allergen> allergens) {
    final labels = allergens.map(allergenLabel).toList()..sort();
    if (labels.isEmpty) return '';
    if (labels.length == 1) return labels.single;
    return '${labels.sublist(0, labels.length - 1).join(', ')} '
        'and ${labels.last}';
  }

  /// Shown under every recipe's ingredient list.
  ///
  /// The wording is deliberately not reassuring. The catalog tracks twelve
  /// regulated allergens from its own ingredient data; it has no visibility of
  /// what happens in the user's kitchen or which brand they buy. Telling
  /// someone a dish is "safe" is a claim this app cannot support.
  static const String allergenDisclaimer =
      'Allergen information is derived from the listed ingredients only. '
      'Always check the labels on what you actually buy.';

  /// Shown while the catalog is unreviewed.
  static const String draftNotice =
      'Written by the Fighter Edge team. Not yet reviewed by a registered '
      'dietitian.';

  static String timeLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final hours = minutes ~/ 60;
    final rest = minutes % 60;
    return rest == 0 ? '${hours}h' : '${hours}h ${rest}m';
  }

  static String servingsLabel(double servings) {
    if (servings == servings.roundToDouble()) {
      final whole = servings.round();
      return whole == 1 ? '1 serving' : '$whole servings';
    }
    return '${servings.toStringAsFixed(1)} servings';
  }
}
