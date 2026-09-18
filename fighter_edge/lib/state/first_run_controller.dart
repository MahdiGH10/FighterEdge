import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers where a brand-new account is in its first week: whether the tour
/// has run, whether the first win (one logged meal) has landed, and whether the
/// checklist has been put away.
///
/// Everything is keyed per user and stored on the device. None of it is
/// account data worth syncing — at worst a reinstall shows a finished user
/// nothing, because [isActive] only turns on when this device ran setup.
class FirstRunController extends ChangeNotifier {
  String? _userId;
  bool _loaded = false;
  bool _active = false;
  bool _tourDone = false;
  bool _firstMealLogged = false;
  bool _remindersAsked = false;
  bool _checklistDismissed = false;

  /// Guards against a slow load for a previous user landing after a switch.
  int _generation = 0;

  static String _key(String userId, String field) =>
      'fe_first_run.$userId.$field';

  /// True while the first-week experience should be on screen. Off for every
  /// account that finished setup before this existed, so an app update never
  /// greets a veteran with a beginner's checklist.
  bool get isActive => _loaded && _active && !_checklistDismissed;
  bool get tourDone => _tourDone;
  bool get firstMealLogged => _firstMealLogged;
  bool get remindersAsked => _remindersAsked;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loaded = false;
    _active = false;
    _tourDone = false;
    _firstMealLogged = false;
    _remindersAsked = false;
    _checklistDismissed = false;
    final generation = ++_generation;
    notifyListeners();
    if (userId != null) _load(userId, generation);
  }

  Future<void> _load(String userId, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      _active = prefs.getBool(_key(userId, 'active')) ?? false;
      _tourDone = prefs.getBool(_key(userId, 'tourDone')) ?? false;
      _firstMealLogged = prefs.getBool(_key(userId, 'firstMeal')) ?? false;
      _remindersAsked = prefs.getBool(_key(userId, 'remindersAsked')) ?? false;
      _checklistDismissed = prefs.getBool(_key(userId, 'dismissed')) ?? false;
    } catch (_) {
      // Storage unavailable: behave as a finished user rather than risk
      // showing the first-run layer on every launch.
    }
    if (generation != _generation) return;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _set(String field, bool value) async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key(userId, field), value);
    } catch (_) {
      // In-memory state still moves on; the worst case is a repeat next launch.
    }
  }

  /// Turns the first-week experience on. Called once, as setup completes.
  Future<void> begin() async {
    _loaded = true;
    _active = true;
    notifyListeners();
    await _set('active', true);
  }

  Future<void> markTourDone() async {
    if (_tourDone) return;
    _tourDone = true;
    notifyListeners();
    await _set('tourDone', true);
  }

  /// Records the first logged meal. Returns true only the first time, so the
  /// celebration fires once however many meals follow.
  bool markFirstMealLogged() {
    if (_firstMealLogged) return false;
    _firstMealLogged = true;
    notifyListeners();
    _set('firstMeal', true);
    return true;
  }

  Future<void> markRemindersAsked() async {
    if (_remindersAsked) return;
    _remindersAsked = true;
    notifyListeners();
    await _set('remindersAsked', true);
  }

  Future<void> dismissChecklist() async {
    _checklistDismissed = true;
    notifyListeners();
    await _set('dismissed', true);
  }
}
