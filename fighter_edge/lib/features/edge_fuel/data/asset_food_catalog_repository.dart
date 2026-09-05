import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../domain/models/food_item.dart';
import '../domain/validation/catalog_validation.dart';
import 'food_catalog_repository.dart';

/// Loads the bundled food table from `assets/data/edge_fuel_foods_v1.json`.
///
/// The asset is parsed once and cached for the process lifetime — the table is
/// immutable content, not user data.
class AssetFoodCatalogRepository implements FoodCatalogRepository {
  static const String assetPath = 'assets/data/edge_fuel_foods_v1.json';

  /// Injectable so tests can supply JSON without a widget binding or a real
  /// asset bundle.
  final Future<String> Function(String path) _loadString;

  List<FoodItem>? _cache;
  Map<String, FoodItem>? _byId;
  Future<List<FoodItem>>? _inFlight;

  AssetFoodCatalogRepository({Future<String> Function(String path)? loadString})
      : _loadString = loadString ?? rootBundle.loadString;

  @override
  Future<List<FoodItem>> loadAll() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    // Collapse concurrent first-callers onto one parse rather than racing.
    return _inFlight ??= _load();
  }

  Future<List<FoodItem>> _load() async {
    try {
      final raw = await _loadString(assetPath);
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('food catalog root must be an object');
      }
      final records = decoded['foods'];
      if (records is! List) {
        throw const FormatException('food catalog has no "foods" array');
      }

      final foods = records
          .whereType<Map<String, dynamic>>()
          .map(FoodItem.fromJson)
          .toList(growable: false);

      _assertValid(foods);

      _cache = foods;
      _byId = {for (final food in foods) food.id: food};
      return foods;
    } finally {
      _inFlight = null;
    }
  }

  /// Fails loudly in debug so a bad hand-authored record is caught while
  /// developing. Release builds do not crash a user's app over content drift —
  /// the same checks run in unit tests, which is where they are meant to bite
  /// (master prompt §9.2).
  void _assertValid(List<FoodItem> foods) {
    assert(() {
      final issues = FoodCatalogValidator.validate(foods);
      if (issues.isNotEmpty) {
        debugPrint('EdgeFuel food catalog has ${issues.length} issue(s):');
        for (final issue in issues) {
          debugPrint('  $issue');
        }
        throw StateError(
          'Invalid EdgeFuel food catalog: ${issues.length} issue(s). '
          'First: ${issues.first}',
        );
      }
      return true;
    }());
  }

  @override
  Future<FoodItem?> byId(String id) async {
    await loadAll();
    return _byId?[id];
  }

  @override
  Future<List<FoodItem>> search(String query, {int limit = 50}) async {
    final foods = await loadAll();
    final needle = query.trim().toLowerCase();
    final matches = needle.isEmpty
        ? foods
        : foods
            .where((food) => food.name.toLowerCase().contains(needle))
            .toList(growable: false);
    if (limit <= 0 || matches.length <= limit) return matches;
    return matches.sublist(0, limit);
  }
}
