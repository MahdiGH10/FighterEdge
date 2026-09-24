import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_repository.dart';
import '../data/mock_data.dart';
import '../models/meal.dart';
import '../models/training_log_entry.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';
import 'streak_engine.dart';

/// Holds the mutable state for the three interactive features:
/// weight tracking and nutrition. (The round timer keeps local state.)
class AppState extends ChangeNotifier {
  AppState({DataRepository? dataRepository, DateTime Function()? clock})
      : _dataRepository = dataRepository,
        _clock = clock ?? DateTime.now,
        _weights = dataRepository == null ? MockData.seedWeights() : [],
        _meals = dataRepository == null ? MockData.seedMeals() : [],
        _sessions = dataRepository == null ? List.of(MockData.week) : [],
        _log = [] {
    _resortWeights();
    if (dataRepository == null) _log = _demoLog(_sessions, _clock());
    unawaited(_loadSettings());
  }

  final DataRepository? _dataRepository;

  /// Injected so tests can move through weeks without waiting for them.
  final DateTime Function() _clock;

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

  /// The weekly plan: a template that repeats every week. Whether a slot is
  /// done is never stored on it; that comes from [_log], per week.
  List<TrainingSession> _sessions;

  /// Every piece of training ever logged, newest first.
  List<TrainingLogEntry> _log;
  DateTime _nutritionDate = DateTime.now();
  StreamSubscription<List<WeightEntry>>? _weightSub;
  StreamSubscription<List<Meal>>? _mealSub;
  StreamSubscription<List<TrainingSession>>? _sessionSub;
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
      _sessions = List.of(MockData.week);
      _log = _demoLog(_sessions, _clock());
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
      _sessions = [];
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

    _sessionSub = repo.watchSessions(userId).listen(
      (sessions) {
        _sessions = List.of(sessions);
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
      unawaited(repo.addWeight(userId, entry));
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
      unawaited(repo.saveMealsForDate(userId, _nutritionDate, _meals));
    }
    notifyListeners();
  }

