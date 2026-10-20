import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_repository.dart';
import '../data/mock_data.dart';
import '../features/training_plan/data/legacy_session_slot.dart';
import '../models/meal.dart';
import '../models/training_log_entry.dart';
import '../models/weight_entry.dart';
import 'sync_tracker.dart';

/// Holds the mutable state for the three interactive features:
/// weight tracking and nutrition. (The round timer keeps local state.)
class AppState extends ChangeNotifier {
  AppState({
    DataRepository? dataRepository,
    DateTime Function()? clock,
    SyncTracker? sync,
  })  : _dataRepository = dataRepository,
        _sync = sync ?? SyncTracker(),
        _clock = clock ?? DateTime.now,
        _weights = dataRepository == null ? MockData.seedWeights() : [],
        _meals = dataRepository == null ? MockData.seedMeals() : [],
        _log = [] {
    _resortWeights();
    unawaited(_loadSettings());
  }

  final DataRepository? _dataRepository;

  /// Where refused writes are recorded for the "not saved" notice. Every
  /// write below goes through [SyncTracker.run] instead of being
  /// fire-and-forget.
  final SyncTracker _sync;

  /// Injected so tests can move through weeks without waiting for them.
  final DateTime Function() _clock;

  /// The same clock used to date training history and evaluate its streak.
  DateTime get now => _clock();

  List<WeightEntry> _weights;

  /// [_weights] sorted both ways, recomputed only when it changes (audit
  /// P-4) — every screen that reads `weights`/`weightHistoryDesc` used to
  /// re-sort the whole list on every call, and the weight tracker's history
  /// row called `weightHistoryDesc` once per row, making one screen O(n²).
  List<WeightEntry> _weightsAsc = const [];
  List<WeightEntry> _weightsDesc = const [];

  void _resortWeights() {
    _weightsAsc = [..._weights]..sort((a, b) => a.date.compareTo(b.date));
    _weightsDesc = [..._weights]..sort((a, b) => b.date.compareTo(a.date));
  }

  List<Meal> _meals;

  /// The old weekday-string schedule, kept only so completions stored on it
  /// can be moved into the log once. The plan itself lives in
  /// `PlanController`.
  List<LegacySessionSlot> _legacySlots = [];

  /// Every piece of training ever logged, newest first.
  List<TrainingLogEntry> _log;
  DateTime _nutritionDate = DateTime.now();
  StreamSubscription<List<WeightEntry>>? _weightSub;
  StreamSubscription<List<Meal>>? _mealSub;
  StreamSubscription<List<LegacySessionSlot>>? _sessionSub;
  StreamSubscription<List<TrainingLogEntry>>? _logSub;
  bool _sessionsLoaded = false;
  bool _logLoaded = false;
  String? _migratedFor;
  String? _userId;
  bool _useMetricUnits = true;
  bool _timerHaptics = true;
  bool _campReminders = false;
  bool _safeCutGuidance = true;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _sync.clear();
    _userId = userId;
    _weightSub?.cancel();
    _mealSub?.cancel();
    _sessionSub?.cancel();
    _logSub?.cancel();
    _sessionsLoaded = false;
    _logLoaded = false;

    final repo = _dataRepository;
    if (repo == null) {
      // No repository at all: the offline demo (main_local.dart, previews,
      // tests that construct AppState with no arguments). Real MockData is
      // fine here — nothing else could ever be shown.
      _weights = MockData.seedWeights();
      _meals = MockData.seedMeals();
      _legacySlots = [];
      _log = [];
      _resortWeights();
      notifyListeners();
      return;
    }
    if (userId == null) {
      // Signed out, or not yet resolved at startup. A real repository exists,
      // so this must never fall back to MockData: a slow first launch would
      // otherwise show fabricated numbers as if they were the user's, and
      // keep showing them after sign-in until the first snapshot arrives
      // (audit A-3). Empty is the only honest state here.
      _weights = [];
      _meals = [];
      _legacySlots = [];
      _log = [];
      _resortWeights();
      notifyListeners();
      return;
    }

    _weightSub = repo.watchWeights(userId).listen(
      (weights) {
        _weights = List.of(weights);
        _resortWeights();
        notifyListeners();
      },
      onError: (Object error) {
        // The last known weights stay on screen; a listener error is not
        // fatal and Firestore keeps retrying the subscription itself.
        if (kDebugMode) debugPrint('[app_state] weights stream error: $error');
      },
    );

    _watchMealsForCurrentDate(repo, userId);

