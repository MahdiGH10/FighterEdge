import '../calculators/recipe_nutrient_calculator.dart';
import '../models/food_item.dart';
import '../models/fuel_add_on.dart';
import 'catalog_validation.dart';

/// Validates the curated add-on list against the food catalog it points into.
///
/// Like the other catalog validators, these are content-integrity checks that
/// run in unit tests so a bad record fails CI. They cannot say a portion is
/// the right size for an athlete; a dietitian does that.
class FuelAddOnValidator {
  FuelAddOnValidator._();

  /// Sanity bounds for one portion. An add-on outside them is almost certainly
  /// a gram typo, or a meal rather than an add-on.
  static const double minPortionKcal = 20;
  static const double maxPortionKcal = 600;
  static const double maxPortionGrams = 400;

  /// The list is "about 40" items. A floor stops it being gutted unnoticed.
  static const int minimumItems = 36;

  /// Protein-rich means at least this many grams of protein per portion.
  static const double proteinRichGrams = 15;
  static const int minimumProteinRich = 12;

  static List<CatalogIssue> validate(
    List<FuelAddOn> addOns,
    Map<String, FoodItem> foods,
  ) {
    final issues = <CatalogIssue>[];
    final seen = <String>{};

    for (var i = 0; i < addOns.length; i++) {
      final addOn = addOns[i];
      final id = addOn.id.isEmpty ? '<index $i>' : addOn.id;

      if (addOn.id.isEmpty) {
        issues.add(CatalogIssue(id, 'missing id'));
      } else if (!seen.add(addOn.id)) {
        issues.add(CatalogIssue(id, 'duplicate id'));
      }

      if (addOn.grams <= 0 || !addOn.grams.isFinite) {
        issues.add(CatalogIssue(id, 'portion has no weight'));
      } else if (addOn.grams > maxPortionGrams) {
        issues.add(
          CatalogIssue(id, 'portion of ${addOn.grams} g is above '
              '$maxPortionGrams g'),
        );
      }
      if (addOn.unitCount <= 0 || !addOn.unitCount.isFinite) {
        issues.add(CatalogIssue(id, 'unit count must be positive'));
      }
      if (addOn.unit == AddOnUnit.gram && addOn.unitCount != addOn.grams) {
        issues.add(
          CatalogIssue(id, 'a gram portion must state its own weight '
              '(${addOn.unitCount} vs ${addOn.grams} g)'),
        );
      }
      if (addOn.prepMinutes < 0) {
        issues.add(CatalogIssue(id, 'prep time cannot be negative'));
      }
      if (addOn.group == AddOnGroup.meal) {
        issues.add(CatalogIssue(id, 'meal is reserved for recipes'));
      }

      final food = foods[addOn.foodId];
      if (food == null) {
        issues.add(CatalogIssue(id, 'unknown food "${addOn.foodId}"'));
        continue;
      }
      if (addOn.grams > 0) {
        final nutrients = RecipeNutrientCalculator.forFood(food, addOn.grams);
        if (nutrients.kcal < minPortionKcal ||
            nutrients.kcal > maxPortionKcal) {
          issues.add(
            CatalogIssue(
              id,
              'implausible ${nutrients.kcal.toStringAsFixed(0)} kcal per '
              'portion (expected $minPortionKcal-$maxPortionKcal)',
            ),
          );
        }
      }
    }
    return issues;
  }

  /// Checks that the list as a whole can still serve a gap: every group but
  /// [AddOnGroup.meal] is present and enough items are protein-rich.
  static List<CatalogIssue> validateComposition(
    List<FuelAddOn> addOns,
    Map<String, FoodItem> foods,
  ) {
    final issues = <CatalogIssue>[];
    if (addOns.length < minimumItems) {
      issues.add(CatalogIssue(
        '<catalog>',
        '${addOns.length} add-ons, expected at least $minimumItems',
      ));
    }
    for (final group in AddOnGroup.values) {
      if (group == AddOnGroup.meal) continue;
      if (!addOns.any((a) => a.group == group)) {
        issues.add(CatalogIssue('<catalog>', 'no add-on in group ${group.name}'));
      }
    }
    var proteinRich = 0;
    for (final addOn in addOns) {
      final food = foods[addOn.foodId];
      if (food == null) continue;
      final protein =
          RecipeNutrientCalculator.forFood(food, addOn.grams).proteinGrams;
      if (protein >= proteinRichGrams) proteinRich++;
    }
    if (proteinRich < minimumProteinRich) {
      issues.add(CatalogIssue(
        '<catalog>',
        '$proteinRich protein-rich add-ons, expected at least '
        '$minimumProteinRich',
      ));
    }
    return issues;
  }
}