  void addMeal(Meal meal) {
    _meals.add(meal);
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(repo.saveMealsForDate(userId, _nutritionDate, _meals));
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

  /// This week's plan: each slot's `completed`, `completedAt`, RPE and note
  /// come from this week's log entry for it, so the plan starts every Monday
  /// fresh while last week's work stays in the log.
  List<TrainingSession> get sessions =>
      List.unmodifiable([for (final slot in _sessions) _asThisWeek(slot)]);

  /// Every entry, newest first.
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

  /// The log, newest first, shaped as sessions for the History list and
  /// Recent activity.
  List<TrainingSession> get completedSessionsDesc => List.unmodifiable([
        for (final entry in _log) _asSession(entry),
      ]);

  void toggleSession(TrainingSession session) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) return;
    completeSession(session, completed: !_isDoneThisWeek(session.id));
  }

  /// Marks a plan slot done this week (or updates its RPE and note if it
  /// already is), or with `completed: false` removes this week's entry for
  /// it. Earlier weeks are never touched.
  void completeSession(
    TrainingSession session, {
    bool completed = true,
    int rpe = 7,
    String note = '',
  }) {
    final slot = _sessions.where((item) => item.id == session.id).firstOrNull;
    if (slot == null) return;
    final existing = _thisWeekEntryFor(slot.id);
    if (!completed) {
      if (existing == null) return;
      _log.removeWhere((entry) => entry.id == existing.id);
      final repo = _dataRepository;
      final userId = _userId;
      if (repo != null && userId != null) {
        unawaited(repo.deleteTrainingLogEntry(userId, existing.id));
      }
      notifyListeners();
      return;
    }
    final now = _clock();
    addTrainingLogEntry(
      existing?.copyWith(rpe: rpe.clamp(1, 10), note: note.trim()) ??
          TrainingLogEntry(
            id: TrainingLogEntry.plannedId(slot.id, now),
            completedAt: now,
            source: TrainingSource.planned,
            title: slot.title,
            planSlotId: slot.id,
            rpe: rpe.clamp(1, 10),
            note: note.trim(),
          ),
    );
  }

  /// Adds an entry to the log, or replaces the one with the same id.
  void addTrainingLogEntry(TrainingLogEntry entry) {
    _upsertLocal(entry);
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(repo.saveTrainingLogEntry(userId, entry));
    }
    notifyListeners();
  }

  bool _isDoneThisWeek(String slotId) => _thisWeekEntryFor(slotId) != null;

  /// The newest entry for [slotId] in the current Monday-to-Sunday week.
  TrainingLogEntry? _thisWeekEntryFor(String slotId) {
    final start = StreakEngine.weekStart(_clock());
    final end = start.add(const Duration(days: 7));
    for (final entry in _log) {
      if (entry.planSlotId != slotId) continue;
      if (entry.completedAt.isBefore(start)) continue;
      if (!entry.completedAt.isBefore(end)) continue;
      return entry; // _log is newest first
    }
    return null;
  }

  TrainingSession _asThisWeek(TrainingSession slot) {
    final entry = _thisWeekEntryFor(slot.id);
    return slot.copyWith(
      completed: entry != null,
      completedAt: entry?.completedAt,
      clearCompletedAt: entry == null,
      rpe: entry?.rpe ?? 0,
      note: entry?.note ?? '',
    );
  }

  /// A log entry dressed as a session, borrowing its plan slot's icon and
  /// subtitle when it has one.
  TrainingSession _asSession(TrainingLogEntry entry) {
    final slot =
        _sessions.where((item) => item.id == entry.planSlotId).firstOrNull;
    return TrainingSession(
      id: entry.id,
      day: slot?.day ?? '',
      title: entry.title,
      subtitle: slot?.subtitle ?? '',
      icon: slot?.icon ?? _sourceIcon(entry.source),
      completed: true,
      completedAt: entry.completedAt,
      rpe: entry.rpe,
      note: entry.note,
    );
  }

  static IconData _sourceIcon(TrainingSource source) => switch (source) {
        TrainingSource.planned => Icons.sports_mma,
        TrainingSource.timer => Icons.timer,
        TrainingSource.reaction => Icons.flash_on,
        TrainingSource.manual => Icons.fitness_center,
      };

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
    for (final slot in _sessions) {
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
      final cleared = slot.copyWith(
          completed: false, clearCompletedAt: true, rpe: 0, note: '');
      unawaited(() async {
        try {
          if (isNew) await repo.saveTrainingLogEntry(userId, entry);
          await repo.saveSession(userId, cleared);
        } catch (_) {
          // Left as it was; the next launch tries again, and the
          // deterministic id keeps that safe.
        }
      }());
    }
  }

  /// The offline demo's completed slots as log entries in the current week,
  /// never dated after now.
  static List<TrainingLogEntry> _demoLog(
      List<TrainingSession> week, DateTime now) {
    final monday = StreakEngine.weekStart(now);
    final entries = <TrainingLogEntry>[];
    for (final (index, slot) in week.indexed) {
      if (!slot.completed) continue;
      final day = monday.add(Duration(days: index, hours: 18));
      final completedAt = day.isAfter(now) ? now : day;
      entries.add(TrainingLogEntry(
        id: TrainingLogEntry.plannedId(slot.id, completedAt),
        completedAt: completedAt,
        source: TrainingSource.planned,
        title: slot.title,
        planSlotId: slot.id,
      ));
    }
    return entries..sort((a, b) => b.completedAt.compareTo(a.completedAt));
  }

  Future<void> startFreshCamp({
    required double? startingWeightKg,
    required int weeklyTrainingDays,
  }) async {
    final repo = _dataRepository;
    final userId = _userId;
    final sessions = _freshPlan(weeklyTrainingDays);

    _weights = [];
    if (startingWeightKg != null && startingWeightKg > 0) {
      final entry = WeightEntry(DateTime.now(), startingWeightKg);
      _weights.add(entry);
      if (repo != null && userId != null) {
        unawaited(repo.addWeight(userId, entry));
      }
    }
    _resortWeights();

    _meals = [];
    _sessions = sessions;
    if (repo != null && userId != null) {
      for (final session in sessions) {
        unawaited(repo.saveSession(userId, session));
      }
      unawaited(repo.saveMealsForDate(userId, _nutritionDate, const []));
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

  List<TrainingSession> _freshPlan(int weeklyTrainingDays) {
    final templates = [
      const TrainingSession(
        day: 'Mon',
        title: 'Striking',
        subtitle: 'Boxing fundamentals + combinations',
        icon: Icons.sports_mma,
        completed: false,
      ),
      const TrainingSession(
        day: 'Tue',
        title: 'Wrestling',
        subtitle: 'Entries, finishes + control',
        icon: Icons.sports_kabaddi,
        completed: false,
      ),
      const TrainingSession(
        day: 'Wed',
        title: 'Conditioning',
        subtitle: 'Intervals + core',
        icon: Icons.bolt,
        completed: false,
      ),
      const TrainingSession(
        day: 'Thu',
        title: 'BJJ',
        subtitle: 'Guard, transitions + submissions',
        icon: Icons.sports_martial_arts,
        completed: false,
      ),
      const TrainingSession(
        day: 'Fri',
        title: 'Strength',
        subtitle: 'Explosive upper/lower body',
        icon: Icons.fitness_center,
        completed: false,
      ),
      const TrainingSession(
        day: 'Sat',
        title: 'Recovery',
        subtitle: 'Mobility + easy zone 2',
        icon: Icons.spa,
        completed: false,
      ),
    ];
    return List.of(templates.take(weeklyTrainingDays.clamp(2, 6)));
  }
}
