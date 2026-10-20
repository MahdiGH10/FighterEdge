import '../../../models/training_log_entry.dart';
import '../../../state/app_state.dart';
import '../../edge_fuel/domain/calculators/weekly_fuel_calculator.dart';
import '../../edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../../fight_camp/domain/calendar.dart';
import '../../fight_camp/domain/weight_path.dart';
import '../../fight_camp/domain/weight_trend.dart';
import '../../fight_camp/presentation/camp_screening_from_draft.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../training_plan/domain/consistency/weekly_adherence.dart';
import '../../training_plan/domain/models/session_status.dart';
import '../../training_plan/presentation/plan_controller.dart';
import '../domain/weekly_review.dart';

/// Gathers the facts of the week starting [weekStartDay] from live app state
/// and runs them through [WeeklyReviewCalculator].
///
/// Everything here is a read: the training week from the plan, the week's
/// food from the Fuel log (the same summary the Fuel week card shows), and
/// the scale from the weight trend against the fight-camp path.
Future<WeeklyReview> buildWeeklyReview({
  required DateTime weekStartDay,
  required PlanController plan,
  required AppState state,
  required EdgeFuelController fuel,
  required FightCampController fightCamp,
}) async {
  final start = calendarDay(weekStartDay);
  final sunday = addDays(start, 6);

  final adherence = WeeklyAdherence.fromResolved(
    weekStart: start,
    resolved: plan.rows,
    today: plan.today,
  );
  String? movable;
  for (final row in plan.rows) {
    if (row.status == SessionStatus.missed &&
        daysBetween(start, row.date) >= 0 &&
        daysBetween(start, row.date) <= 6 &&
        plan.canMoveToToday(row)) {
      movable = row.session.id;
      break;
    }
  }
  final training = ReviewTraining(
    planned: adherence.planned,
    completed: adherence.completed,
    target: adherence.target,
    missed: adherence.missed,
    skipped: adherence.skipped,
    movableSessionId: movable,
  );

  var nutrition = const ReviewNutrition();
  final target = fuel.target;
  if (fuel.hasUsableTarget && target != null) {
    final days = await fuel.loadThisWeek(
      now: DateTime(sunday.year, sunday.month, sunday.day),
    );
    nutrition = ReviewNutrition.fromSummary(
      WeeklyFuelCalculator.summarise(days: days, target: target),
      restingEnergyKcal: target.estimatedRmrKcal,
    );
  }

  final points = [for (final w in state.weights) WeightPoint(w.date, w.kg)];
  final trend = WeightTrend.from(points, today: sunday);
  double? expected;
  final camp = fightCamp.camp;
  if (camp != null) {
    final status = FightCampStatus.of(
      camp,
      weights: state.weights,
      today: sunday,
      ageYears: fuel.draft?.ageYears,
      screening: campScreeningFromDraft(fuel.draft),
    );
    // Only a path the app actually plans has a pace to compare with.
    if (status.path.status == WeightPathStatus.onTrack) {
      expected = -status.path.weeklyLossKg;
    }
  }

  return WeeklyReviewCalculator.build(
    weekStart: start,
    training: training,
    nutrition: nutrition,
    weight: ReviewWeight(
      changeKg: trend.weeklyChangeKg,
      expectedChangeKg: expected,
      weighIns: trend.weighInsLast7Days,
    ),
  );
}

// Keeps the log type in scope for readers: entries are what the plan joins.
typedef _LogEntry = TrainingLogEntry;
