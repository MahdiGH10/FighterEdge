import 'dart:convert';

import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/training_plan/domain/models/day_type.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/fight_context.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/plan_inputs.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_week.dart';
import 'package:fighter_edge/features/training_plan/domain/models/reason_code.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_template.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_goal.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_phase.dart';
import 'package:fighter_edge/features/training_plan/domain/rules/phase_modifiers.dart';
import 'package:fighter_edge/features/training_plan/domain/templates/generic_template_set.dart';
import 'package:fighter_edge/features/training_plan/domain/training_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/placeholder_template_set.dart';

/// A Monday.
final _monday = DateTime.utc(2026, 10, 19);
const _generator = TrainingPlanGenerator();

PlanInputs _inputs({
  List<Discipline> disciplines = const [Discipline.boxing],
  TrainingGoal goal = TrainingGoal.buildFitness,
  ExperienceLevel level = ExperienceLevel.intermediate,
  List<int> weekdays = const [1, 3, 5],
  List<int> gymClassWeekdays = const [],
  int? sessionMinutes,
  DateTime? startDate,
  FightContext? fight,
}) =>
    PlanInputs(
      disciplines: disciplines,
      goal: goal,
      level: level,
      weekdays: weekdays,
      gymClassWeekdays: gymClassWeekdays,
      sessionMinutes: sessionMinutes,
      startDate: startDate ?? _monday,
      fight: fight,
    );

PlannedWeek _week(
  PlanInputs inputs, {
  DateTime? weekStart,
  TemplateSet? templates,
}) =>
    _generator.week(
      inputs,
      weekStart ?? _monday,
      templates ?? placeholderTemplateSet,
    );

FightContext _fight(DateTime fightDate, {DateTime? weighIn}) => FightContext(
      FightCamp.tryCreate(
        fightDate: fightDate,
        weighInDate: weighIn,
        weightLimitKg: 70,
        category: CompetitionCategory.amateurStriking,
      )!,
    );

List<PlannedSession> _sessions(PlannedWeek week) => week.sessions.toList();

Set<int> _trainingWeekdays(PlannedWeek week) => {
      for (final s in week.sessions) s.date.weekday,
    };

