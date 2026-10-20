import '../../edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../../fight_camp/domain/weight_trend.dart';
import '../../fight_camp/presentation/camp_screening_from_draft.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../../state/app_state.dart';
import '../../training_plan/domain/models/session_status.dart';
import '../../training_plan/presentation/plan_controller.dart';
import '../../training_plan/presentation/plan_labels.dart';
import '../domain/daily_snapshot.dart';

/// Assembles [DailySnapshot] from live app state, for the AI coach (product
/// plan, step 5). Only training, the weight trend and the fight camp reach
/// the model this way — food targets and the day's log already reach it
/// through `NutritionTarget`/`NutritionDay`, so [DailySnapshot.nutrition] is
/// left out of what gets sent (`aiFacts.ts` does not whitelist it either).
///
/// Age and the camp screening gate both come from [fuelDraft], so a caller
/// cannot pass one and forget the other. Without a confirmed draft the camp
/// reads as "needs screening", which the model is told to answer with "finish
/// Fuel setup". Refuel guidance follows [FightCampController.refuelGuidance],
/// the same switch the screens use.
DailySnapshot buildDailySnapshot(
  AppState state,
  PlanController plan,
  FightCampController fightCamp, {
  NutritionSetupDraft? fuelDraft,
}) {
  final planned = plan.todayRow;
  return DailySnapshot.build(
    today: state.now,
    training: [
      for (final entry in state.trainingLog)
        TrainingRecord(
          completedAt: entry.completedAt,
          countsAsTrainingDay: entry.source.countsAsTrainingDay,
          durationMinutes: entry.durationSeconds == null
              ? null
              : entry.durationSeconds! ~/ 60,
          rpe: entry.rpe,
        ),
    ],
    plannedSessionsPerWeek: plan.trainingWeekdays.length,
    plannedToday:
        planned == null ? null : PlanLabels.snapshotKind(planned.session),
    plannedTodayDone: planned?.status == SessionStatus.completed,
    // Food targets/log reach the AI through NutritionTarget/NutritionDay
    // already; a null goal here just skips the (unused) nutrition summary.
    goal: null,
    nutritionDays: const [],
    weights: [for (final w in state.weights) WeightPoint(w.date, w.kg)],
    camp: fightCamp.camp,
    ageYears: fuelDraft?.ageYears,
    screening: campScreeningFromDraft(fuelDraft),
    refuelGuidance: fightCamp.refuelGuidance,
  );
}
