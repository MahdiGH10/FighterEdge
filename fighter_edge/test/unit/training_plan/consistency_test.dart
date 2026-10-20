import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/training_plan/domain/consistency/freeze_rules.dart';
import 'package:fighter_edge/features/training_plan/domain/consistency/weekly_adherence.dart';
import 'package:fighter_edge/features/training_plan/domain/consistency/weekly_streak.dart';
import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/plan_inputs.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_session.dart';
import 'package:fighter_edge/features/training_plan/domain/models/planned_week.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_goal.dart';
import 'package:fighter_edge/features/training_plan/domain/session_status_resolver.dart';
import 'package:fighter_edge/features/training_plan/domain/training_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/placeholder_template_set.dart';

final _monday = DateTime.utc(2026, 10, 19);
const _resolver = SessionStatusResolver();

PlanInputs _inputs(
  List<int> weekdays, {
  DateTime? start,
  TrainingGoal goal = TrainingGoal.buildFitness,
}) =>
    PlanInputs(
      disciplines: [Discipline.boxing],
      goal: goal,
      level: ExperienceLevel.intermediate,
      weekdays: weekdays,
      startDate: start ?? _monday,
    );

PlannedWeek _week(PlanInputs inputs, [DateTime? weekStart]) =>
    const TrainingPlanGenerator()
        .week(inputs, weekStart ?? _monday, placeholderTemplateSet);

/// Completion records for the sessions at [indexes] (in date order), by id.
List<CompletionRecord> _done(PlannedWeek week, Iterable<int> indexes) {
  final sessions = week.sessions.toList();
  return [
    for (final i in indexes)
      CompletionRecord(
        plannedSessionId: sessions[i].id,
        date: sessions[i].date,
      ),
  ];
}

WeeklyAdherence _adherence(
  PlannedWeek week,
  DateTime today, {
  Iterable<int> done = const [],
  Iterable<SessionAdjustment> adjustments = const [],
  int freezeCovered = 0,
}) =>
    WeeklyAdherence.fromResolved(
      weekStart: week.weekStart,
      resolved: _resolver.resolve(
        weeks: [week],
        today: today,
        completions: _done(week, done),
        adjustments: adjustments,
      ),
      today: today,
      freezeCovered: freezeCovered,
    );

