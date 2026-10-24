import 'package:fighter_edge/features/edge_fuel/domain/calculators/training_plan_fuel_bridge.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/training_plan/domain/models/day_type.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/fight_context.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/plan_inputs.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_day.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_week.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_goal.dart';
import 'package:fighter_edge/features/training_plan/domain/templates/generic_template_set.dart';
import 'package:fighter_edge/features/training_plan/domain/training_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Monday.
final _monday = DateTime.utc(2026, 10, 19);

PlannedSession _session(
  int dayOffset, {
  SessionKind kind = SessionKind.skill,
  Discipline? discipline = Discipline.boxing,
  Intensity intensity = Intensity.moderate,
  int minutes = 60,
}) {
  final date = _monday.add(Duration(days: dayOffset));
  return PlannedSession(
    id: 'd$dayOffset.${kind.name}',
    date: date,
    kind: kind,
    discipline: discipline,
    intensity: intensity,
    titleKey: kind.fallbackTitleKey,
    estimatedMinutes: minutes,
  );
}

PlannedWeek _week(Map<int, PlannedSession> sessions) => PlannedWeek(
      weekStart: _monday,
      planStart: _monday,
      generatorVersion: 1,
      templateSetVersion: 1,
      inputsHash: 'test',
      days: [
        for (var i = 0; i < 7; i++)
          PlannedDay(
            date: _monday.add(Duration(days: i)),
            type: sessions.containsKey(i) ? DayType.training : DayType.rest,
            sessions: [if (sessions[i] != null) sessions[i]!],
          ),
      ],
    );

void main() {
  test('maps every session kind and discipline to an energy row', () {
    expect(
      TrainingPlanFuelBridge.disciplineOf(SessionKind.conditioning, null),
      FuelDiscipline.conditioning,
    );
    expect(
      TrainingPlanFuelBridge.disciplineOf(
        SessionKind.strength,
        Discipline.bjj,
      ),
      FuelDiscipline.strength,
    );
    expect(
      TrainingPlanFuelBridge.disciplineOf(
        SessionKind.recovery,
        Discipline.mma,
      ),
      FuelDiscipline.other,
    );
    expect(
      TrainingPlanFuelBridge.disciplineOf(SessionKind.sparring, null),
      FuelDiscipline.other,
    );
    for (final kind in [
      SessionKind.skill,
      SessionKind.sparring,
      SessionKind.gymClass,
    ]) {
      for (final d in Discipline.values) {
        expect(
          TrainingPlanFuelBridge.disciplineOf(kind, d).name,
          d.name,
          reason: '${kind.name}/${d.name}',
        );
      }
    }
    for (final i in Intensity.values) {
      expect(TrainingPlanFuelBridge.intensityOf(i).name, i.name);
    }
  });

  test('carries the date, minutes and plan id of a session', () {
    final s = TrainingPlanFuelBridge.sessionOf(
      _session(2, intensity: Intensity.hard, minutes: 75),
    );
    expect(s.date, _monday.add(const Duration(days: 2)));
    expect(s.discipline, FuelDiscipline.boxing);
    expect(s.intensity, FuelIntensity.hard);
    expect(s.durationMinutes, 75);
    expect(s.sessionId, 'd2.skill');
    expect(s.startMinuteOfDay, isNull);
  });

  test('day types follow the planned week', () {
    final days = TrainingPlanFuelBridge.planWeek(
      _week({
        0: _session(0, intensity: Intensity.hard),
        2: _session(2, minutes: 30),
        4: _session(4, kind: SessionKind.recovery, intensity: Intensity.light),
      }),
    );
    expect(days.map((d) => d.type), [
      FuelDayType.hard,
      FuelDayType.rest,
      FuelDayType.easy,
      FuelDayType.rest,
      FuelDayType.easy,
      FuelDayType.rest,
      FuelDayType.rest,
    ]);
    expect(days.first.date, DateTime(2026, 10, 19));
    expect(days.first.sessions.single.sessionId, 'd0.skill');
  });

  test('an extra class on a planned day makes a double day', () {
    final days = TrainingPlanFuelBridge.planWeek(
      _week({1: _session(1, minutes: 45)}),
      extra: [
        FuelDatedSession(
          date: _monday.add(const Duration(days: 1)),
          discipline: FuelDiscipline.bjj,
          intensity: FuelIntensity.light,
          durationMinutes: 60,
        ),
      ],
    );
    expect(days[1].type, FuelDayType.doubleDay);
    expect(days[1].sessions, hasLength(2));
  });

  test('a booked fight marks fight week from the fight camp dates', () {
    final camp = FightCamp.tryCreate(
      fightDate: DateTime.utc(2026, 10, 25),
      weighInDate: DateTime.utc(2026, 10, 24),
      weightLimitKg: 70,
      category: CompetitionCategory.amateurStriking,
    )!;
    final fight = FightContext(camp);
    final window = TrainingPlanFuelBridge.fightWindowOf(fight)!;
    expect(window.fightWeekDays, WeightCutPolicy.fightWeekDays);
    expect(TrainingPlanFuelBridge.fightWindowOf(null), isNull);

    final days = TrainingPlanFuelBridge.planWeek(
      _week({0: _session(0, intensity: Intensity.hard)}),
      fight: fight,
    );
    // The weigh-in is Saturday 24th, so fight week starts Saturday 17th:
    // the whole of this week is in the window.
    expect(days.every((d) => d.isFightWeek), isTrue);
    expect(days.first.load, FuelDayType.hard);
    for (final day in days) {
      expect(
        camp.phaseOn(day.date),
        anyOf(CampPhase.fightWeek, CampPhase.refuel),
        reason: '${day.date}',
      );
    }
  });

  test('works on a week from the real generator', () {
    final inputs = PlanInputs(
      disciplines: const [Discipline.boxing, Discipline.bjj],
      goal: TrainingGoal.buildFitness,
      level: ExperienceLevel.intermediate,
      weekdays: const [1, 3, 5],
      startDate: _monday,
    );
    final week = const TrainingPlanGenerator()
        .week(inputs, _monday, GenericTemplateSet.instance);
    final days = TrainingPlanFuelBridge.planWeek(week);
    expect(days, hasLength(7));
    for (var i = 0; i < 7; i++) {
      final planned = week.days[i];
      expect(days[i].date, DateTime(2026, 10, 19 + i));
      expect(days[i].sessions, hasLength(planned.sessions.length));
      expect(
        days[i].hasTraining,
        planned.sessions.isNotEmpty,
        reason: 'day $i',
      );
    }
    expect(days.where((d) => d.hasTraining), hasLength(3));
  });
}
