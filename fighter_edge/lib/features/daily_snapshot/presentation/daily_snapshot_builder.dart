import '../../fight_camp/domain/weight_trend.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../../state/app_state.dart';
import '../domain/daily_snapshot.dart';

/// Assembles [DailySnapshot] from live app state, for the AI coach (product
/// plan, step 5). Only training, the weight trend and the fight camp reach
/// the model this way — food targets and the day's log already reach it
/// through `NutritionTarget`/`NutritionDay`, so [DailySnapshot.nutrition] is
/// left out of what gets sent (`aiFacts.ts` does not whitelist it either).
DailySnapshot buildDailySnapshot(
  AppState state,
  FightCampController fightCamp, {
  int? ageYears,
}) {
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
    plannedSessionsPerWeek: state.sessions.length,
    // Food targets/log reach the AI through NutritionTarget/NutritionDay
    // already; a null goal here just skips the (unused) nutrition summary.
    goal: null,
    nutritionDays: const [],
    weights: [for (final w in state.weights) WeightPoint(w.date, w.kg)],
    camp: fightCamp.camp,
    ageYears: ageYears,
  );
}
