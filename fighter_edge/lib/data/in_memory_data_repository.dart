import 'dart:async';

import '../models/meal.dart';
import '../models/training_session.dart';
import '../models/weight_entry.dart';
import 'data_repository.dart';
import 'mock_data.dart';

class InMemoryDataRepository implements DataRepository {
  final Map<String, List<WeightEntry>> _weights = {};
  final Map<String, Map<String, List<Meal>>> _meals = {};
  final Map<String, List<TrainingSession>> _sessions = {};

  final Map<String, StreamController<List<WeightEntry>>> _weightControllers =
      {};
  final Map<String, StreamController<List<Meal>>> _mealControllers = {};
  final Map<String, StreamController<List<TrainingSession>>>
      _sessionControllers = {};

  @override
  Stream<List<WeightEntry>> watchWeights(String userId) {
    _ensureUser(userId);
    final controller = _weightControllers.putIfAbsent(
      userId,
      () => StreamController<List<WeightEntry>>.broadcast(),
    );
    Future.microtask(() => controller.add(_sortedWeights(userId)));
    return controller.stream;
  }

  @override
  Future<void> addWeight(String userId, WeightEntry entry) async {
    _ensureUser(userId);
    _weights[userId]!.removeWhere((w) => w.stableId == entry.stableId);
    _weights[userId]!.add(entry);
    _weightControllers[userId]?.add(_sortedWeights(userId));
  }

  @override
  Stream<List<Meal>> watchMeals(String userId, DateTime date) {
    _ensureUser(userId);
    final key = _mealStreamKey(userId, date);
    final controller = _mealControllers.putIfAbsent(
      key,
      () => StreamController<List<Meal>>.broadcast(),
    );
    Future.microtask(() => controller.add(_mealsForDate(userId, date)));
    return controller.stream;
  }

  @override
  Future<void> saveMealsForDate(
    String userId,
    DateTime date,
    List<Meal> meals,
  ) async {
    _ensureUser(userId);
    _meals[userId]![mealDateKey(date)] = [for (final meal in meals) meal];
    _mealControllers[_mealStreamKey(userId, date)]
        ?.add(_mealsForDate(userId, date));
  }

  @override
  Stream<List<TrainingSession>> watchSessions(String userId) {
    _ensureUser(userId);
    final controller = _sessionControllers.putIfAbsent(
      userId,
      () => StreamController<List<TrainingSession>>.broadcast(),
    );
    Future.microtask(
        () => controller.add(List.unmodifiable(_sessions[userId]!)));
    return controller.stream;
  }

  @override
  Future<void> saveSession(String userId, TrainingSession session) async {
    _ensureUser(userId);
    final sessions = _sessions[userId]!;
    final existingIndex = sessions.indexWhere((s) => s.id == session.id);
    if (existingIndex == -1) {
      sessions.add(session);
    } else {
      sessions[existingIndex] = session;
    }
    _sessionControllers[userId]?.add(List.unmodifiable(sessions));
  }

  void dispose() {
    for (final controller in _weightControllers.values) {
      controller.close();
    }
    for (final controller in _mealControllers.values) {
      controller.close();
    }
    for (final controller in _sessionControllers.values) {
      controller.close();
    }
  }

  void _ensureUser(String userId) {
    _weights.putIfAbsent(userId, MockData.seedWeights);
    _meals.putIfAbsent(
        userId, () => {mealDateKey(DateTime.now()): MockData.seedMeals()});
    _sessions.putIfAbsent(userId, () => List.of(MockData.week));
  }

  List<WeightEntry> _sortedWeights(String userId) {
    return List.unmodifiable(
      [..._weights[userId]!]..sort((a, b) => a.date.compareTo(b.date)),
    );
  }

  List<Meal> _mealsForDate(String userId, DateTime date) {
    return List.unmodifiable(
      _meals[userId]![mealDateKey(date)] ?? MockData.seedMeals(),
    );
  }

  String _mealStreamKey(String userId, DateTime date) =>
      '$userId:${mealDateKey(date)}';
}
