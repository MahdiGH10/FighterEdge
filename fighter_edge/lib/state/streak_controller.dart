import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_repository.dart';
import 'streak_engine.dart';

/// Holds streak-freeze bookkeeping: how many freezes are banked, which days
/// have been protected by one, and when freezes were last earned.
///
/// Persisted per user on the device, the same way [FirstRunController] is —
/// this is a comfort feature riding on top of the training log, not billing
/// or account state, so device-local storage is the right weight for it.
class StreakController extends ChangeNotifier {
  String? _userId;
  bool _loaded = false;
  int _freezesAvailable = 0;
  Set<String> _protectedDateKeys = {};
  String? _lastEarnedWeekKey;
  int _generation = 0;

  static String _key(String userId, String field) => 'fe_streak.$userId.$field';

  bool get isLoaded => _loaded;
  int get freezesAvailable => _freezesAvailable;
  Set<String> get protectedDateKeys => Set.unmodifiable(_protectedDateKeys);

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _loaded = false;
    _freezesAvailable = 0;
    _protectedDateKeys = {};
    _lastEarnedWeekKey = null;
    final generation = ++_generation;
    notifyListeners();
    if (userId != null) _load(userId, generation);
  }

  Future<void> _load(String userId, int generation) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (generation != _generation) return;
      _freezesAvailable = prefs.getInt(_key(userId, 'freezes')) ?? 0;
      _protectedDateKeys =
          (prefs.getStringList(_key(userId, 'protected')) ?? const []).toSet();
      _lastEarnedWeekKey = prefs.getString(_key(userId, 'lastEarnedWeek'));
    } catch (_) {
      // No persisted state is a safe empty state, not a crash.
    }
    if (generation != _generation) return;
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final userId = _userId;
    if (userId == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_key(userId, 'freezes'), _freezesAvailable);
      await prefs.setStringList(
        _key(userId, 'protected'),
        _protectedDateKeys.toList(),
      );
      final week = _lastEarnedWeekKey;
      if (week != null) {
        await prefs.setString(_key(userId, 'lastEarnedWeek'), week);
      }
    } catch (_) {
      // In-memory state still moves on; worst case is a repeat next launch.
    }
  }

  /// Checks whether the week that just ended earned a freeze, and banks it if
  /// so. Cheap and idempotent — call it on every dashboard build; it only
  /// does real work once per calendar week per account.
  ///
  /// Evaluates the *previous* week, not the current one in progress, so a
  /// freeze is only ever earned for a week that is actually over — otherwise
  /// a user could bank a freeze mid-week and use it to cover a day in that
  /// same week, which would let a freeze extend a streak the user never
  /// actually put together.
  void syncWeeklyEarn({
    required Set<String> completedDateKeys,
    required bool isPro,
    DateTime? now,
  }) {
    if (!_loaded) return;
    final today = now ?? DateTime.now();
    final priorWeekStart =
        StreakEngine.weekStart(today).subtract(const Duration(days: 7));
    final priorWeekKey = StreakEngine.weekKey(priorWeekStart);
    if (_lastEarnedWeekKey == priorWeekKey) return;

    final daysCompleted =
        StreakEngine.daysCompletedInWeek(completedDateKeys, priorWeekStart);
    final earned =
        StreakEngine.freezesEarned(daysCompleted: daysCompleted, isPro: isPro);
    _lastEarnedWeekKey = priorWeekKey;
    if (earned > 0) {
      final cap = StreakEngine.freezeCap(isPro: isPro);
      _freezesAvailable = (_freezesAvailable + earned).clamp(0, cap);
    }
    notifyListeners();
    unawaited(_persist());
  }

  /// Spends a freeze to protect yesterday. Returns false and changes nothing
  /// if there is no freeze to spend.
  Future<bool> useFreezeForYesterday({DateTime? now}) async {
    if (_freezesAvailable <= 0) return false;
    final yesterday = (now ?? DateTime.now()).subtract(const Duration(days: 1));
    final key = mealDateKey(yesterday);
    if (_protectedDateKeys.contains(key)) return false;
    _freezesAvailable -= 1;
    _protectedDateKeys = {..._protectedDateKeys, key};
    notifyListeners();
    await _persist();
    return true;
  }
}
