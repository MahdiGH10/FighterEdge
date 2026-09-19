import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/models/food_log_entry.dart';

/// The foods an athlete logs again and again: the most recent distinct ones,
/// and the ones they starred.
///
/// Lives across days on purpose. Recents drawn only from the day on screen —
/// the previous behaviour — were empty every morning, which is exactly when
/// "log what I had yesterday" matters most. Stored per account on the device:
/// it is a convenience index over the real log, not the log itself.
class FoodMemory {
  FoodMemory(this.userId);

  final String userId;

  static const recentLimit = 12;

  final List<FoodLogEntry> _recent = [];
  final List<FoodLogEntry> _saved = [];

  String get _key => 'fe_food_memory.v1.$userId';

  List<FoodLogEntry> get recent => List.unmodifiable(_recent);
  List<FoodLogEntry> get saved => List.unmodifiable(_saved);

  static String keyOf(FoodLogEntry entry) => entry.name.trim().toLowerCase();

  bool isSaved(FoodLogEntry entry) =>
      _saved.any((s) => keyOf(s) == keyOf(entry));

  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final json = jsonDecode(raw) as Map<String, dynamic>;
      _recent
        ..clear()
        ..addAll(_decode(json['recent']));
      _saved
        ..clear()
        ..addAll(_decode(json['saved']));
    } catch (_) {
      // Unreadable memory starts empty; the log itself is unaffected.
    }
  }

  /// Moves [entry] to the front of the recents, replacing an older entry
  /// with the same name so the latest portion is the one offered back.
  void remember(FoodLogEntry entry) {
    if (keyOf(entry).isEmpty) return;
    _recent
      ..removeWhere((r) => keyOf(r) == keyOf(entry))
      ..insert(0, _template(entry));
    if (_recent.length > recentLimit) {
      _recent.removeRange(recentLimit, _recent.length);
    }
    _persist();
  }

  /// Returns whether the food is saved after the toggle.
  bool toggleSaved(FoodLogEntry entry) {
    final key = keyOf(entry);
    final wasSaved = _saved.any((s) => keyOf(s) == key);
    if (wasSaved) {
      _saved.removeWhere((s) => keyOf(s) == key);
    } else {
      _saved.insert(0, _template(entry));
    }
    _persist();
    return !wasSaved;
  }

  static FoodLogEntry _template(FoodLogEntry entry) => entry.copyWith(
        consumed: true,
        saved: false,
      );

  static List<FoodLogEntry> _decode(Object? raw) {
    if (raw is! List) return const [];
    final out = <FoodLogEntry>[];
    for (final item in raw) {
      try {
        out.add(FoodLogEntry.fromJson(Map<String, dynamic>.from(item as Map)));
      } catch (_) {
        // Skip a malformed item rather than dropping the whole list.
      }
    }
    return out;
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _key,
        jsonEncode({
          'recent': [for (final e in _recent) e.toJson()],
          'saved': [for (final e in _saved) e.toJson()],
        }),
      );
    } catch (_) {
      // Memory stays correct for this session either way.
    }
  }
}
