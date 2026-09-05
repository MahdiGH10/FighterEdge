/// Pure-Dart enums for the EdgeFuel food/recipe catalog (master prompt §9).
/// No Flutter imports — this whole `domain/` subtree must stay usable outside
/// the widget tree.
library;

/// Coarse grouping used for catalog browsing and for sanity-checking that a
/// recipe's ingredient list is plausible. Not a nutrition input.
enum FoodCategory {
  protein,
  dairy,
  grain,
  legume,
  vegetable,
  fruit,
  nutSeed,
  fat,
  condiment,
  beverage,
  other,
}

/// The allergens the catalog tracks. Deliberately limited to the widely
/// regulated set (EU 14 / US "big 9" overlap) rather than an open-ended list —
/// an allergen we cannot reliably tag on every food is worse than one we do not
/// claim to track. Absence of a tag is never a safety guarantee; the UI says so.
enum Allergen {
  milk,
  eggs,
  fish,
  shellfish,
  treeNuts,
  peanuts,
  gluten,
  soy,
  sesame,
  mustard,
  celery,
  sulphites,
}

/// Diets a food is *compatible with*. Read as a whitelist: a food carrying
/// [DietTag.vegan] is safe for a vegan. A food with no tags is compatible with
/// no restricted diet.
///
/// [DietTag.halal] marks foods with no pork, no alcohol, and no non-halal meat.
/// Meat that would require certified slaughter is not tagged halal in V1 —
/// claiming certification the catalog cannot verify would be dishonest.
enum DietTag { vegan, vegetarian, pescatarian, halal }

/// Editorial lifecycle of a catalog record (master prompt §9.2).
///
/// Everything ships as [draft] until a qualified reviewer signs off. Nothing in
/// the app may present a `draft` record as professionally reviewed.
enum ContentStatus { draft, reviewed, published, retired }

/// Where a recipe sits in a training day (master prompt §9.1 composition floor).
enum MealType { breakfast, snack, lunch, dinner }

/// Timing relative to a session. [any] means the recipe carries no timing claim.
enum TrainingTiming { any, preTraining, postTraining }

/// Rough affordability band, used as a filter. Relative, not currency-pegged.
enum CostBand { low, medium, high }
