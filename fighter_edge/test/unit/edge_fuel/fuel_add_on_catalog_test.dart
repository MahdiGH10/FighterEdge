import 'dart:convert';
import 'dart:io';

import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_add_on.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/fuel_add_on_catalog.dart';
import 'package:fighter_edge/features/edge_fuel/domain/validation/fuel_add_on_validation.dart';
import 'package:flutter_test/flutter_test.dart';

/// Reads the shipped food table off disk, so the add-ons are checked against
/// the catalog as authored.
Future<Map<String, FoodItem>> _realFoods() async {
  final json = jsonDecode(
    await File('assets/data/edge_fuel_foods_v1.json').readAsString(),
  ) as Map<String, dynamic>;
  return {
    for (final raw in (json['foods'] as List).cast<Map<String, dynamic>>())
      raw['id'] as String: FoodItem.fromJson(raw),
  };
}

const _food = FoodItem(
  id: 'food',
  name: 'Food',
  category: FoodCategory.protein,
  kcalPer100g: 100,
  proteinPer100g: 20,
  carbsPer100g: 0,
  fatPer100g: 2,
  fibrePer100g: 0,
);

FuelAddOn _addOn({
  String id = 'a',
  String foodId = 'food',
  AddOnGroup group = AddOnGroup.meat,
  double grams = 100,
  AddOnUnit unit = AddOnUnit.gram,
  double? unitCount,
  String source = FuelAddOn.sourceCurated,
  int prep = 0,
}) =>
    FuelAddOn(
      id: id,
      foodId: foodId,
      group: group,
      grams: grams,
      unit: unit,
      unitCount: unitCount ?? grams,
      source: source,
      prepMinutes: prep,
    );

List<String> _messages(List<FuelAddOn> addOns) => [
      for (final issue
          in FuelAddOnValidator.validate(addOns, const {'food': _food}))
        issue.toString(),
    ];

void main() {
  group('the shipped add-on catalog', () {
    late Map<String, FoodItem> foods;

    setUpAll(() async {
      foods = await _realFoods();
    });

    test('is about 40 items and passes every record check', () {
      expect(FuelAddOnCatalog.all.length, inInclusiveRange(36, 50));
      expect(
        FuelAddOnValidator.validate(FuelAddOnCatalog.all, foods),
        isEmpty,
      );
    });

    test('covers every group with enough protein-rich items', () {
      expect(
        FuelAddOnValidator.validateComposition(FuelAddOnCatalog.all, foods),
        isEmpty,
      );
    });

    test('every add-on names its portion source', () {
      for (final addOn in FuelAddOnCatalog.all) {
        expect(
          addOn.source,
          anyOf(FuelAddOn.sourceCurated, FuelAddOn.sourceUsdaHousehold),
          reason: addOn.id,
        );
        // The nutrition source lives on the food record.
        expect(foods[addOn.foodId]!.source, isNotEmpty, reason: addOn.id);
      }
    });

    test('stays marked for dietitian sign-off', () {
      expect(FuelAddOnCatalog.dietitianSignOffPending, isTrue);
    });
  });

  group('add-on validator', () {
    test('accepts a clean record', () {
      expect(_messages([_addOn()]), isEmpty);
    });

    test('flags ids', () {
      expect(_messages([_addOn(id: '')]).single, contains('missing id'));
      expect(
        _messages([_addOn(), _addOn()]).single,
        contains('duplicate id'),
      );
    });

    test('flags portion weights and unit counts', () {
      expect(
        _messages([_addOn(grams: 0, unitCount: 1)]),
        contains(contains('portion has no weight')),
      );
      expect(
        _messages([_addOn(grams: 450)]),
        contains(contains('above')),
      );
      expect(
        _messages([_addOn(unit: AddOnUnit.piece, unitCount: 0)]),
        contains(contains('unit count must be positive')),
      );
      expect(
        _messages([_addOn(unitCount: 90)]),
        contains(contains('must state its own weight')),
      );
    });

    test('flags source, time, group and food problems', () {
      expect(
        _messages([_addOn(source: ' ')]),
        contains(contains('missing source')),
      );
      expect(
        _messages([_addOn(prep: -1)]),
        contains(contains('prep time cannot be negative')),
      );
      expect(
        _messages([_addOn(group: AddOnGroup.meal)]),
        contains(contains('reserved for recipes')),
      );
      expect(
        _messages([_addOn(foodId: 'nope')]).single,
        contains('unknown food'),
      );
    });

    test('flags an implausible portion energy', () {
      expect(
        _messages([_addOn(grams: 10)]),
        contains(contains('implausible')),
      );
    });

    test('flags a thin catalog', () {
      final issues = FuelAddOnValidator.validateComposition(
        [_addOn()],
        const {'food': _food},
      ).map((i) => i.message).toList();
      expect(issues, contains(contains('expected at least 36')));
      expect(issues, contains(contains('no add-on in group dairy')));
      expect(issues, contains(contains('protein-rich')));
      expect(issues, isNot(contains(contains('group meal'))));
    });
  });
}
