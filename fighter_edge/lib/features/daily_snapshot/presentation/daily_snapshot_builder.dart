import '../../edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../../fight_camp/domain/weight_trend.dart';
import '../../fight_camp/presentation/camp_screening_from_draft.dart';
import '../../fight_camp/presentation/fight_camp_controller.dart';
import '../../../models/training_session.dart';
import '../../../state/app_state.dart';
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
  FightCampController fightCamp, {
  NutritionSetupDraft? fuelDraft,
}) {
  final planned = plannedSessionToday(state);
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
    plannedToday: planned == null ? null : sessionKindOf(planned),
    plannedTodayDone: planned?.completed ?? false,
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

const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The weekly plan's session for today, done or not; null on a rest day.
/// Matches the plan's day names the way the dashboard does.
TrainingSession? plannedSessionToday(AppState state) {
  final today = _weekdays[state.now.weekday - 1];
  return state.sessions
      .where((s) => s.day.toLowerCase().startsWith(today))
      .firstOrNull;
}

/// The plan's session titles (`AppState`'s templates) as fixed names. Any
/// other title is [SessionKind.other]: its words never leave the device.
SessionKind sessionKindOf(TrainingSession session) =>
    switch (session.title.trim().toLowerCase()) {
      'striking' => SessionKind.striking,
      'wrestling' => SessionKind.wrestling,
      'conditioning' => SessionKind.conditioning,
      'bjj' => SessionKind.bjj,
      'strength' => SessionKind.strength,
      'recovery' => SessionKind.recovery,
      _ => SessionKind.other,
    };
