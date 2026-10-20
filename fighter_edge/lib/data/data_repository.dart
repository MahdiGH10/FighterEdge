import '../features/training_plan/data/legacy_session_slot.dart';
import '../features/training_plan/data/stored_training_plan.dart';
import '../models/meal.dart';
import '../models/training_log_entry.dart';
import '../models/weight_entry.dart';

abstract class DataRepository {
  Stream<List<WeightEntry>> watchWeights(String userId);

  Future<void> addWeight(String userId, WeightEntry entry);

  Stream<List<Meal>> watchMeals(String userId, DateTime date);

  Future<void> saveMealsForDate(
    String userId,
    DateTime date,
    List<Meal> meals,
  );

  /// The old weekday-string schedule. Read only to migrate it once to the
  /// dated plan and to move its completions into the log; nothing plans from
  /// it.
  Stream<List<LegacySessionSlot>> watchLegacySessions(String userId);

  Future<void> saveLegacySession(String userId, LegacySessionSlot session);

  /// The saved training plan (inputs and skip/move choices), or null before
  /// one exists. Its existence marks the one-time migration as done.
  Stream<StoredTrainingPlan?> watchTrainingPlan(String userId);

  Future<void> saveTrainingPlan(String userId, StoredTrainingPlan plan);

  /// Every logged training entry, newest first.
  Stream<List<TrainingLogEntry>> watchTrainingLog(String userId);

  /// Creates or replaces the entry with [TrainingLogEntry.id].
  Future<void> saveTrainingLogEntry(String userId, TrainingLogEntry entry);

  Future<void> deleteTrainingLogEntry(String userId, String entryId);
}

String mealDateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year.toString().padLeft(4, '0')}-'
      '${normalized.month.toString().padLeft(2, '0')}-'
      '${normalized.day.toString().padLeft(2, '0')}';
}
