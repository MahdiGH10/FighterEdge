import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_target.dart';

/// Persistence boundary for EdgeFuel. Mirrors the existing `DataRepository`
/// convention (watchX returns a live stream, saveX writes) so the two
/// repositories read the same way throughout the app. Widgets never see a
/// Firebase type through this interface (master prompt §11).
abstract class EdgeFuelRepository {
  Stream<NutritionSetupDraft?> watchProfileDraft(String userId);

  Future<void> saveProfileDraft(String userId, NutritionSetupDraft draft);

  Stream<NutritionTarget?> watchTarget(String userId);

  Future<void> saveTarget(String userId, NutritionTarget target);

  Stream<NutritionDay> watchNutritionDay(
    String userId,
    DateTime localDate, {
    NutritionTarget? targetSnapshot,
  });

  Future<void> saveNutritionDay(String userId, NutritionDay day);
}