    _sessionSub = repo.watchLegacySessions(userId).listen(
      (sessions) {
        _legacySlots = List.of(sessions);
        _sessionsLoaded = true;
        _migrateLegacyCompletions(repo, userId);
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) debugPrint('[app_state] sessions stream error: $error');
      },
    );

    _logSub = repo.watchTrainingLog(userId).listen(
      (log) {
        _log = List.of(log);
        _logLoaded = true;
        _migrateLegacyCompletions(repo, userId);
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) {
          debugPrint('[app_state] training log stream error: $error');
        }
      },
    );
  }

  // ---- Weight ----
  List<WeightEntry> get weights => List.unmodifiable(_weightsAsc);

  double get latestWeight => _weightsAsc.isEmpty ? 0 : _weightsAsc.last.kg;

  /// Change vs the previous weigh-in (negative = weight loss).
  double get weeklyDelta {
    final s = _weightsAsc;
    if (s.length < 2) return 0;
    return s.last.kg - s[s.length - 2].kg;
  }

  /// History newest-first for the list view.
  List<WeightEntry> get weightHistoryDesc => List.unmodifiable(_weightsDesc);

  double get sevenDayAverage {
    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final recent = _weights.where((w) => !w.date.isBefore(cutoff)).toList();
    final source = recent.isEmpty ? _weights : recent;
    if (source.isEmpty) return 0;
    return source.fold<double>(0, (sum, entry) => sum + entry.kg) /
        source.length;
  }

  void addWeight(DateTime date, double kg) {
    final entry = WeightEntry(date, kg);
    _weights.add(entry);
    _resortWeights();
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(_sync.run('weight-${entry.stableId}', 'weight_save_failed',
          () => repo.addWeight(userId, entry)));
    }
    notifyListeners();
  }

  // ---- Settings ----
  bool get useMetricUnits => _useMetricUnits;
  bool get timerHaptics => _timerHaptics;
  bool get campReminders => _campReminders;
  bool get safeCutGuidance => _safeCutGuidance;

  String get weightUnitLabel => _useMetricUnits ? 'kg' : 'lb';

  static const double _lbPerKg = 2.2046226218;

  /// Kilograms (how weight is stored) into the unit the user reads in.
  double displayWeight(double kg) => _useMetricUnits ? kg : kg * _lbPerKg;

  /// The reverse: a number the user typed, in their unit, back into kg.
  double weightToKg(double displayed) =>
      _useMetricUnits ? displayed : displayed / _lbPerKg;

  Future<void> setUseMetricUnits(bool value) async {
    _useMetricUnits = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.useMetricUnits', value);
  }

  Future<void> setTimerHaptics(bool value) async {
    _timerHaptics = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.timerHaptics', value);
  }

  Future<void> setCampReminders(bool value) async {
    _campReminders = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.campReminders', value);
  }

  Future<void> setSafeCutGuidance(bool value) async {
    _safeCutGuidance = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('settings.safeCutGuidance', value);
  }

  // ---- Nutrition ----
  List<Meal> get meals => List.unmodifiable(_meals);
  MacroTarget get target => MockData.macroTarget;
  DateTime get nutritionDate => _nutritionDate;
  bool get isTodayNutrition =>
      mealDateKey(_nutritionDate) == mealDateKey(DateTime.now());

  int get consumedCalories =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.calories);
  int get consumedProtein =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.protein);
  int get consumedCarbs =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.carbs);
  int get consumedFats =>
      _meals.where((m) => m.eaten).fold(0, (s, m) => s + m.fats);

  void toggleMeal(Meal meal) {
    meal.eaten = !meal.eaten;
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(_sync.run('meals', 'meals_save_failed',
          () => repo.saveMealsForDate(userId, _nutritionDate, _meals)));
    }
    notifyListeners();
  }

  void addMeal(Meal meal) {
    _meals.add(meal);
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(_sync.run('meals', 'meals_save_failed',
          () => repo.saveMealsForDate(userId, _nutritionDate, _meals)));
    }
    notifyListeners();
  }

  void shiftNutritionDate(int days) {
    _nutritionDate =
        DateTime(_nutritionDate.year, _nutritionDate.month, _nutritionDate.day)
            .add(Duration(days: days));
    final repo = _dataRepository;
    final userId = _userId;
    if (repo == null) {
      _meals = isTodayNutrition ? MockData.seedMeals() : [];
      notifyListeners();
      return;
    }
    if (userId == null) {
      _meals = [];
      notifyListeners();
      return;
    }
    _mealSub?.cancel();
    _watchMealsForCurrentDate(repo, userId);
  }

  // ---- Training ----

  /// Every piece of training ever logged, newest first. What the plan says
  /// should happen lives in `PlanController`; this is what did.
  List<TrainingLogEntry> get trainingLog => List.unmodifiable(_log);

  /// The calendar days (see `mealDateKey`) with training that counts toward
  /// the weekly target and streak, across every week, not only this one.
  Set<String> get trainingDayKeys => {
        for (final entry in _log)
          if (entry.source.countsAsTrainingDay) entry.dateKey,
      };

  /// All-time count of logged sessions that count as training.
  int get completedSessionCount =>
      _log.where((entry) => entry.source.countsAsTrainingDay).length;

  /// Adds an entry to the log, or replaces the one with the same id.
  void addTrainingLogEntry(TrainingLogEntry entry) {
    _upsertLocal(entry);
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(_sync.run('log-${entry.id}', 'training_log_save_failed',
          () => repo.saveTrainingLogEntry(userId, entry)));
    }
    notifyListeners();
  }

  /// Removes the entry with [entryId], if there is one.
  void removeTrainingLogEntry(String entryId) {
    final before = _log.length;
    _log.removeWhere((entry) => entry.id == entryId);
    if (_log.length == before) return;
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(_sync.run('log-$entryId', 'training_log_delete_failed',
          () => repo.deleteTrainingLogEntry(userId, entryId)));
    }
    notifyListeners();
  }

  void _upsertLocal(TrainingLogEntry entry) {
    _log
      ..removeWhere((item) => item.id == entry.id)
      ..add(entry)
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  /// One-time move of completions stored on the old weekly-plan documents
  /// into the log. Before the log existed, a completed slot kept its only
  /// record in `completed`/`completedAt` on the slot itself.
  ///
  /// Runs once both streams have delivered. Each entry gets a deterministic
  /// id, so a second run writes the same document instead of a duplicate.
  /// Once an entry is saved, the slot's completion is cleared: the data now
  /// lives in the log, and a device with a stale cache can then never
  /// re-migrate old values over an entry the athlete has since edited.
  void _migrateLegacyCompletions(DataRepository repo, String userId) {
    if (!_sessionsLoaded || !_logLoaded || _migratedFor == userId) return;
    _migratedFor = userId;
    final known = {for (final entry in _log) entry.id};
    for (final slot in _legacySlots) {
      final completedAt = slot.completedAt;
      if (!slot.completed || completedAt == null) continue;
      final entry = TrainingLogEntry(
        id: TrainingLogEntry.plannedId(slot.id, completedAt),
        completedAt: completedAt,
        source: TrainingSource.planned,
        title: slot.title,
        planSlotId: slot.id,
        rpe: slot.rpe,
        note: slot.note,
      );
      final isNew = !known.contains(entry.id);
      if (isNew) _upsertLocal(entry);
      final cleared = slot.cleared();
      unawaited(() async {
        try {
          if (isNew) await repo.saveTrainingLogEntry(userId, entry);
          await repo.saveLegacySession(userId, cleared);
        } catch (_) {
          // Left as it was; the next launch tries again, and the
          // deterministic id keeps that safe.
        }
      }());
    }
  }

  /// Clears the weight and meal history for a new camp, optionally with a
  /// first weigh-in. The training plan is made separately
  /// (`PlanController.startFresh`).
  Future<void> startFreshCamp({required double? startingWeightKg}) async {
    final repo = _dataRepository;
    final userId = _userId;

    _weights = [];
    if (startingWeightKg != null && startingWeightKg > 0) {
      final entry = WeightEntry(DateTime.now(), startingWeightKg);
      _weights.add(entry);
      if (repo != null && userId != null) {
        unawaited(_sync.run('weight-${entry.stableId}', 'weight_save_failed',
            () => repo.addWeight(userId, entry)));
      }
    }
    _resortWeights();

    _meals = [];
    if (repo != null && userId != null) {
      unawaited(_sync.run('meals', 'meals_save_failed',
          () => repo.saveMealsForDate(userId, _nutritionDate, const [])));
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _weightSub?.cancel();
    _mealSub?.cancel();
    _sessionSub?.cancel();
    _logSub?.cancel();
    super.dispose();
  }

  void _watchMealsForCurrentDate(DataRepository repo, String userId) {
    _mealSub = repo.watchMeals(userId, _nutritionDate).listen(
      (meals) {
        _meals = List.of(meals);
        notifyListeners();
      },
      onError: (Object error) {
        if (kDebugMode) debugPrint('[app_state] meals stream error: $error');
      },
    );
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _useMetricUnits = prefs.getBool('settings.useMetricUnits') ?? true;
      _timerHaptics = prefs.getBool('settings.timerHaptics') ?? true;
      _campReminders = prefs.getBool('settings.campReminders') ?? false;
      _safeCutGuidance = prefs.getBool('settings.safeCutGuidance') ?? true;
      notifyListeners();
    } catch (_) {
      // Pure unit tests may construct AppState before Flutter services are
      // initialized. Keep safe defaults instead of making domain logic depend
      // on platform storage.
    }
  }
}
