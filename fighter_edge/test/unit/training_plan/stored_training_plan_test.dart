import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/plan_inputs.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_goal.dart';
import 'package:fighter_edge/features/training_plan/domain/session_status_resolver.dart';
import 'package:fighter_edge/features/training_plan/domain/templates/generic_template_set.dart';
import 'package:fighter_edge/features/training_plan/domain/training_plan_generator.dart';

StoredTrainingPlan _plan() => StoredTrainingPlan(
      origin: PlanOrigin.migration,
      generatorVersion: 1,
      templateSetVersion: 1,
      inputs: PlanInputs(
        disciplines: const [Discipline.boxing, Discipline.bjj],
        goal: TrainingGoal.competitionPrep,
        level: ExperienceLevel.intermediate,
        weekdays: const [DateTime.monday, DateTime.wednesday, DateTime.friday],
        gymClassWeekdays: const [DateTime.thursday],
        sessionMinutes: 50,
        startDate: DateTime(2026, 10, 14, 22),
      ),
      adjustments: [
        const SessionAdjustment.skipped('2026-10-19.skill'),
        SessionAdjustment.moved('2026-10-21.skill', DateTime(2026, 10, 22)),
      ],
    );

/// Through JSON text, like a Firestore document that was stored and read.
StoredTrainingPlan _reload(StoredTrainingPlan plan) =>
    StoredTrainingPlan.fromJson(
        jsonDecode(jsonEncode(plan.toJson())) as Map<String, dynamic>)!;

void main() {
  test('round-trips every field through JSON', () {
    final back = _reload(_plan());
    expect(back.toJson(), _plan().toJson());
    expect(back.origin, PlanOrigin.migration);
    expect(back.generatorVersion, 1);
    expect(back.inputs.disciplines, [Discipline.boxing, Discipline.bjj]);
    expect(back.inputs.trainingWeekdays, {1, 3, 4, 5});
    expect(back.inputs.gymClassWeekdays, {4});
    expect(back.inputs.sessionMinutes, 50);
    expect(back.adjustments['2026-10-19.skill']!.kind, AdjustmentKind.skipped);
    final moved = back.adjustments['2026-10-21.skill']!;
    expect(moved.kind, AdjustmentKind.moved);
    expect(moved.movedTo, DateTime.utc(2026, 10, 22));
  });

  test('the same plan generates the same week after a reload', () {
    const generator = TrainingPlanGenerator();
    final templates = GenericTemplateSet.instance;
    final monday = DateTime(2026, 10, 19);
    for (var w = 0; w < 6; w++) {
      final start = monday.add(Duration(days: 7 * w));
      final before = generator.week(_plan().inputs, start, templates);
      final after = generator.week(_reload(_plan()).inputs, start, templates);
      expect(jsonEncode(after.toJson()), jsonEncode(before.toJson()),
          reason: 'week $w');
    }
  });

  test('only the start day is kept, not the time of day', () {
    expect(_reload(_plan()).inputs.startDate, DateTime.utc(2026, 10, 14));
  });

  test('a document with no usable start date is not a plan', () {
    expect(StoredTrainingPlan.fromJson({}), isNull);
    expect(StoredTrainingPlan.fromJson({'inputs': 'x'}), isNull);
    expect(
      StoredTrainingPlan.fromJson({
        'inputs': {'startDate': '2026-02-31'},
      }),
      isNull,
      reason: 'a date the calendar would roll over',
    );
    expect(
      StoredTrainingPlan.fromJson({
        'inputs': {'startDate': 'tomorrow'},
      }),
      isNull,
    );
  });

  test('unknown values fall back to safe defaults instead of throwing', () {
    final plan = StoredTrainingPlan.fromJson({
      'origin': 'martian',
      'inputs': {
        'startDate': '2026-10-19',
        'disciplines': ['boxing', 'quidditch', 7],
        'goal': 'world-domination',
        'level': null,
        'weekdays': [1, 99, 'x', 3],
        'sessionMinutes': 9999,
      },
      'adjustments': [
        {'sessionId': 'a', 'kind': 'moved'},
        {'sessionId': '', 'kind': 'skipped'},
        {'sessionId': 'b', 'kind': 'skipped'},
        'junk',
      ],
    })!;
    expect(plan.inputs.disciplines, [Discipline.boxing]);
    expect(plan.inputs.goal, TrainingGoal.buildFitness);
    expect(plan.inputs.level, ExperienceLevel.beginner);
    expect(plan.inputs.trainingWeekdays, {1, 3});
    expect(plan.inputs.sessionMinutes, isNull);
    expect(plan.origin, PlanOrigin.onboarding);
    expect(plan.adjustments.keys, ['b'],
        reason: 'a move with no date and a blank id are dropped');
  });

  test('adjustments replace by session id and can be removed', () {
    var plan = StoredTrainingPlan(inputs: _plan().inputs);
    plan = plan.withAdjustment(const SessionAdjustment.skipped('x'));
    plan = plan.withAdjustment(SessionAdjustment.moved('x', DateTime(2026, 10, 22)));
    expect(plan.adjustments, hasLength(1));
    expect(plan.adjustments['x']!.kind, AdjustmentKind.moved);
    expect(plan.withoutAdjustment('x').adjustments, isEmpty);
    expect(plan.withoutAdjustment('nope').adjustments, hasLength(1));
  });

  test('the fight is not stored with the plan', () {
    expect(jsonEncode(_plan().toJson()), isNot(contains('fight')));
  });
}