void main() {
  group('weekly target', () {
    test('is every planned session, or one fewer from five', () {
      expect(WeeklyTarget.forPlanned(0), 0);
      expect(WeeklyTarget.forPlanned(1), 1);
      expect(WeeklyTarget.forPlanned(3), 3);
      expect(WeeklyTarget.forPlanned(4), 4);
      expect(WeeklyTarget.forPlanned(5), 4);
      expect(WeeklyTarget.forPlanned(7), 6);
    });
  });

  group('status resolver', () {
    // Mon, Wed, Fri.
    final week = _week(_inputs([1, 3, 5]));
    final sessions = week.sessions.toList();

    SessionStatus statusOn(DateTime today, Iterable<int> done) {
      final rows = _resolver.resolve(
        weeks: [week],
        today: today,
        completions: _done(week, done),
      );
      return rows.firstWhere((r) => r.session.id == sessions[1].id).status;
    }

    test('future sessions are planned, today is today', () {
      expect(statusOn(DateTime.utc(2026, 10, 19), []), SessionStatus.planned);
      expect(statusOn(DateTime.utc(2026, 10, 21), []), SessionStatus.today);
    });

    test('a past session nobody did is missed', () {
      expect(statusOn(DateTime.utc(2026, 10, 22), []), SessionStatus.missed);
    });

    test('a logged session is completed whenever it is looked at', () {
      for (final day in [19, 21, 25]) {
        expect(
          statusOn(DateTime.utc(2026, 10, day), [1]),
          SessionStatus.completed,
        );
      }
    });

    test('skipped is neutral; completed wins over skipped', () {
      final skipped = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 25),
        adjustments: [SessionAdjustment.skipped(sessions[0].id)],
      );
      expect(skipped.first.status, SessionStatus.skipped);
      final both = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 25),
        completions: _done(week, [0]),
        adjustments: [SessionAdjustment.skipped(sessions[0].id)],
      );
      expect(both.first.status, SessionStatus.completed);
    });

    test('a moved session shows twice: moved, then its real status', () {
      final rows = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 20),
        adjustments: [
          SessionAdjustment.moved(sessions[0].id, DateTime.utc(2026, 10, 23)),
        ],
      );
      final id = sessions[0].id;
      final original = rows.firstWhere(
        (r) => r.session.id == id && r.status == SessionStatus.moved,
      );
      expect(original.date, DateTime.utc(2026, 10, 19));
      expect(original.movedTo, DateTime.utc(2026, 10, 23));
      final shown = rows.firstWhere(
        (r) => r.session.id == id && r.status != SessionStatus.moved,
      );
      expect(shown.date, DateTime.utc(2026, 10, 23));
      expect(shown.status, SessionStatus.planned);
      expect(shown.movedFrom, DateTime.utc(2026, 10, 19));
    });

    test('rows come out in date order', () {
      final rows = _resolver.resolve(
        weeks: [week],
        today: _monday,
        adjustments: [
          SessionAdjustment.moved(sessions[0].id, DateTime.utc(2026, 10, 24)),
        ],
      );
      final dates = [for (final r in rows) r.date];
      expect([...dates]..sort(), dates);
    });

    test('a record without an id completes a session on that date, once', () {
      final record = CompletionRecord(date: DateTime.utc(2026, 10, 21));
      final rows = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 25),
        completions: [record, record],
      );
      expect(
        rows.where((r) => r.status == SessionStatus.completed),
        hasLength(1),
      );
    });

    test('a record on a rest day completes nothing', () {
      final rows = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 25),
        completions: [CompletionRecord(date: DateTime.utc(2026, 10, 20))],
      );
      expect(rows.any((r) => r.status == SessionStatus.completed), isFalse);
    });

    test('a named record completes the named session, not another', () {
      final rows = _resolver.resolve(
        weeks: [week],
        today: DateTime.utc(2026, 10, 25),
        completions: [
          CompletionRecord(
            plannedSessionId: sessions[2].id,
            date: DateTime.utc(2026, 10, 21),
          ),
        ],
      );
      final done = rows.where((r) => r.status == SessionStatus.completed);
      expect(done.single.session.id, sessions[2].id);
    });

    test('rest days are rest, and days before the start are beforeStart', () {
      final mid = _week(
        _inputs([1, 2, 3, 4, 5, 6, 7], start: DateTime.utc(2026, 10, 22)),
      );
      expect(
        _resolver.emptyDayStatus(mid, mid.days[0]),
        SessionStatus.beforeStart,
      );
      expect(week.days[1].sessions, isEmpty);
      expect(_resolver.emptyDayStatus(week, week.days[1]), SessionStatus.rest);
    });

    test('a recovery session nobody did is rest, never missed', () {
      final recovery = PlannedSession(
        id: 'r',
        date: DateTime.utc(2026, 10, 19),
        kind: SessionKind.recovery,
        intensity: Intensity.light,
        titleKey: 'tplGenericRecovery',
        estimatedMinutes: 30,
      );
      expect(
        _resolver.statusOf(
          recovery,
          date: recovery.date,
          today: DateTime.utc(2026, 10, 25),
        ),
        SessionStatus.rest,
      );
      expect(
        _resolver.statusOf(
          recovery,
          date: recovery.date,
          today: DateTime.utc(2026, 10, 25),
          completed: true,
        ),
        SessionStatus.completed,
      );
    });
  });

  group('weekly adherence', () {
    final week = _week(_inputs([1, 3, 5]));

    test('an open week with nothing done is still possible', () {
      final a = _adherence(week, DateTime.utc(2026, 10, 19));
      expect(a.planned, 3);
      expect(a.completed, 0);
      expect(a.upcoming, 3);
      expect(a.target, 3);
      expect(a.met, isFalse);
      expect(a.alive, isTrue);
      expect(a.closed, isFalse);
      expect(a.ratio, 0);
    });

    test('rest days are not planned sessions and never count against', () {
      final a = _adherence(week, DateTime.utc(2026, 10, 26));
      expect(a.planned, 3); // not 7
      expect(a.missed, 3);
      expect(a.skipped, 0);
    });

    test('doing everything meets the target', () {
      final a = _adherence(week, DateTime.utc(2026, 10, 25), done: [0, 1, 2]);
      expect(a.completed, 3);
      expect(a.met, isTrue);
      expect(a.ratio, 1);
      expect(a.missed, 0);
    });

    test('a missed session in a 3-day week ends the chance this week', () {
      final a = _adherence(week, DateTime.utc(2026, 10, 24), done: [0, 1]);
      expect(a.missed, 1);
      expect(a.met, isFalse);
      expect(a.alive, isFalse);
    });

    test('the week is closed once it is over', () {
      expect(_adherence(week, DateTime.utc(2026, 10, 25)).closed, isFalse);
      expect(_adherence(week, DateTime.utc(2026, 10, 26)).closed, isTrue);
    });

    test('a skipped session is neither done nor missed', () {
      final sessions = week.sessions.toList();
      final a = _adherence(
        week,
        DateTime.utc(2026, 10, 26),
        done: [0, 1],
        adjustments: [SessionAdjustment.skipped(sessions[2].id)],
      );
      expect(a.skipped, 1);
      expect(a.missed, 0);
      expect(a.completed, 2);
      expect(a.planned, 3);
    });

    test('a five-session week needs four', () {
      final five = _week(
        _inputs([1, 2, 3, 4, 5], goal: TrainingGoal.improveTechnique),
      );
      final a =
          _adherence(five, DateTime.utc(2026, 10, 26), done: [0, 1, 2, 3]);
      expect(a.planned, 5);
      expect(a.target, 4);
      expect(a.met, isTrue);
      final b = _adherence(five, DateTime.utc(2026, 10, 26), done: [0, 1, 2]);
      expect(b.met, isFalse);
    });

    test('recovery sessions are never counted', () {
      final hard = _week(PlanInputs(
        disciplines: [Discipline.boxing, Discipline.wrestling],
        goal: TrainingGoal.competitionPrep,
        level: ExperienceLevel.advanced,
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        startDate: _monday,
      ));
      final recoveries =
          hard.sessions.where((s) => s.kind == SessionKind.recovery).length;
      expect(recoveries, greaterThan(0));
      final a = _adherence(hard, DateTime.utc(2026, 10, 26));
      expect(a.planned, hard.sessions.length - recoveries);
      expect(a.missed, a.planned);
    });

    test('a week before the plan start is rest only and neutral', () {
      final early = _week(
        _inputs([1, 3, 5], start: DateTime.utc(2026, 10, 26)),
      );
      final a = _adherence(early, DateTime.utc(2026, 10, 28));
      expect(a.planned, 0);
      expect(a.isRestOnly, isTrue);
      expect(a.target, 0);
      expect(a.ratio, 0);
    });

    test('a moved session counts once, in the week of its new date', () {
      final inputs = _inputs([1, 3, 5]);
      final first = _week(inputs);
      final second = _week(inputs, DateTime.utc(2026, 10, 26));
      final resolved = _resolver.resolve(
        weeks: [first, second],
        today: DateTime.utc(2026, 10, 28),
        adjustments: [
          SessionAdjustment.moved(
            first.sessions.first.id,
            DateTime.utc(2026, 10, 27),
          ),
        ],
      );
      WeeklyAdherence of(PlannedWeek w) => WeeklyAdherence.fromResolved(
            weekStart: w.weekStart,
            resolved: resolved,
            today: DateTime.utc(2026, 10, 28),
          );
      expect(of(first).planned, 2);
      expect(of(second).planned, 4);
    });

    test('a freeze counts toward the target', () {
      final a = _adherence(
        week,
        DateTime.utc(2026, 10, 26),
        done: [0, 1],
        freezeCovered: 1,
      );
      expect(a.completed, 2);
      expect(a.effectiveCompleted, 3);
      expect(a.met, isTrue);
    });
  });

  group('freeze rules', () {
    WeeklyAdherence adherence(int planned, int completed, int missed) =>
        WeeklyAdherence(
          weekStart: _monday,
          planned: planned,
          completed: completed,
          missed: missed,
          closed: true,
        );

    test('cover one missed session that brings the week to its target', () {
      expect(FreezeRules.covered(adherence(3, 2, 1), freezesAvailable: 1), 1);
      expect(FreezeRules.covered(adherence(5, 3, 2), freezesAvailable: 2), 1);
    });

    test('are not spent when they would not help', () {
      expect(FreezeRules.covered(adherence(3, 1, 2), freezesAvailable: 3), 0);
      expect(FreezeRules.covered(adherence(3, 3, 0), freezesAvailable: 3), 0);
      expect(FreezeRules.covered(adherence(5, 4, 1), freezesAvailable: 3), 0);
    });

    test('need a freeze to spend and a missed session to cover', () {
      expect(FreezeRules.covered(adherence(3, 2, 1), freezesAvailable: 0), 0);
      // The third session was skipped, not missed: nothing to cover.
      expect(FreezeRules.covered(adherence(3, 2, 0), freezesAvailable: 1), 0);
    });

    test('apply returns the week with the freeze counted', () {
      final applied = FreezeRules.apply(
        adherence(3, 2, 1),
        freezesAvailable: 1,
      );
      expect(applied.freezeCovered, 1);
      expect(applied.met, isTrue);
      final unchanged = FreezeRules.apply(
        adherence(3, 1, 2),
        freezesAvailable: 1,
      );
      expect(unchanged.freezeCovered, 0);
      expect(unchanged.met, isFalse);
    });

    test('a rest-only week has nothing to cover', () {
      expect(FreezeRules.covered(adherence(0, 0, 0), freezesAvailable: 5), 0);
    });
  });

  group('weekly streak', () {
    WeeklyAdherence closedWeek(int planned, int completed, {int freeze = 0}) =>
        WeeklyAdherence(
          weekStart: _monday,
          planned: planned,
          completed: completed,
          missed: planned - completed,
          freezeCovered: freeze,
          closed: true,
        );

    WeeklyAdherence openWeek(int planned, int completed, int upcoming) =>
        WeeklyAdherence(
          weekStart: _monday,
          planned: planned,
          completed: completed,
          upcoming: upcoming,
          closed: false,
        );

    test('no weeks is an empty, alive streak', () {
      final s = WeeklyStreak.of(const []);
      expect(s.count, 0);
      expect(s.currentWeekMet, isFalse);
      expect(s.currentWeekAlive, isTrue);
    });

    test('counts consecutive closed weeks that met the target', () {
      expect(
        WeeklyStreak.of([closedWeek(3, 3), closedWeek(3, 3), closedWeek(4, 4)])
            .count,
        3,
      );
    });

    test('a closed week below target resets the streak', () {
      expect(
        WeeklyStreak.of([
          closedWeek(3, 3),
          closedWeek(3, 3),
          closedWeek(3, 1),
          closedWeek(3, 3),
        ]).count,
        1,
      );
    });

    test('a five-session week with four done keeps the streak', () {
      expect(WeeklyStreak.of([closedWeek(5, 4), closedWeek(5, 4)]).count, 2);
    });

    test('a rest-only week neither extends nor breaks the streak', () {
      expect(
        WeeklyStreak.of([
          closedWeek(3, 3),
          closedWeek(0, 0),
          closedWeek(3, 3),
        ]).count,
        2,
      );
      expect(WeeklyStreak.of([closedWeek(3, 3), closedWeek(0, 0)]).count, 1);
    });

    test('a week saved by a freeze counts as met', () {
      expect(WeeklyStreak.of([closedWeek(3, 2, freeze: 1)]).count, 1);
    });

    test('an open week adds one once its target is met', () {
      final s = WeeklyStreak.of([closedWeek(3, 3), openWeek(3, 3, 0)]);
      expect(s.count, 2);
      expect(s.currentWeekMet, isTrue);
      expect(s.currentWeekAlive, isTrue);
    });

    test('an open week that can still be met keeps the streak', () {
      final s = WeeklyStreak.of([closedWeek(3, 3), openWeek(3, 1, 2)]);
      expect(s.count, 1);
      expect(s.currentWeekMet, isFalse);
      expect(s.currentWeekAlive, isTrue);
    });

    test('an open week that can no longer be met resets the streak', () {
      final s = WeeklyStreak.of([closedWeek(3, 3), openWeek(3, 1, 1)]);
      expect(s.count, 0);
      expect(s.currentWeekAlive, isFalse);
    });

    test('an open rest-only week leaves the streak as it was', () {
      final s = WeeklyStreak.of([closedWeek(3, 3), openWeek(0, 0, 0)]);
      expect(s.count, 1);
      expect(s.currentWeekAlive, isTrue);
    });

    test('a streak built from real generated weeks', () {
      final inputs = _inputs([1, 3, 5]);
      final weeks = [
        for (var w = 0; w < 4; w++) _week(inputs, addDays(_monday, 7 * w)),
      ];
      final today = addDays(_monday, 22); // Wednesday of week 4
      final completions = [
        for (final week in weeks.take(3))
          for (final s in week.sessions)
            CompletionRecord(plannedSessionId: s.id, date: s.date),
        CompletionRecord(
          plannedSessionId: weeks[3].sessions.first.id,
          date: weeks[3].sessions.first.date,
        ),
      ];
      final resolved = _resolver.resolve(
        weeks: weeks,
        today: today,
        completions: completions,
      );
      final streak = WeeklyStreak.of([
        for (final week in weeks)
          WeeklyAdherence.fromResolved(
            weekStart: week.weekStart,
            resolved: resolved,
            today: today,
          ),
      ]);
      expect(streak.count, 3);
      expect(streak.currentWeekMet, isFalse);
      expect(streak.currentWeekAlive, isTrue);
    });
  });
}