void main() {
  group('determinism', () {
    test('the same inputs give the same week, byte for byte', () {
      final inputs = _inputs(
        disciplines: [Discipline.boxing, Discipline.wrestling],
        goal: TrainingGoal.competitionPrep,
        weekdays: [1, 2, 4, 5, 6],
      );
      final a = jsonEncode(_week(inputs).toJson());
      final b = jsonEncode(_week(inputs).toJson());
      expect(a, b);
    });

    test('equal inputs built twice give the same week and the same hash', () {
      PlanInputs build() => _inputs(
            disciplines: [Discipline.mma, Discipline.bjj],
            weekdays: [6, 1, 3],
            fight: _fight(DateTime.utc(2026, 12, 12)),
          );
      expect(build().hash, build().hash);
      expect(
        jsonEncode(_week(build()).toJson()),
        jsonEncode(_week(build()).toJson()),
      );
    });

    test('weekday order and duplicates do not change the plan', () {
      final a = _inputs(weekdays: [1, 3, 5]);
      final b = _inputs(weekdays: [5, 1, 3, 3, 1]);
      expect(a.hash, b.hash);
      expect(jsonEncode(_week(a).toJson()), jsonEncode(_week(b).toJson()));
    });

    test('a different input changes the hash', () {
      final base = _inputs();
      final others = [
        _inputs(goal: TrainingGoal.loseFat),
        _inputs(level: ExperienceLevel.advanced),
        _inputs(weekdays: [1, 3, 6]),
        _inputs(disciplines: [Discipline.mma]),
        _inputs(sessionMinutes: 50),
        _inputs(gymClassWeekdays: [2]),
        _inputs(startDate: DateTime.utc(2026, 10, 20)),
        _inputs(fight: _fight(DateTime.utc(2026, 12, 12))),
      ];
      for (final other in others) {
        expect(other.hash, isNot(base.hash));
      }
    });

    test('the week records the generator, template set and inputs used', () {
      final inputs = _inputs();
      final week = _week(inputs);
      expect(week.generatorVersion, TrainingPlanGenerator.version);
      expect(week.templateSetVersion, placeholderTemplateSetVersion);
      expect(week.inputsHash, inputs.hash);
      expect(week.weekStart, _monday);
      expect(week.planStart, _monday);
    });

    test('time of day and time zone of the dates do not matter', () {
      final a = _inputs(startDate: DateTime(2026, 10, 19, 23, 59));
      final b = _inputs(startDate: DateTime.utc(2026, 10, 19, 1));
      expect(a.hash, b.hash);
      expect(
        jsonEncode(_week(a, weekStart: DateTime(2026, 10, 19, 22)).toJson()),
        jsonEncode(_week(b).toJson()),
      );
    });

    test('session ids are unique and built from the date and kind', () {
      final week = _week(_inputs(weekdays: [1, 2, 3, 4, 5, 6]));
      final ids = [for (final s in week.sessions) s.id];
      expect(ids.toSet().length, ids.length);
      for (final s in week.sessions) {
        expect(s.id, startsWith('2026-10-'));
        expect(s.id, endsWith('.${s.kind.name}'));
      }
    });
  });

  group('week shape', () {
    test('seven consecutive dated days', () {
      final week = _week(_inputs());
      expect(week.days, hasLength(7));
      for (var i = 0; i < 7; i++) {
        expect(week.days[i].date, addDays(_monday, i));
      }
    });

    test('exactly the chosen weekdays get one session', () {
      for (final days in [
        [1, 3, 5],
        [2, 6],
        [1, 2, 3, 4, 5, 6, 7],
        [7],
      ]) {
        final week = _week(_inputs(weekdays: days));
        expect(_trainingWeekdays(week), days.toSet(), reason: '$days');
        for (final day in week.days) {
          expect(day.sessions.length, days.contains(day.date.weekday) ? 1 : 0);
        }
      }
    });

    test('rest days have no session and are typed rest', () {
      final week = _week(_inputs(weekdays: [1, 3, 5]));
      for (final day in week.days) {
        if (day.sessions.isEmpty) expect(day.type, DayType.rest);
      }
    });

    test('invalid weekdays are dropped', () {
      final inputs = _inputs(weekdays: [0, 8, -1, 2]);
      expect(inputs.trainingWeekdays, {2});
    });

    test('no weekdays chosen gives a plan of rest days with a reason', () {
      final week = _week(_inputs(weekdays: []));
      expect(week.sessions, isEmpty);
      expect(week.reasons, contains(ReasonCode.noWeekdaysChosen));
      expect(week.reasons, isNot(contains(ReasonCode.weekdaysChosen)));
    });

    test('the week may start on any weekday', () {
      final wednesday = DateTime.utc(2026, 10, 21);
      final week = _week(
        _inputs(weekdays: [1, 3, 5], startDate: wednesday),
        weekStart: wednesday,
      );
      expect(week.days.first.date, wednesday);
      expect(_trainingWeekdays(week), {1, 3, 5});
    });

    test('a session lasts what the template says unless the athlete sets it',
        () {
      final plain = _week(_inputs(level: ExperienceLevel.beginner));
      for (final s in plain.sessions) {
        expect(s.reasons, isNot(contains(ReasonCode.sessionMinutesOverride)));
        expect(s.estimatedMinutes, greaterThan(0));
      }
      final custom = _week(_inputs(sessionMinutes: 30));
      for (final s in custom.sessions) {
        expect(s.estimatedMinutes, 30);
        expect(s.reasons, contains(ReasonCode.sessionMinutesOverride));
      }
    });

    test('an out-of-range session length is ignored', () {
      expect(_inputs(sessionMinutes: 5).sessionMinutes, isNull);
      expect(_inputs(sessionMinutes: 400).sessionMinutes, isNull);
      expect(_inputs(sessionMinutes: 90).sessionMinutes, 90);
    });

    test('scaled blocks follow the session length', () {
      final long = _week(_inputs(sessionMinutes: 90));
      final short = _week(_inputs(sessionMinutes: 30));
      int rounds(PlannedWeek w) => w.sessions
          .expand((s) => s.blocks)
          .where((b) => b.rounds != null)
          .fold(0, (sum, b) => sum + b.rounds!);
      expect(rounds(long), greaterThan(rounds(short)));
      for (final s in long.sessions.followedBy(short.sessions)) {
        for (final b in s.blocks) {
          expect(b.minutes ?? 1, greaterThanOrEqualTo(1));
          expect(b.rounds ?? 1, greaterThanOrEqualTo(1));
        }
      }
    });

    test('weeks start on the plan start and nothing before it is planned', () {
      final thursday = DateTime.utc(2026, 10, 22);
      final week = _week(
        _inputs(weekdays: [1, 2, 3, 4, 5, 6, 7], startDate: thursday),
      );
      expect(week.reasons, contains(ReasonCode.midWeekStart));
      expect(
        [for (final s in week.sessions) s.date],
        [for (var i = 3; i < 7; i++) addDays(_monday, i)],
      );
      for (var i = 0; i < 3; i++) {
        expect(week.days[i].sessions, isEmpty);
        expect(week.days[i].type, DayType.rest);
      }
    });

    test('a week entirely before the start has no sessions', () {
      final week = _week(
        _inputs(startDate: DateTime.utc(2026, 11, 2)),
      );
      expect(week.sessions, isEmpty);
    });

    test('a week after the start is a full week with no mid-week reason', () {
      final week = _week(
        _inputs(weekdays: [1, 3, 5]),
        weekStart: addDays(_monday, 7),
      );
      expect(week.reasons, isNot(contains(ReasonCode.midWeekStart)));
      expect(_trainingWeekdays(week), {1, 3, 5});
    });
  });

  group('no fight booked', () {
    test('still produces a full plan with a reason', () {
      final week = _week(_inputs(weekdays: [1, 2, 4, 5]));
      expect(week.sessions, hasLength(4));
      expect(week.reasons, contains(ReasonCode.noFightGeneralPlan));
      for (final day in week.days) {
        expect(day.type, isNot(DayType.fight));
        expect(day.type, isNot(DayType.weighIn));
      }
      for (final s in week.sessions) {
        expect(s.templateId, isNotNull);
        expect(s.blocks, isNotEmpty);
      }
    });

    test('works for every goal and level', () {
      for (final goal in TrainingGoal.values) {
        for (final level in ExperienceLevel.values) {
          final week = _week(_inputs(goal: goal, level: level, weekdays: [
            1,
            2,
            4,
            6,
          ]));
          expect(week.sessions, hasLength(4), reason: '$goal $level');
          expect(week.sessions.every((s) => s.templateId != null), isTrue);
        }
      }
    });

    test('every plan week of a long run has the same shape without a fight',
        () {
      final inputs = _inputs(weekdays: [1, 3, 5, 6]);
      for (var w = 0; w < 12; w++) {
        final week = _week(inputs, weekStart: addDays(_monday, 7 * w));
        expect(week.sessions, hasLength(4), reason: 'week $w');
        for (final s in week.sessions) {
          if (s.kind != SessionKind.recovery) {
            expect(s.intensity, isNot(Intensity.light),
                reason: 'week $w ${s.kind}');
          }
        }
      }
    });

    test('without a fight the phase is general, never a fight-camp one', () {
      final week = _week(_inputs(weekdays: [1, 2, 3, 4, 5]));
      const fightReasons = {
        ReasonCode.buildPhase,
        ReasonCode.peakPhase,
        ReasonCode.taperFightWeek,
        ReasonCode.weighInLight,
        ReasonCode.refuelDayRest,
        ReasonCode.fightDayRest,
        ReasonCode.postFightRecovery,
      };
      for (final s in week.sessions) {
        expect(s.reasons.toSet().intersection(fightReasons), isEmpty);
      }
    });
  });

  group('inputs change the plan', () {
    test('the goal changes the mix of session kinds', () {
      Map<SessionKind, int> mix(TrainingGoal goal) {
        final counts = <SessionKind, int>{};
        for (final s in _week(_inputs(
          goal: goal,
          level: ExperienceLevel.advanced,
          weekdays: [1, 2, 3, 4, 5, 6],
        )).sessions) {
          counts[s.kind] = (counts[s.kind] ?? 0) + 1;
        }
        return counts;
      }

      final technique = mix(TrainingGoal.improveTechnique);
      expect(technique[SessionKind.conditioning], isNull);
      expect(technique[SessionKind.strength], isNull);

      final muscle = mix(TrainingGoal.buildMuscle);
      expect(muscle[SessionKind.strength], greaterThanOrEqualTo(2));

      final compete = mix(TrainingGoal.competitionPrep);
      expect(compete[SessionKind.conditioning], greaterThanOrEqualTo(2));

      expect(
        mix(TrainingGoal.loseFat),
        isNot(technique),
      );
    });

    test('competition goals add conditioning from four days', () {
      final four = _week(_inputs(
        goal: TrainingGoal.competitionPrep,
        weekdays: [1, 2, 4, 5],
      ));
      expect(
          four.reasons, contains(ReasonCode.extraConditioningForCompetition));
      final three = _week(_inputs(
        goal: TrainingGoal.competitionPrep,
        weekdays: [1, 3, 5],
      ));
      expect(
        three.reasons,
        isNot(contains(ReasonCode.extraConditioningForCompetition)),
      );
    });

    test('technique goal is skill only and says so', () {
      final week = _week(_inputs(
        goal: TrainingGoal.improveTechnique,
        weekdays: [1, 2, 4, 5],
      ));
      expect(week.reasons, contains(ReasonCode.skillOnlyForTechnique));
      for (final s in week.sessions) {
        expect(
          s.kind == SessionKind.skill || s.kind == SessionKind.sparring,
          isTrue,
          reason: '${s.kind}',
        );
      }
    });

    test('the level changes the template and the length', () {
      final beginner = _week(_inputs(level: ExperienceLevel.beginner));
      final advanced = _week(_inputs(level: ExperienceLevel.advanced));
      expect(
        [for (final s in beginner.sessions) s.templateId],
        isNot([for (final s in advanced.sessions) s.templateId]),
      );
    });

    test('generic set lengths follow the level bands', () {
      for (final entry in {
        ExperienceLevel.beginner: 45,
        ExperienceLevel.intermediate: 60,
        ExperienceLevel.advanced: 75,
        ExperienceLevel.competitor: 75,
      }.entries) {
        final week = _week(
          _inputs(level: entry.key, weekdays: [1, 3, 5]),
          templates: GenericTemplateSet.instance,
        );
        final skill =
            week.sessions.firstWhere((s) => s.kind == SessionKind.skill);
        expect(skill.estimatedMinutes, entry.value, reason: '${entry.key}');
      }
    });

    test('the first discipline gets about half of the skill sessions', () {
      final inputs = _inputs(
        disciplines: [Discipline.boxing, Discipline.wrestling, Discipline.mma],
        goal: TrainingGoal.improveTechnique,
        level: ExperienceLevel.beginner,
        weekdays: [1, 2, 3, 4],
      );
      final counts = <Discipline, int>{};
      for (var w = 0; w < 12; w++) {
        for (final s
            in _week(inputs, weekStart: addDays(_monday, 7 * w)).sessions) {
          counts[s.discipline!] = (counts[s.discipline!] ?? 0) + 1;
        }
      }
      final total = counts.values.fold(0, (a, b) => a + b);
      expect(counts[Discipline.boxing], total ~/ 2);
      expect(counts[Discipline.wrestling], greaterThan(0));
      expect(counts[Discipline.mma], greaterThan(0));
    });

    test('a single discipline gets every skill session', () {
      final week = _week(_inputs(
        disciplines: [Discipline.wrestling],
        goal: TrainingGoal.improveTechnique,
        weekdays: [1, 2, 3],
      ));
      for (final s in week.sessions) {
        expect(s.discipline, Discipline.wrestling);
      }
    });

    test('no disciplines still plans a week', () {
      final week = _week(_inputs(disciplines: [], weekdays: [1, 3, 5]));
      expect(week.sessions, hasLength(3));
      expect(week.sessions.every((s) => s.discipline == null), isTrue);
    });

    test('templates rotate from week to week', () {
      final inputs = _inputs(
        disciplines: [Discipline.boxing],
        goal: TrainingGoal.improveTechnique,
        level: ExperienceLevel.beginner,
        weekdays: [2],
      );
      final ids = {
        for (var w = 0; w < 3; w++)
          _week(inputs, weekStart: addDays(_monday, 7 * w))
              .sessions
              .single
              .templateId,
      };
      expect(ids.length, 3);
      final first = _week(inputs).sessions.single;
      expect(first.reasons, contains(ReasonCode.templateRotation));
    });

    test('rotation repeats predictably', () {
      final inputs = _inputs(
        goal: TrainingGoal.improveTechnique,
        level: ExperienceLevel.beginner,
        weekdays: [2],
      );
      final a = _week(inputs, weekStart: _monday).sessions.single.templateId;
      final b = _week(inputs, weekStart: addDays(_monday, 21))
          .sessions
          .single
          .templateId;
      expect(a, b);
    });
  });

  group('sparring', () {
    PlanInputs sparringInputs(ExperienceLevel level, {FightContext? fight}) =>
        _inputs(
          disciplines: [Discipline.boxing, Discipline.wrestling],
          goal: TrainingGoal.competitionPrep,
          level: level,
          weekdays: [1, 2, 3, 4, 5, 6],
          fight: fight,
        );

    test('beginners never get sparring, in any week', () {
      for (var w = 0; w < 8; w++) {
        final week = _week(
          sparringInputs(ExperienceLevel.beginner),
          weekStart: addDays(_monday, 7 * w),
        );
        expect(
          week.sessions.any((s) => s.kind == SessionKind.sparring),
          isFalse,
        );
        expect(week.reasons, contains(ReasonCode.noSparringForBeginner));
      }
    });

    test('beginners never get a sparring template even from a bad set', () {
      final sparringOnly = TemplateSet(version: 1, templates: [
        for (final t in placeholderTemplateSet.templates)
          if (t.kind != SessionKind.skill) t,
      ]);
      final week = _week(
        sparringInputs(ExperienceLevel.beginner),
        templates: sparringOnly,
      );
      for (final s in week.sessions) {
        expect(s.templateId, isNot(contains('sparring')));
      }
    });

    test('intermediate gets one sparring session, advanced up to two', () {
      int count(ExperienceLevel level) => _week(sparringInputs(level))
          .sessions
          .where((s) => s.kind == SessionKind.sparring)
          .length;
      expect(count(ExperienceLevel.intermediate), 1);
      expect(count(ExperienceLevel.advanced), 2);
      expect(count(ExperienceLevel.competitor), 2);
    });

    test('sparring sessions are hard, include the reason, and keep a skill day',
        () {
      final week = _week(sparringInputs(ExperienceLevel.advanced));
      final sparring =
          week.sessions.where((s) => s.kind == SessionKind.sparring);
      expect(sparring, isNotEmpty);
      for (final s in sparring) {
        expect(s.reasons, contains(ReasonCode.sparringIncluded));
        expect(s.discipline, isNotNull);
      }
      expect(week.sessions.any((s) => s.kind == SessionKind.skill), isTrue);
    });

    test('goals that do not train for a fight get no sparring', () {
      for (final goal in [
        TrainingGoal.loseFat,
        TrainingGoal.buildFitness,
        TrainingGoal.buildMuscle,
      ]) {
        final week = _week(_inputs(
          goal: goal,
          level: ExperienceLevel.advanced,
          weekdays: [1, 2, 3, 4, 5],
        ));
        expect(
          week.sessions.any((s) => s.kind == SessionKind.sparring),
          isFalse,
          reason: '$goal',
        );
      }
    });

    test('a set with no sparring template falls back to skill', () {
      final noSparring = TemplateSet(version: 1, templates: [
        for (final t in placeholderTemplateSet.templates)
          if (t.kind != SessionKind.sparring) t,
      ]);
      final week = _week(
        sparringInputs(ExperienceLevel.advanced),
        templates: noSparring,
      );
      expect(
        week.sessions.any((s) => s.kind == SessionKind.sparring),
        isFalse,
      );
    });

    test('there is no sparring in fight week', () {
      final fightDate = DateTime.utc(2026, 10, 24);
      final week = _week(
        sparringInputs(
          ExperienceLevel.advanced,
          fight: _fight(fightDate, weighIn: DateTime.utc(2026, 10, 23)),
        ),
      );
      expect(
        week.sessions.any((s) => s.kind == SessionKind.sparring),
        isFalse,
      );
    });
  });

  group('gym classes', () {
    test('a gym-class day is a gym class with no blocks', () {
      final week = _week(
        _inputs(weekdays: [1, 3], gymClassWeekdays: [2, 4]),
      );
      final gym = week.sessions.where((s) => s.kind == SessionKind.gymClass);
      expect(gym.map((s) => s.date.weekday).toSet(), {2, 4});
      for (final s in gym) {
        expect(s.blocks, isEmpty);
        expect(s.reasons, contains(ReasonCode.gymClassDay));
      }
      expect(week.reasons, contains(ReasonCode.gymClassCountsAsSkill));
    });

    test('a gym-class weekday is a training day even if not listed', () {
      final inputs = _inputs(weekdays: [1], gymClassWeekdays: [4]);
      expect(inputs.trainingWeekdays, {1, 4});
      expect(_trainingWeekdays(_week(inputs)), {1, 4});
    });

    test('a gym class counts as skill work: other days are not all skill', () {
      final week = _week(
        _inputs(
          goal: TrainingGoal.buildFitness,
          weekdays: [1, 3, 5],
          gymClassWeekdays: [2],
        ),
      );
      final others = week.sessions.where((s) => s.kind != SessionKind.gymClass);
      expect(others.any((s) => s.kind != SessionKind.skill), isTrue);
    });

    test('a gym class is not trimmed by the taper', () {
      final fightDate = DateTime.utc(2026, 10, 24);
      final week = _week(
        _inputs(
          weekdays: [],
          gymClassWeekdays: [2],
          fight: _fight(fightDate, weighIn: DateTime.utc(2026, 10, 23)),
        ),
      );
      final gym = week.sessions.single;
      expect(gym.kind, SessionKind.gymClass);
      expect(gym.estimatedMinutes, 60);
    });
  });

  group('spacing', () {
    test('never three hard sessions in a row', () {
      for (final goal in TrainingGoal.values) {
        for (final level in ExperienceLevel.values) {
          final week = _week(_inputs(
            goal: goal,
            level: level,
            weekdays: [1, 2, 3, 4, 5, 6, 7],
            disciplines: [Discipline.boxing, Discipline.wrestling],
          ));
          var run = 0;
          for (final day in week.days) {
            final hard = day.sessions.any((s) => s.intensity == Intensity.hard);
            run = hard ? run + 1 : 0;
            expect(run, lessThanOrEqualTo(2), reason: '$goal $level');
          }
        }
      }
    });

    test('a spaced recovery day is light and says why', () {
      var found = false;
      for (final goal in TrainingGoal.values) {
        final week = _week(_inputs(
          goal: goal,
          level: ExperienceLevel.advanced,
          weekdays: [1, 2, 3, 4, 5, 6, 7],
        ));
        for (final s in week.sessions) {
          if (s.reasons.contains(ReasonCode.recoveryAfterHardDays)) {
            found = true;
            expect(s.kind, SessionKind.recovery);
            expect(s.intensity, Intensity.light);
          }
        }
      }
      expect(found, isTrue);
    });

    test('a recovery session has the recovery day type', () {
      final week = _week(_inputs(
        goal: TrainingGoal.competitionPrep,
        level: ExperienceLevel.advanced,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
      ));
      for (final day in week.days) {
        for (final s in day.sessions) {
          if (s.kind == SessionKind.recovery) {
            expect(day.type, DayType.recovery);
          }
        }
      }
    });
  });

  group('fight phases', () {
    final fightDate = DateTime.utc(2026, 11, 28); // Saturday
    final fight = _fight(fightDate, weighIn: DateTime.utc(2026, 11, 27));

    PlanInputs fightInputs({List<int>? weekdays}) => _inputs(
          disciplines: [Discipline.boxing, Discipline.wrestling],
          goal: TrainingGoal.competitionPrep,
          level: ExperienceLevel.advanced,
          weekdays: weekdays ?? [1, 2, 3, 4, 5, 6, 7],
          startDate: DateTime.utc(2026, 9, 28),
          fight: fight,
        );

    PlannedWeek weekOf(DateTime monday) =>
        _week(fightInputs(), weekStart: monday);

    test('phaseOn follows the proposal day counts', () {
      TrainingPhase on(int daysBefore) =>
          fight.phaseOn(addDays(fightDate, -daysBefore));
      expect(on(100), TrainingPhase.general);
      expect(on(57), TrainingPhase.general);
      expect(on(56), TrainingPhase.build);
      expect(on(22), TrainingPhase.build);
      expect(on(21), TrainingPhase.peak);
      expect(on(11), TrainingPhase.peak);
      expect(on(10), TrainingPhase.taper);
      expect(on(2), TrainingPhase.taper);
      expect(on(1), TrainingPhase.weighIn);
      expect(on(0), TrainingPhase.fightDay);
      expect(on(-1), TrainingPhase.postFight);
      expect(on(-7), TrainingPhase.postFight);
      expect(on(-8), TrainingPhase.general);
    });

    test('a same-day weigh-in goes straight to the fight day', () {
      final sameDay = _fight(fightDate);
      expect(sameDay.weighInOffsetDays, 0);
      expect(sameDay.phaseOn(fightDate), TrainingPhase.fightDay);
      expect(sameDay.phaseOn(addDays(fightDate, -1)), TrainingPhase.taper);
      expect(fight.weighInOffsetDays, 1);
    });

    test('far from the fight the plan is general and says so', () {
      final week = weekOf(DateTime.utc(2026, 9, 28));
      var general = 0;
      for (final s in week.sessions) {
        if (fight.phaseOn(s.date) != TrainingPhase.general) continue;
        general++;
        expect(s.reasons, contains(ReasonCode.generalPhase));
      }
      expect(general, greaterThan(3));
    });

    test('the build phase says so', () {
      final week = weekOf(DateTime.utc(2026, 10, 19));
      expect(
        week.sessions.every((s) => s.reasons.contains(ReasonCode.buildPhase)),
        isTrue,
      );
    });

    test('the peak phase trims volume a little', () {
      final peak = weekOf(DateTime.utc(2026, 11, 9));
      final build = weekOf(DateTime.utc(2026, 10, 19));
      final peakSession =
          peak.sessions.firstWhere((s) => s.kind == SessionKind.skill);
      final buildSession =
          build.sessions.firstWhere((s) => s.kind == SessionKind.skill);
      expect(peakSession.reasons, contains(ReasonCode.peakPhase));
      expect(peakSession.estimatedMinutes,
          lessThan(buildSession.estimatedMinutes));
    });

    test('fight week is a taper: lighter, shorter, no hard sessions', () {
      final week = weekOf(DateTime.utc(2026, 11, 23));
      final taper = week.sessions
          .where((s) => s.reasons.contains(ReasonCode.taperFightWeek));
      expect(taper, isNotEmpty);
      for (final s in taper) {
        expect(s.intensity.index, lessThanOrEqualTo(Intensity.moderate.index));
        expect(s.kind, isNot(SessionKind.sparring));
      }
      final build = weekOf(DateTime.utc(2026, 10, 19));
      final taperSkill = taper.firstWhere((s) => s.kind == SessionKind.skill);
      final buildSkill =
          build.sessions.firstWhere((s) => s.kind == SessionKind.skill);
      // Volume is about 40% lower.
      expect(
        taperSkill.estimatedMinutes,
        closeTo(buildSkill.estimatedMinutes * PhaseModifiers.taperVolume, 1),
      );
    });

    test('the weigh-in day is a light recovery session', () {
      final week = weekOf(DateTime.utc(2026, 11, 23));
      final day =
          week.days.firstWhere((d) => d.date == DateTime.utc(2026, 11, 27));
      expect(day.type, DayType.weighIn);
      final s = day.sessions.single;
      expect(s.kind, SessionKind.recovery);
      expect(s.intensity, Intensity.light);
      expect(s.reasons, contains(ReasonCode.weighInLight));
    });

    test('the fight day is planned as no training', () {
      final week = weekOf(DateTime.utc(2026, 11, 23));
      final day = week.days.firstWhere((d) => d.date == fightDate);
      expect(day.type, DayType.fight);
      expect(day.sessions, isEmpty);
      expect(day.reasons, contains(ReasonCode.fightDayRest));
    });

    test('no session is planned between the weigh-in and the fight', () {
      final both = _fight(
        DateTime.utc(2026, 11, 28),
        weighIn: DateTime.utc(2026, 11, 26),
      );
      final week = _week(
        _inputs(
          weekdays: [1, 2, 3, 4, 5, 6, 7],
          startDate: DateTime.utc(2026, 9, 28),
          fight: both,
        ),
        weekStart: DateTime.utc(2026, 11, 23),
      );
      final refuel = week.days.firstWhere(
        (d) => d.date == DateTime.utc(2026, 11, 27),
      );
      expect(refuel.sessions, isEmpty);
      expect(refuel.reasons, contains(ReasonCode.refuelDayRest));
      expect(refuel.type, DayType.rest);
    });

    test('the week after the fight is light recovery only', () {
      final week = weekOf(DateTime.utc(2026, 11, 30));
      final after = week.sessions
          .where((s) => fight.phaseOn(s.date) == TrainingPhase.postFight);
      expect(after, isNotEmpty);
      for (final s in after) {
        expect(s.kind, SessionKind.recovery);
        expect(s.intensity, Intensity.light);
        expect(s.reasons, contains(ReasonCode.postFightRecovery));
      }
    });

    test('long after the fight the plan is general again', () {
      final week = weekOf(DateTime.utc(2026, 12, 14));
      for (final s in week.sessions) {
        expect(s.reasons, contains(ReasonCode.generalPhase));
      }
    });

    test('a fight date changes the plan against the same inputs without one',
        () {
      final without = _week(
        _inputs(
          weekdays: [1, 2, 3, 4, 5, 6, 7],
          goal: TrainingGoal.competitionPrep,
          level: ExperienceLevel.advanced,
          startDate: DateTime.utc(2026, 9, 28),
        ),
        weekStart: DateTime.utc(2026, 11, 23),
      );
      final withFight = weekOf(DateTime.utc(2026, 11, 23));
      expect(
        jsonEncode(without.toJson()),
        isNot(jsonEncode(withFight.toJson())),
      );
    });

    test('no phase ever plans a session on a non-trainable day', () {
      for (var w = 0; w < 14; w++) {
        final week = weekOf(addDays(DateTime.utc(2026, 9, 28), 7 * w));
        for (final day in week.days) {
          final phase = fight.phaseOn(day.date);
          if (!PhaseModifiers.forPhase(phase).trainable) {
            expect(day.sessions, isEmpty, reason: '${day.date} $phase');
          }
        }
      }
    });

    test('every phase has a modifier and a ceiling', () {
      for (final phase in TrainingPhase.values) {
        final modifier = PhaseModifiers.forPhase(phase);
        expect(modifier.volume, inInclusiveRange(0, 1));
        expect(modifier.reason, isNotNull);
      }
      expect(PhaseModifiers.taperVolume, 0.6);
    });
  });

  group('missing templates', () {
    test('an empty set plans the sessions with fallback titles', () {
      final week = _week(
        _inputs(weekdays: [1, 3, 5]),
        templates: const TemplateSet(version: 1, templates: []),
      );
      expect(week.sessions, hasLength(3));
      for (final s in week.sessions) {
        expect(s.templateId, isNull);
        expect(s.titleKey, s.kind.fallbackTitleKey);
        expect(s.blocks, isEmpty);
        expect(s.reasons, contains(ReasonCode.noTemplateAvailable));
        expect(s.estimatedMinutes,
            ExperienceLevel.intermediate.defaultSessionMinutes);
      }
    });

    test('matching relaxes and says so', () {
      // The placeholder set has no moderate/hard skill for competitor in the
      // taper except the light boxing one; wrestling falls back to relaxed
      // matching.
      final fightDate = DateTime.utc(2026, 10, 24);
      final week = _week(
        _inputs(
          disciplines: [Discipline.mma],
          goal: TrainingGoal.improveTechnique,
          level: ExperienceLevel.competitor,
          weekdays: [1, 2],
          startDate: DateTime.utc(2026, 9, 1),
          fight: _fight(fightDate, weighIn: DateTime.utc(2026, 10, 23)),
        ),
      );
      for (final s in week.sessions) {
        expect(s.templateId, isNotNull);
      }
    });
  });

  group('generic launch set', () {
    test('plans every goal and level without gaps', () {
      for (final goal in TrainingGoal.values) {
        for (final level in ExperienceLevel.values) {
          final week = _week(
            _inputs(
              goal: goal,
              level: level,
              weekdays: [1, 2, 3, 4, 5, 6],
              disciplines: [Discipline.boxing, Discipline.mma],
            ),
            templates: GenericTemplateSet.instance,
          );
          for (final s in week.sessions) {
            expect(s.templateId, isNotNull, reason: '$goal $level ${s.kind}');
            expect(s.templateId, startsWith('generic.'));
          }
        }
      }
    });

    test('is marked as a placeholder awaiting sign-off', () {
      expect(GenericTemplateSet.version, 1);
      for (final t in GenericTemplateSet.instance.templates) {
        expect(t.id, startsWith('generic.'));
        // No invented methodology: no drills, no cues, no energy values.
        expect(t.energyMet, isNull);
        for (final b in t.blocks) {
          expect(b.drillIds, isEmpty);
          expect(b.cueKeys, isEmpty);
          expect(b.rounds, isNull);
        }
      }
    });
  });
}
