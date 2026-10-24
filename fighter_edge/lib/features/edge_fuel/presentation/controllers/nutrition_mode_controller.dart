import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../domain/policies/nutrition_display_mode.dart';

/// The athlete's chosen [NutritionDisplayMode], remembered on the device for
/// the signed-in account.
///
/// Device-local on purpose: it says something about the athlete's health
/// habits, so it is never synced, sent to analytics or written to a log.
///
/// Until the stored choice has been read, [visible] is false: a paused athlete
/// must never see a flash of numbers while the app starts. Screens that gate
/// on it show nothing nutrition-shaped until [loaded].
class NutritionModeController extends ChangeNotifier {
  NutritionModeController({SharedPreferences? preferences})
      : _preferences = preferences;

  final SharedPreferences? _preferences;

  String? _userId;
  NutritionDisplayMode _mode = NutritionDisplayMode.normal;
  bool _loaded = true; // no account yet: nothing stored, nothing to hide

  /// Guards against a slow load for a previous user landing after a switch.
  int _generation = 0;

  static String _key(String userId) => 'fe_nutrition_mode.$userId';

  NutritionDisplayMode get mode => _mode;
  bool get loaded => _loaded;

  /// Nutrition may be shown right now: the choice is known and it is not
  /// paused.
  bool get visible => _loaded && _mode.showsNutrition;

  /// Numbers may be shown right now.
  bool get numbersVisible => _loaded && _mode.showsNumbers;

  /// Nutrition reminders may be sent. False until the choice is known, so a
  /// reminder is never scheduled on a guess.
  bool get remindersAllowed => _loaded && _mode.allowsNutritionReminders;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _mode = NutritionDisplayMode.normal;
    // With no account there is nothing stored to honor and no nutrition screen
    // to protect, so the answer is known at once.
    _loaded = userId == null;
    final generation = ++_generation;
    notifyListeners();
    if (userId != null) _load(userId, generation);
  }

  Future<void> _load(String userId, int generation) async {
    var mode = NutritionDisplayMode.normal;
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      mode = NutritionDisplayMode.fromStorage(prefs.getString(_key(userId)));
    } catch (_) {
      // Storage unavailable: the shipped behavior. There is nothing stored to
      // honor, and failing closed would hide the app from everyone.
    }
    if (generation != _generation) return;
    _mode = mode;
    _loaded = true;
    notifyListeners();
  }

  /// Switches the mode and remembers it.
  Future<void> setMode(NutritionDisplayMode mode) async {
    final userId = _userId;
    if (userId == null || mode == _mode) return;
    _mode = mode;
    _loaded = true;
    notifyListeners();
    try {
      final prefs = _preferences ?? await SharedPreferences.getInstance();
      await prefs.setString(_key(userId), mode.storageName);
    } catch (_) {
      // The choice still applies for this run.
    }
  }
}
