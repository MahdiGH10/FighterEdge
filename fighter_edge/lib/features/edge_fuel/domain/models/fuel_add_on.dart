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
    this.prepMinutes = 0,
  });

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

  /// Time to make it ready to eat. Zero for something eaten as it is.
  final int prepMinutes;
}
