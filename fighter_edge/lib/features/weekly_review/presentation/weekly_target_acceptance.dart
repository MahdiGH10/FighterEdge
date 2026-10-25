import '../../edge_fuel/data/edge_fuel_repository.dart';
import '../../edge_fuel/domain/models/nutrition_profile.dart';
import '../../edge_fuel/domain/models/nutrition_target.dart';
import '../../training_plan/presentation/plan_controller.dart';
import '../domain/target_adjustment.dart';

/// Commits the new target and accepted decision before updating the live plan.
/// An unsafe step or a failed batch leaves the old target and review open.
class WeeklyTargetAcceptance {
  const WeeklyTargetAcceptance._();

  static Future<bool> accept({
    required EdgeFuelRepository repository,
    required PlanController plan,
    required String userId,
    required DateTime weekStart,
    required NutritionTarget target,
    required NutritionProfile profile,
    required int deltaKcal,
    required DateTime now,
  }) async {
    final adjusted =
        TargetAdjustment.apply(target, deltaKcal, profile: profile, now: now);
    final prepared = plan.prepareAcceptedReview(weekStart);
    if (adjusted == null || prepared == null) return false;
    await repository.saveAcceptedReview(userId, adjusted, prepared, weekStart);
    plan.adoptCommittedReview(userId, weekStart);
    return true;
  }
}
