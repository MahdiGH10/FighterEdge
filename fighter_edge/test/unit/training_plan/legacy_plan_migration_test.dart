import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/training_plan/data/legacy_plan_migration.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/data/onboarding_plan.dart';
import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/date_key.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_goal.dart';
import 'package:fighter_edge/features/training_plan/domain/session_status_resolver.dart';
import 'package:fighter_edge/features/training_plan/domain/templates/generic_template_set.dart';
import 'package:fighter_edge/features/training_plan/domain/training_plan_generator.dart';

LegacySessionSlot _slot(String day, String title) =>
    LegacySessionSlot(id: '$day-$title', day: day, title: title);

/// What the app's old fresh plan looked like for a six-day athlete.
final _legacyWeek = [
  _slot('Mon', 'Striking'),
  _slot('Tue', 'Wrestling'),
  _slot('Wed', 'Conditioning'),
  _slot('Thu', 'BJJ'),
  _slot('Fri', 'Strength'),
  _slot('Sat', 'Recovery'),
];

void main() {
  // A Wednesday, mid-week, so "nothing before today counts" is visible.
  final today = DateTime(2026, 10, 21, 20);

  group('LegacyPlanMigration', () {
    test('keeps the weekdays the athlete trained on', () {
      final plan = LegacyPlanMigration.migrate(
        [_slot('Mon', 'Striking'), _slot('Wed', 'BJJ'), _slot('Fri', 'x')],
        today: today,
      )!;
      expect(plan.inputs.trainingWeekdays,
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(plan.origin, PlanOrigin.migration);
    });

    test('keeps the disciplines named in the titles, in week order', () {
      final plan = LegacyPlanMigration.migrate(_legacyWeek, today: today)!;
      expect(plan.inputs.disciplines,
          [Discipline.boxing, Discipline.wrestling, Discipline.bjj]);
    });

    test('does not invent a discipline for conditioning, strength, recovery',
        () {
      final plan = LegacyPlanMigration.migrate(
        [_slot('Mon', 'Conditioning'), _slot('Tue', 'Strength')],
        today: today,
      )!;
      expect(plan.inputs.disciplines, isEmpty);
    });

    test('reads discipline words the old plan and athletes used', () {
      Discipline? of(String title) =>
          LegacyPlanMigration.disciplineOfTitle(title);
      expect(of('Boxing + Combinations'), Discipline.boxing);
      expect(of('Kickboxing'), Discipline.kickboxing);
      expect(of('Muay Thai'), Discipline.muayThai);
      expect(of('Takedowns'), isNull);
      expect(of('Wrestling'), Discipline.wrestling);
      expect(of('Jiu-Jitsu'), Discipline.bjj);
      expect(of('MMA sparring'), Discipline.mma);
    });

    test('starts on the day it is made, so no earlier day can be missed', () {
      final plan = LegacyPlanMigration.migrate(_legacyWeek, today: today)!;
      expect(dateKey(plan.inputs.startDate), '2026-10-21');
      final week = const TrainingPlanGenerator().week(
        plan.inputs,
        DateTime(2026, 10, 19),
        GenericTemplateSet.instance,
      );
      // Mon and Tue are before the plan: no session, nothing to miss.
      expect(week.days[0].sessions, isEmpty);
      expect(week.days[1].sessions, isEmpty);
      expect(week.days[2].sessions, hasLength(1));
      final rows = const SessionStatusResolver().resolve(
        weeks: [week],
        today: DateTime(2026, 10, 21),
      );
      expect(rows.where((r) => r.status.name == 'missed'), isEmpty);
    });

    test('returns nothing when no slot names a weekday', () {
      expect(LegacyPlanMigration.migrate([], today: today), isNull);
      expect(
        LegacyPlanMigration.migrate([_slot('someday', 'Striking')],
            today: today),
        isNull,
      );
    });

    test('an unknown profile gets the safest defaults', () {
      final plan = LegacyPlanMigration.migrate(_legacyWeek, today: today)!;
      expect(plan.inputs.level, ExperienceLevel.beginner,
          reason: 'beginners get no sparring');
      expect(plan.inputs.goal, TrainingGoal.buildFitness);
    });

    test('maps the onboarding answers', () {
      final plan = LegacyPlanMigration.migrate(
        _legacyWeek,
        today: today,
        goal: 'Lose weight safely',
        level: 'Fighter',
      )!;
      expect(plan.inputs.goal, TrainingGoal.loseFat);
      expect(plan.inputs.level, ExperienceLevel.competitor);
      expect(LegacyPlanMigration.goalOfProfile('Gain muscle'),
          TrainingGoal.buildMuscle);
      expect(LegacyPlanMigration.goalOfProfile('Improve technique'),
          TrainingGoal.improveTechnique);
      expect(LegacyPlanMigration.goalOfProfile('Get competition ready'),
          TrainingGoal.competitionPrep);
      expect(LegacyPlanMigration.levelOfProfile('Advanced'),
          ExperienceLevel.advanced);
      expect(LegacyPlanMigration.levelOfProfile('Intermediate'),
          ExperienceLevel.intermediate);
    });

    test('is deterministic', () {
      final a = LegacyPlanMigration.migrate(_legacyWeek, today: today)!;
      final b = LegacyPlanMigration.migrate(
          _legacyWeek.reversed, // order of the documents does not matter
          today: today)!;
      expect(a.toJson(), b.toJson());
    });
  });

  group('OnboardingPlan', () {
    test('spreads the chosen number of days through the week', () {
      for (var days = 2; days <= 6; days++) {
        expect(OnboardingPlan.weekdaysFor(days), hasLength(days));
      }
      expect(OnboardingPlan.weekdaysFor(3),
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
    });

    test('clamps to two to six days and never plans a Sunday', () {
      expect(OnboardingPlan.weekdaysFor(0), hasLength(2));
      expect(OnboardingPlan.weekdaysFor(9), hasLength(6));
      for (var days = 0; days <= 9; days++) {
        expect(
            OnboardingPlan.weekdaysFor(days), isNot(contains(DateTime.sunday)));
      }
    });

    test('makes no assumption about disciplines', () {
      final plan = OnboardingPlan.create(
        weeklyTrainingDays: 4,
        goal: 'Gain muscle',
        level: 'Intermediate',
        today: today,
      );
      expect(plan.inputs.disciplines, isEmpty);
      expect(plan.origin, PlanOrigin.onboarding);
      expect(plan.inputs.level, ExperienceLevel.intermediate);
    });
  });
}
