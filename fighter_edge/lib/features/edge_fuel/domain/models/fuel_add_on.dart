/// Food groups used to keep the gap picker's options varied. A recipe is
/// [meal].
enum AddOnGroup {
  dairy,
  egg,
  meat,
  fish,
  plantProtein,
  supplement,
  legume,
  grain,
  fruit,
  nutSeed,
  meal,
}

/// The household unit of an add-on portion. A code, not a string: the screen
/// owns the words and the plural forms.
enum AddOnUnit { gram, piece, slice, scoop, can, tablespoon, cup }

/// One curated add-on: a single food in a household portion.
///
/// An add-on stores no nutrition. [foodId] points into the food catalog, so
/// calories, macros, allergens and diet tags always come from one source and
/// can never drift from it. An allergen can only be missed if the food record
/// misses it.
class FuelAddOn {
  const FuelAddOn({
    required this.id,
    required this.foodId,
    required this.group,
    required this.grams,
    required this.unit,
    required this.unitCount,
    required this.source,
    this.prepMinutes = 0,
  });

  /// [source] for a portion Fighter Edge chose as a common serving.
  // dietitian sign-off pending
  static const String sourceCurated = 'Fighter Edge curated portion';

  /// [source] for a portion that is a household weight in USDA FoodData
  /// Central (SR Legacy), such as one medium banana. Re-check at sign-off.
  static const String sourceUsdaHousehold =
      'USDA FoodData Central household weight';

  /// Stable id, unique across the list.
  final String id;

  /// A food in the bundled food catalog.
  final String foodId;
  final AddOnGroup group;

  /// Weight of one portion. The maths runs on this.
  final double grams;

  /// Display only: "2 piece", "1 scoop", or grams for [AddOnUnit.gram].
  final AddOnUnit unit;
  final double unitCount;

  /// Where the portion size comes from. The nutrition always comes from the
  /// food record, which carries its own source.
  final String source;

  /// Time to make it ready to eat. Zero for something eaten as it is.
  final int prepMinutes;
}
