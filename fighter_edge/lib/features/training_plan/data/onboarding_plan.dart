import '../domain/models/plan_inputs.dart';
import 'legacy_plan_migration.dart';
import 'stored_training_plan.dart';

/// The first plan, made when onboarding finishes.
///
/// Onboarding still asks for a number of days, goal and level, not which
/// weekdays or disciplines (that arrives with slice 5.5), so the days are
/// spread through the week and no discipline is assumed: every skill session
/// is a general one until the athlete says what they train.
class OnboardingPlan {
  OnboardingPlan._();

  /// Training weekdays for [days] sessions a week (clamped to 2-6), spread
  /// so hard days are not stacked.
  static Set<int> weekdaysFor(int days) => switch (days.clamp(2, 6)) {
        2 => {DateTime.monday, DateTime.thursday},
        3 => {DateTime.monday, DateTime.wednesday, DateTime.friday},
        4 => {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.thursday,
            DateTime.friday,
          },
        5 => {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
          },
        _ => {
            DateTime.monday,
            DateTime.tuesday,
            DateTime.wednesday,
            DateTime.thursday,
            DateTime.friday,
            DateTime.saturday,
          },
      };

  static StoredTrainingPlan create({
    required int weeklyTrainingDays,
    required String goal,
    required String level,
    required DateTime today,
  }) =>
      StoredTrainingPlan(
        origin: PlanOrigin.onboarding,
        inputs: PlanInputs(
          disciplines: const [],
          goal: LegacyPlanMigration.goalOfProfile(goal),
          level: LegacyPlanMigration.levelOfProfile(level),
          weekdays: weekdaysFor(weeklyTrainingDays),
          startDate: today,
        ),
      );
}
