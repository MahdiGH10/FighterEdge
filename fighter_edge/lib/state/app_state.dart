import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/data_repository.dart';
import '../data/mock_data.dart';
import '../models/meal.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';

/// Holds the mutable state for the three interactive features:
/// weight tracking and nutrition. (The round timer keeps local state.)
class AppState extends ChangeNotifier {
  AppState({DataRepository? dataRepository}) : _dataRepository = dataRepository;

  final DataRepository? _dataRepository;

  List<WeightEntry> _weights = MockData.seedWeights();
  List<Meal> _meals = MockData.seedMeals();
  List<TrainingSession> _sessions = List.of(MockData.week);
  StreamSubscription<List<WeightEntry>>? _weightSub;
  StreamSubscription<List<Meal>>? _mealSub;
  StreamSubscription<List<TrainingSession>>? _sessionSub;
  String? _userId;
  bool _seededWeightsForCurrentUser = false;
  bool _seededMealsForCurrentUser = false;
  bool _seededSessionsForCurrentUser = false;

  void setUser(String? userId) {
    if (_userId == userId) return;
    _userId = userId;
    _seededWeightsForCurrentUser = false;
    _seededMealsForCurrentUser = false;
    _seededSessionsForCurrentUser = false;
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
      if (weights.isEmpty && !_seededWeightsForCurrentUser) {
        _seededWeightsForCurrentUser = true;
        for (final entry in MockData.seedWeights()) {
          unawaited(repo.addWeight(userId, entry));
        }
        return;
      }
      _weights = List.of(weights);
      notifyListeners();
    });

    _mealSub = repo.watchMeals(userId, DateTime.now()).listen((meals) {
      if (meals.isEmpty && !_seededMealsForCurrentUser) {
        _seededMealsForCurrentUser = true;
        unawaited(repo.saveMealsForDate(
          userId,
          DateTime.now(),
          MockData.seedMeals(),
        ));
        return;
      }
      _meals = List.of(meals);
      notifyListeners();
    });

    _sessionSub = repo.watchSessions(userId).listen((sessions) {
      if (sessions.isEmpty && !_seededSessionsForCurrentUser) {
        _seededSessionsForCurrentUser = true;
        for (final session in MockData.week) {
          unawaited(repo.saveSession(userId, session));
        }
        return;
      }
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

  // ---- Nutrition ----
  List<Meal> get meals => List.unmodifiable(_meals);
  MacroTarget get target => MockData.macroTarget;

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
      unawaited(repo.saveMealsForDate(userId, DateTime.now(), _meals));
    }
    notifyListeners();
  }

  // ---- Training ----
  List<TrainingSession> get sessions => List.unmodifiable(_sessions);

  int get completedSessionCount =>
      _sessions.where((session) => session.completed).length;

  void toggleSession(TrainingSession session) {
    final index = _sessions.indexWhere((item) => item.id == session.id);
    if (index == -1) return;
    final updated = session.copyWith(completed: !session.completed);
    _sessions[index] = updated;
    final repo = _dataRepository;
    final userId = _userId;
    if (repo != null && userId != null) {
      unawaited(repo.saveSession(userId, updated));
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
}
