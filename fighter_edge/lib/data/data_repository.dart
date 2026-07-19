import '../models/meal.dart';
import '../models/training_session.dart';
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

  Stream<List<TrainingSession>> watchSessions(String userId);

  Future<void> saveSession(String userId, TrainingSession session);
}

String mealDateKey(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return '${normalized.year.toString().padLeft(4, '0')}-'
      '${normalized.month.toString().padLeft(2, '0')}-'
      '${normalized.day.toString().padLeft(2, '0')}';
}
