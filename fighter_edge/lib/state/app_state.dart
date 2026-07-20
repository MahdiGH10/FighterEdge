import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/data_repository.dart';
import '../data/mock_data.dart';
import '../models/meal.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';

/// Holds the mutable state for the three interactive features:
/// weight tracking and nutrition. (The round timer keeps local state.)
class AppState extends ChangeNotifier {
  AppState({DataRepository? dataRepository})
      : _dataRepository = dataRepository {
    unawaited(_loadSettings());
  }

  final DataRepository? _dataRepository;

  List<WeightEntry> _weights = MockData.seedWeights();
  List<Meal> _meals = MockData.seedMeals();
  List<TrainingSession> _sessions = List.of(MockData.week);
  DateTime _nutritionDate = DateTime.now();
  StreamSubscription<List<WeightEntry>>? _weightSub;
  StreamSubscription<List<Meal>>? _mealSub;
  StreamSubscription<List<TrainingSession>>? _sessionSub;
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

    final repo = _dataRepository;
    if (repo == null || userId == null) {
      _weights = MockData.seedWeights();
      _meals = MockData.seedMeals();
      _sessions = List.of(MockData.week);
      notifyListeners();
      return;
    }

    _weightSub = repo.watchWeights(userId).listen((weights) {
      _weights = List.of(weights);
      notifyListeners();
    });

    _watchMealsForCurrentDate(repo, userId);

    _sessionSub = repo.watchSessions(userId).listen((sessions) {
      _sessions = List.of(sessions);
      notifyListeners();
    });
  }

  // ---- Weight ----
  List<WeightEntry> get weights => List.unmodifiable(_sortedByDate);

  double get latestWeight => _weights.isEmpty ? 0 : _sortedByDate.last.kg;

  /// Change vs the previous weigh-in (negative = weight loss).
  double get weeklyDelta {
    final s = _sortedByDate;
    if (s.length < 2) return 0;
    return s.last.kg - s[s.length - 2].kg;
  }

  List<WeightEntry> get _sortedByDate =>
      [..._weights]..sort((a, b) => a.date.compareTo(b.date));

  /// History newest-first for the list view.
  List<WeightEntry> get weightHistoryDesc =>
      [..._weights]..sort((a, b) => b.date.compareTo(a.date));

  double get goalWeightKg => 74;

  double get weightToGoal =>
      latestWeight == 0 ? 0 : latestWeight - goalWeightKg;

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

  double displayWeight(double kg) => _useMetricUnits ? kg : kg * 2.2046226218;

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
    if (repo == null || userId == null) {
      _meals = isTodayNutrition ? MockData.seedMeals() : [];
      notifyListeners();
      return;
    }
    _mealSub?.cancel();
    _watchMealsForCurrentDate(repo, userId);
  }

  // ---- Training ----
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);

  int get completedSessionCount =>
      _sessions.where((session) => session.completed).length;

  List<TrainingSession> get completedSessionsDesc {
    final completed = _sessions.where((s) => s.completed).toList();
    completed.sort((a, b) {
      final aDate = a.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bDate = b.completedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bDate.compareTo(aDate);
    });
    return List.unmodifiable(completed);
  }

  int get currentStreakDays {
    final completedDays = {
      for (final session in _sessions.where((s) => s.completed))
        mealDateKey(session.completedAt ?? DateTime.now()),
    };
    var streak = 0;
    var cursor = DateTime.now();
    while (completedDays.contains(mealDateKey(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  void toggleSession(TrainingSession session) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) return;
    completeSession(session, completed: !session.completed);
  }

  void completeSession(
    TrainingSession session, {
    bool completed = true,
    int rpe = 7,
    String note = '',
  }) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) return;
    final updated = session.copyWith(
      completed: completed,
      completedAt: completed ? DateTime.now() : null,
      clearCompletedAt: !completed,
      rpe: completed ? rpe.clamp(1, 10) : 0,
      note: completed ? note.trim() : '',
    );
    _sessions[index] = updated;
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(repo.saveSession(userId, updated));
    }
    notifyListeners();
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
    super.dispose();
  }

  void _watchMealsForCurrentDate(DataRepository repo, String userId) {
    _mealSub = repo.watchMeals(userId, _nutritionDate).listen((meals) {
      _meals = List.of(meals);
      notifyListeners();
    });
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
