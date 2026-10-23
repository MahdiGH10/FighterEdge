import '../../../fight_camp/domain/weight_cut_policy.dart';
import '../../../training_plan/domain/models/discipline.dart';
import '../../../training_plan/domain/models/fight_context.dart';
import '../../../training_plan/domain/models/intensity.dart';
import '../../../training_plan/domain/models/planned_session.dart';
import '../../../training_plan/domain/models/planned_week.dart';
import '../../../training_plan/domain/models/session_kind.dart';
import '../models/fuel_day_plan.dart';
import '../models/planned_fuel_session.dart';
import 'fuel_day_planner.dart';

/// Maps the training plan's dated week onto Fuel's input types.
///
/// This is the one file in the Fuel domain that reads the training-plan
/// domain. Both are pure Dart, so the day types always follow the same plan
/// the Train tab shows, with no second copy of the week.
class TrainingPlanFuelBridge {
  const TrainingPlanFuelBridge._();

  /// Fuel day plans for the seven days of [week]. [extra] adds dated sessions
  /// the plan does not hold (for example a second class the athlete adds),
  /// which is how a double day can appear: the plan itself has at most one
  /// session a day.
  static List<FuelDayPlan> planWeek(
    PlannedWeek week, {
    FightContext? fight,
    Iterable<FuelDatedSession> extra = const [],
  }) =>
      FuelDayPlanner.planWeek(
        start: week.weekStart,
        plan: [...sessionsOf(week), ...extra],
        fight: fightWindowOf(fight),
        days: week.days.length,
      );

  /// Every session of [week], in plan order.
  static List<FuelDatedSession> sessionsOf(PlannedWeek week) =>
      List.unmodifiable([for (final s in week.sessions) sessionOf(s)]);

  static FuelDatedSession sessionOf(PlannedSession session) => FuelDatedSession(
        date: session.date,
        discipline: disciplineOf(session.kind, session.discipline),
        intensity: intensityOf(session.intensity),
        durationMinutes: session.estimatedMinutes,
        sessionId: session.id,
      );

  /// What a session costs is set by what it trains. Skill, sparring and gym
  /// classes take the session's discipline; with none, they cost as
  /// [FuelDiscipline.other], the conservative row.
  static FuelDiscipline disciplineOf(
          SessionKind kind, Discipline? discipline) =>
      switch (kind) {
        SessionKind.conditioning => FuelDiscipline.conditioning,
        SessionKind.strength => FuelDiscipline.strength,
        SessionKind.recovery => FuelDiscipline.other,
        SessionKind.skill ||
        SessionKind.sparring ||
        SessionKind.gymClass =>
          switch (discipline) {
            null => FuelDiscipline.other,
            Discipline.boxing => FuelDiscipline.boxing,
            Discipline.kickboxing => FuelDiscipline.kickboxing,
            Discipline.muayThai => FuelDiscipline.muayThai,
            Discipline.wrestling => FuelDiscipline.wrestling,
            Discipline.bjj => FuelDiscipline.bjj,
            Discipline.mma => FuelDiscipline.mma,
          },
      };

  static FuelIntensity intensityOf(Intensity intensity) => switch (intensity) {
        Intensity.light => FuelIntensity.light,
        Intensity.moderate => FuelIntensity.moderate,
        Intensity.hard => FuelIntensity.hard,
      };

  /// The fight window of a booked fight: the seven days before the weigh-in
  /// through fight day, the same days the fight camp calls fight week and
  /// refuel. Null with no fight.
  static FuelFightWindow? fightWindowOf(FightContext? fight) => fight == null
      ? null
      : FuelFightWindow(
          weighInDate: fight.weighInDate,
          fightDate: fight.fightDate,
          fightWeekDays: WeightCutPolicy.fightWeekDays,
        );
}
