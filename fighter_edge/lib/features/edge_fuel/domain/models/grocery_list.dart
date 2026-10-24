import 'food_enums.dart';

/// One line on the grocery list: a food and the total grams to buy.
class GroceryItem {
  final String foodId;

  /// Display name from the food catalog. Falls back to [foodId] when the
  /// catalog has no such food, so a line is never dropped.
  final String name;
  final FoodCategory category;

  /// Total grams over every recipe, rounded up to a whole gram.
  final int grams;

  /// Household label of the recipe line, e.g. `2 tbsp`. Display only. Set only
  /// when the food comes from a single recipe line cooked once; null once the
  /// grams are merged or scaled, because the label would no longer be true.
  final String? householdLabel;

  /// Ids of the recipes this line comes from, in plan order.
  final List<String> recipeIds;

  /// True when the food id is missing from the catalog.
  final bool unknownFood;

  final bool checked;

  const GroceryItem({
    required this.foodId,
    required this.name,
    required this.category,
    required this.grams,
    this.householdLabel,
    this.recipeIds = const [],
    this.unknownFood = false,
    this.checked = false,
  });

  GroceryItem copyWith({bool? checked}) => GroceryItem(
        foodId: foodId,
        name: name,
        category: category,
        grams: grams,
        householdLabel: householdLabel,
        recipeIds: recipeIds,
        unknownFood: unknownFood,
        checked: checked ?? this.checked,
      );

  Map<String, dynamic> toJson() => {
        'foodId': foodId,
        'name': name,
        'category': category.name,
        'grams': grams,
        if (householdLabel != null) 'householdLabel': householdLabel,
        'recipeIds': recipeIds,
        if (unknownFood) 'unknownFood': true,
        if (checked) 'checked': true,
      };

  factory GroceryItem.fromJson(Map<String, dynamic> json) {
    final category = FoodCategory.values.where(
      (c) => c.name == json['category'],
    );
    final grams = json['grams'];
    return GroceryItem(
      foodId: (json['foodId'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      category: category.isEmpty ? FoodCategory.other : category.first,
      grams: grams is num && grams.isFinite && grams > 0 ? grams.round() : 0,
      householdLabel: (json['householdLabel'] as String?)?.trim(),
      recipeIds: (json['recipeIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      unknownFood: json['unknownFood'] as bool? ?? false,
      checked: json['checked'] as bool? ?? false,
    );
  }
}

/// A merged shopping list for a set of recipes. Plain data: it stores locally
/// and works with no network.
class GroceryList {
  /// Sorted by food category, then name.
  final List<GroceryItem> items;

  /// Recipes left out because they are not published, in plan order.
  final List<String> skippedRecipeIds;

  const GroceryList({
    this.items = const [],
    this.skippedRecipeIds = const [],
  });

  bool get isEmpty => items.isEmpty;

  int get checkedCount => items.where((i) => i.checked).length;

  /// The list with [foodId] flipped between checked and not. An id that is not
  /// on the list leaves it unchanged.
  GroceryList toggled(String foodId) => GroceryList(
        items: [
          for (final i in items)
            i.foodId == foodId ? i.copyWith(checked: !i.checked) : i,
        ],
        skippedRecipeIds: skippedRecipeIds,
      );

  /// This list with the checked marks of [previous] carried over for foods
  /// that are still on it. Use after the recipe plan changes.
  GroceryList withChecksFrom(GroceryList previous) {
    final checked = {
      for (final i in previous.items)
        if (i.checked) i.foodId,
    };
    return GroceryList(
      items: [
        for (final i in items) i.copyWith(checked: checked.contains(i.foodId)),
      ],
      skippedRecipeIds: skippedRecipeIds,
    );
  }

  /// A plain-text list for sharing, one line per food, for example
  /// `- [ ] Chicken breast: 600 g`. A checked line shows `[x]`.
  String toPlainText() => items
      .map((i) => '- [${i.checked ? "x" : " "}] ${i.name}: ${i.grams} g')
      .join('\n');

  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'skippedRecipeIds': skippedRecipeIds,
      };

  factory GroceryList.fromJson(Map<String, dynamic> json) => GroceryList(
        items: (json['items'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .map(GroceryItem.fromJson)
            .where((i) => i.foodId.isNotEmpty && i.grams > 0)
            .toList(growable: false),
        skippedRecipeIds:
            (json['skippedRecipeIds'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(growable: false),
      );
}
