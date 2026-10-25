import 'dart:async';

import '../../../data/data_repository.dart';
import '../../../models/meal.dart';
import '../domain/models/food_log_entry.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_target.dart';
import '../../training_plan/data/stored_training_plan.dart';
import 'edge_fuel_repository.dart';

/// In-process fake used for tests and as the offline/unauthenticated
/// fallback. No disk or network I/O — state lives only as long as the
/// instance does.
class InMemoryEdgeFuelRepository implements EdgeFuelRepository {
  final Map<String, NutritionSetupDraft> _drafts = {};
  final Map<String, NutritionTarget> _targets = {};
  final Map<String, StoredTrainingPlan> _acceptedPlans = {};
  final Map<String, NutritionDay> _days = {};
  final Map<String, List<Meal>> _legacyMeals = {};
  final Map<String, StreamController<NutritionSetupDraft?>> _draftControllers =
      {};
  final Map<String, StreamController<NutritionTarget?>> _targetControllers = {};
  final Map<String, StreamController<NutritionDay>> _dayControllers = {};

  @override
  Stream<NutritionSetupDraft?> watchProfileDraft(String userId) {
    final controller = _draftControllers.putIfAbsent(
      userId,
      () => StreamController<NutritionSetupDraft?>.broadcast(
        onListen: () {},
      ),
    );
    scheduleMicrotask(() => controller.add(_drafts[userId]));
    return controller.stream;
  }

  @override
  Future<void> saveProfileDraft(
      String userId, NutritionSetupDraft draft) async {
    _drafts[userId] = draft;
    _draftControllers[userId]?.add(draft);
  }

  @override
  Stream<NutritionTarget?> watchTarget(String userId) {
    final controller = _targetControllers.putIfAbsent(
      userId,
      () => StreamController<NutritionTarget?>.broadcast(onListen: () {}),
    );
    scheduleMicrotask(() => controller.add(_targets[userId]));
    return controller.stream;
  }

  @override
  Future<void> saveTarget(String userId, NutritionTarget target) async {
    _targets[userId] = target;
    _targetControllers[userId]?.add(target);
  }

  @override
  Future<void> saveConfirmedPlan(
      String userId, NutritionSetupDraft draft, NutritionTarget target) async {
    _drafts[userId] = draft;
    _targets[userId] = target;
    _draftControllers[userId]?.add(draft);
    _targetControllers[userId]?.add(target);
  }

  @override
  Future<void> saveAcceptedReview(String userId, NutritionTarget target,
      StoredTrainingPlan plan, DateTime weekStart) async {
    _targets[userId] = target;
    _acceptedPlans[userId] = plan;
    _targetControllers[userId]?.add(target);
  }

  StoredTrainingPlan? acceptedReviewPlan(String userId) =>
      _acceptedPlans[userId];

  @override
  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) {
    final key = _dayKey(userId, localDate);
    final controller = _dayControllers.putIfAbsent(
      key,
      () => StreamController<NutritionDay>.broadcast(onListen: () {}),
    );
    scheduleMicrotask(() {
      controller.add(_days[key] ??
          _migratedOrEmptyDay(userId, localDate,
              targetSnapshot: targetSnapshot));
    });
    return controller.stream;
  }

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) async {
    final key = '$userId:${day.localDate}';
    final normalized = day.copyWith(
      entries: List.unmodifiable(day.entries),
      totals: FoodLogTotals.fromEntries(day.entries),
      loggingCoverage: _coverageFor(day.entries),
    );
    _days[key] = normalized;
    _dayControllers[key]?.add(normalized);
  }

  @override
  Future<void> upsertFoodEntry(
    String userId,
    String localDate,
    FoodLogEntry entry,
  ) async {
    final day = _dayForMutation(userId, localDate);
    await saveNutritionDay(
      userId,
      day.copyWith(entries: [
        for (final existing in day.entries)
          if (existing.id != entry.id) existing,
        entry,
      ]),
    );
  }

  @override
  Future<void> deleteFoodEntry(
    String userId,
    String localDate,
    String entryId,
  ) async {
    final day = _dayForMutation(userId, localDate);
    await saveNutritionDay(
      userId,
      day.copyWith(
        entries: day.entries.where((entry) => entry.id != entryId).toList(),
      ),
    );
  }

  NutritionDay _dayForMutation(String userId, String localDate) =>
      _days['$userId:$localDate'] ??
      _migratedOrEmptyDay(userId, DateTime.parse(localDate));

  Future<void> seedLegacyMeals(
    String userId,
    DateTime localDate,
    List<Meal> meals,
  ) async {
    _legacyMeals[_dayKey(userId, localDate)] = List.of(meals);
  }

  NutritionDay _migratedOrEmptyDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) {
    final key = _dayKey(userId, localDate);
    final now = DateTime.now();
    final legacy = _legacyMeals[key] ?? const <Meal>[];
    if (legacy.isEmpty) {
      return NutritionDay.empty(
        localDate: mealDateKey(localDate),
        timeZone: localDate.timeZoneName,
        now: now,
        targetSnapshot: targetSnapshot,
      );
    }
    final entries = [
      for (final meal in legacy)
        FoodLogEntry.fromMeal(meal,
            loggedAt:
                DateTime(localDate.year, localDate.month, localDate.day, 12))
    ];
    final day = NutritionDay.empty(
      localDate: mealDateKey(localDate),
      timeZone: localDate.timeZoneName,
      now: now,
      targetSnapshot: targetSnapshot,
    ).copyWith(
      entries: entries,
      migratedFromLegacyMeals: true,
      loggingCoverage: _coverageFor(entries),
    );
    _days[key] = day;
    return day;
  }

  String _dayKey(String userId, DateTime localDate) =>
      '$userId:${mealDateKey(localDate)}';

  String _coverageFor(List<FoodLogEntry> entries) {
    if (entries.isEmpty) return 'none';
    if (entries.length < 3) return 'partial';
    return 'full';
  }
}
