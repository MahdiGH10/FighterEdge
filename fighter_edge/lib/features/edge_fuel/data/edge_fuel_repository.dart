import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/food_log_entry.dart';
import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_target.dart';
import '../../training_plan/data/stored_training_plan.dart';
import '../../../data/read_state.dart';

/// Persistence boundary for EdgeFuel. Mirrors the existing `DataRepository`
/// convention (watchX returns a live stream, saveX writes) so the two
/// repositories read the same way throughout the app. Widgets never see a
/// Firebase type through this interface (master prompt §11).
abstract class EdgeFuelRepository {
  Stream<NutritionSetupDraft?> watchProfileDraft(String userId);

  Future<void> saveProfileDraft(String userId, NutritionSetupDraft draft);

  Stream<NutritionTarget?> watchTarget(String userId);

  Future<void> saveTarget(String userId, NutritionTarget target);

  /// Commits both sides of setup together. A failed write must leave neither
  /// a confirmed draft nor a new target visible.
  Future<void> saveConfirmedPlan(
      String userId, NutritionSetupDraft draft, NutritionTarget target);

  /// Commits an accepted weekly calorie target and its review decision in
  /// one operation. The caller updates its in-memory plan only after success.
  Future<void> saveAcceptedReview(String userId, NutritionTarget target,
      StoredTrainingPlan plan, DateTime weekStart);

  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  });

  /// Legacy/fixture day seeding. Interactive food changes use the entry
  /// operations below so one device cannot replace another device's log.
  Future<void> saveNutritionDay(String userId, NutritionDay day);

  Future<void> upsertFoodEntry(
    String userId,
    String localDate,
    FoodLogEntry entry,
  );

  Future<void> deleteFoodEntry(String userId, String localDate, String entryId);
}

/// Uniform read status for every EdgeFuel repository implementation.
extension EdgeFuelRepositoryReads on EdgeFuelRepository {
  Stream<ReadState<NutritionSetupDraft?>> watchProfileDraftRead(
          String userId) =>
      readStates(watchProfileDraft(userId), isEmpty: (draft) => draft == null);

  Stream<ReadState<NutritionTarget?>> watchTargetRead(String userId) =>
      readStates(watchTarget(userId), isEmpty: (target) => target == null);

  Stream<ReadState<NutritionDay>> watchNutritionDayRead(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  }) =>
      readStates(
        watchNutritionDay(userId, localDate, targetSnapshot: targetSnapshot),
        isEmpty: (day) => day.entries.isEmpty,
      );
}
