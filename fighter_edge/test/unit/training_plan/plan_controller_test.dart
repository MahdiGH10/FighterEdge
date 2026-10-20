import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/data/stored_training_plan.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_status.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';

/// Monday 2026-10-19 starts the week the tests live in.
final _monday = DateTime(2026, 10, 19, 9);
const _uid = 'fighter';

LegacySessionSlot _slot(String day, String title) =>
    LegacySessionSlot(id: '$day-$title', day: day, title: title);

/// Everything a screen needs, wired the way the app wires it, with a clock
/// the test moves.
class _Rig {
  _Rig(this.repo, this.now) {
    state = AppState(dataRepository: repo, clock: () => now)..setUser(_uid);
    plan = PlanController(log: state, repository: repo, sync: sync)
      ..configure(userId: _uid, goal: 'Gain muscle', level: 'Intermediate');
  }

  final InMemoryDataRepository repo;
  DateTime now;
  final sync = SyncTracker();
  late final AppState state;
  late final PlanController plan;

  Future<void> settle() => pumpEventQueue();

  void dispose() {
    plan.dispose();
    state.dispose();
  }
}

Future<_Rig> _rig({
  required InMemoryDataRepository repo,
  DateTime? at,
}) async {
  final rig = _Rig(repo, at ?? _monday);
  addTearDown(rig.dispose);
  await rig.settle();
  return rig;
}

/// A repository whose plan writes the server refuses.
class _RefusingRepository extends InMemoryDataRepository {
  @override
  Future<void> saveTrainingPlan(String userId, StoredTrainingPlan plan) =>
      Future.error(StateError('permission-denied'));
}

void main() {
  late InMemoryDataRepository repo;

  setUp(() {
    repo = InMemoryDataRepository();
    addTearDown(repo.dispose);
  });

  group('one-time migration', () {
    Future<void> seedLegacy() async {
      for (final slot in [
        _slot('Mon', 'Striking'),
        _slot('Wed', 'Wrestling'),
        _slot('Fri', 'BJJ'),
      ]) {
        await repo.saveLegacySession(_uid, slot);
      }
    }

    test('turns the weekday schedule into a saved, dated plan', () async {
      await seedLegacy();
      final rig = await _rig(repo: repo);

      expect(rig.plan.hasPlan, isTrue);
      expect(rig.plan.trainingWeekdays,
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
      final saved = (await repo.watchTrainingPlan(_uid).first)!;
      expect(saved.origin, PlanOrigin.migration);
      expect(saved.generatorVersion, isNotNull);
      expect(saved.inputs.level.name, 'intermediate',
          reason: 'taken from the profile answers');
    });

    test('runs once: the saved plan wins over later changes to the old docs',
        () async {
      await seedLegacy();
      final first = await _rig(repo: repo);
      first.plan.skip(first.plan.todaySession!.session);
      await first.settle();

      // The old schedule changes afterwards; a new launch must not redo it.
      await repo.saveLegacySession(_uid, _slot('Sat', 'Strength'));
      final second = await _rig(repo: repo);

      expect(second.plan.trainingWeekdays,
          {DateTime.monday, DateTime.wednesday, DateTime.friday});
      expect(second.plan.rows.where((r) => r.status == SessionStatus.skipped),
          hasLength(1),
          reason: 'the skip survived the reload');
    });

    test('leaves the old documents and the log untouched', () async {
      await seedLegacy();
      await repo.saveTrainingLogEntry(
        _uid,
        TrainingLogEntry(
          id: 'old',
          completedAt: DateTime(2026, 10, 12, 18),
          source: TrainingSource.planned,
          title: 'Striking',
          planSlotId: 'Mon-Striking',
        ),
      );
      final rig = await _rig(repo: repo);

      expect(await repo.watchLegacySessions(_uid).first, hasLength(3));
      expect(rig.state.trainingLog.single.id, 'old');
    });

    test('an account with no old schedule gets no plan', () async {
      final rig = await _rig(repo: repo);
      expect(rig.plan.loaded, isTrue);
      expect(rig.plan.hasPlan, isFalse);
      expect(rig.plan.rows, isEmpty);
      expect(rig.plan.todayRow, isNull);
      expect(await repo.watchTrainingPlan(_uid).first, isNull);
    });

    test('does not overwrite a plan made while it was reading', () async {
      await seedLegacy();
      final rig = _Rig(repo, _monday);
      addTearDown(rig.dispose);
      // The athlete finishes onboarding before the migration read returns.
      rig.plan.startFresh(
          weeklyTrainingDays: 2, goal: 'Gain muscle', level: 'Beginner');
      await rig.settle();

      expect(rig.plan.trainingWeekdays, {DateTime.monday, DateTime.thursday});
      final saved = (await repo.watchTrainingPlan(_uid).first)!;
      expect(saved.origin, PlanOrigin.onboarding);
    });

    test('old log entries with a weekday-slot id still count for their day',
        () async {
      await seedLegacy();
      await repo.saveTrainingLogEntry(
        _uid,
        TrainingLogEntry(
          id: 'plan-Mon-Striking-2026-10-19',
          completedAt: DateTime(2026, 10, 19, 8),
          source: TrainingSource.planned,
          title: 'Striking',
          planSlotId: 'Mon-Striking',
        ),
      );
      final rig = await _rig(repo: repo);

      expect(rig.plan.todayRow?.status, SessionStatus.completed);
    });
  });

  group('the dated week', () {
    test('the same inputs give the same week after a reload', () async {
      final first = await _rig(repo: repo);
      first.plan.startFresh(
          weeklyTrainingDays: 4, goal: 'Gain muscle', level: 'Intermediate');
      await first.settle();
      final before = [
        for (var w = 0; w < 4; w++)
          jsonEncode(
              first.plan.weekContaining(addDays(_monday, 7 * w))!.toJson()),
      ];

      final second = await _rig(repo: repo);
      final after = [
        for (var w = 0; w < 4; w++)
          jsonEncode(
              second.plan.weekContaining(addDays(_monday, 7 * w))!.toJson()),
      ];

      expect(second.plan.hasPlan, isTrue);
      expect(after, before);
    });

    test('session ids are dated and stable', () async {
      final rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      expect(rig.plan.todaySession!.session.id, startsWith('2026-10-19.'));
    });

    test('Home reads today first, then the next session, even next week',
        () async {
      final rig = await _rig(repo: repo, at: DateTime(2026, 10, 23, 9));
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');

      // Friday, the last session of the week (Mon/Wed/Fri).
      expect(rig.plan.todaySession?.date, DateTime.utc(2026, 10, 23));
      expect(rig.plan.nextSession?.date, DateTime.utc(2026, 10, 26),
          reason: 'next Monday');

      rig.plan.complete(rig.plan.todaySession!.session, title: 'x');
      expect(rig.plan.todaySession, isNull);
      expect(rig.plan.todayRow?.status, SessionStatus.completed);
    });

    test('the week view always has seven dates, Monday first', () async {
      final rig = await _rig(repo: repo, at: DateTime(2026, 10, 21, 9));
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      final days = rig.plan.weekDays();

      expect(days, hasLength(7));
      expect([for (final d in days) d.date.weekday], [1, 2, 3, 4, 5, 6, 7]);
      expect(days[0].emptyStatus, SessionStatus.beforeStart);
      expect(days[0].isRest, isTrue);
      expect(days[2].rows.single.status, SessionStatus.today);
      expect(days[3].emptyStatus, SessionStatus.rest);
    });

    test('a fight joins the plan but is never stored with it', () async {
      final rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 4, goal: 'Gain muscle', level: 'Intermediate');
      final general = rig.plan.inputs!.hash;
      final camp = FightCamp.tryCreate(
        fightDate: DateTime(2026, 11, 14),
        weightLimitKg: 70,
        category: CompetitionCategory.amateurStriking,
      )!;

      rig.plan.configure(userId: _uid, fight: camp);

      expect(rig.plan.inputs!.fight, isNotNull);
      expect(rig.plan.inputs!.hash, isNot(general));
      final saved = (await repo.watchTrainingPlan(_uid).first)!;
      expect(saved.inputs.fight, isNull);

      rig.plan.configure(userId: _uid);
      expect(rig.plan.inputs!.hash, general);
    });

    test('another account starts clean', () async {
      final rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 4, goal: 'Gain muscle', level: 'Intermediate');
      rig.plan.configure(userId: 'someone-else');
      await rig.settle();
      expect(rig.plan.hasPlan, isFalse);
      rig.plan.configure(userId: null);
      expect(rig.plan.hasPlan, isFalse);
      expect(rig.plan.rows, isEmpty);
    });
  });

  group('done, skipped and moved', () {
    late _Rig rig;

    setUp(() async {
      // Monday, three days a week: Mon, Wed, Fri.
      rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      await rig.settle();
    });

    test('completing logs the session and marks it done', () async {
      final session = rig.plan.todaySession!.session;
      rig.plan.complete(session, title: 'Skill session', rpe: 8, note: ' ok ');

      expect(rig.plan.todayRow!.status, SessionStatus.completed);
      final entry = rig.state.trainingLog.single;
      expect(entry.planSlotId, session.id);
      expect(entry.source, TrainingSource.planned);
      expect(entry.rpe, 8);
      expect(entry.note, 'ok');
      expect(entry.title, 'Skill session');
      expect(entry.detail['kind'], session.kind.name);
      expect(rig.plan.logEntryFor(session.id), same(entry));
    });

    test('completing again updates the effort and note, not a duplicate',
        () async {
      final session = rig.plan.todaySession!.session;
      rig.plan.complete(session, title: 't', rpe: 6);
      rig.now = rig.now.add(const Duration(hours: 2));
      rig.plan.complete(session, title: 't', rpe: 9, note: 'Edited');

      expect(rig.state.trainingLog, hasLength(1));
      expect(rig.state.trainingLog.single.rpe, 9);
      expect(rig.state.trainingLog.single.note, 'Edited');
      expect(rig.state.trainingLog.single.completedAt, _monday,
          reason: 'editing keeps when the session happened');
    });

    test('undoing takes the completion back', () async {
      final session = rig.plan.todaySession!.session;
      rig.plan.complete(session, title: 't');
      rig.plan.undoComplete(session);

      expect(rig.state.trainingLog, isEmpty);
      expect(rig.plan.todaySession?.session.id, session.id);
    });

    test('a skipped session is neutral and can be put back', () async {
      final session = rig.plan.todaySession!.session;
      rig.plan.skip(session);

      expect(rig.plan.todaySession, isNull);
      expect(rig.plan.todayRow, isNull);
      final skipped = rig.plan.rows.firstWhere((r) => r.session == session);
      expect(skipped.status, SessionStatus.skipped);
      expect(rig.plan.thisWeek.missed, 0);

      rig.plan.clearAdjustment(session);
      expect(rig.plan.todaySession?.session.id, session.id);
    });

    test('a missed session can be moved to today when today is free', () async {
      // Tuesday: Monday's session was not done, and Tuesday is a rest day.
      rig.now = DateTime(2026, 10, 20, 9);
      final missed =
          rig.plan.rows.firstWhere((r) => r.date == DateTime.utc(2026, 10, 19));
      expect(missed.status, SessionStatus.missed);
      expect(rig.plan.canMoveToToday(missed), isTrue);

      rig.plan.move(missed.session, rig.plan.today);

      expect(rig.plan.todaySession!.session.id, missed.session.id);
      final original = rig.plan.rows.firstWhere((r) =>
          r.session.id == missed.session.id && r.status == SessionStatus.moved);
      expect(original.movedTo, DateTime.utc(2026, 10, 20));
      expect(rig.plan.canMoveToToday(rig.plan.todaySession!), isFalse);
    });

    test('nothing can be moved onto a day that already has a session',
        () async {
      // Wednesday: Monday missed, but Wednesday has its own session.
      rig.now = DateTime(2026, 10, 21, 9);
      final missed =
          rig.plan.rows.firstWhere((r) => r.date == DateTime.utc(2026, 10, 19));
      expect(rig.plan.canMoveToToday(missed), isFalse);
    });

    test('skips, moves and completions all survive a reload', () async {
      final monday = rig.plan.todaySession!.session;
      rig.plan.skip(monday);
      rig.now = DateTime(2026, 10, 21, 9);
      final wednesday = rig.plan.todaySession!.session;
      rig.plan.move(wednesday, DateTime(2026, 10, 22));
      rig.plan.complete(
          rig.plan.rows
              .firstWhere((r) => r.date == DateTime.utc(2026, 10, 22))
              .session,
          title: 'x');
      await rig.settle();

      final again = await _rig(repo: repo, at: DateTime(2026, 10, 22, 9));
      final statuses = {
        for (final r in again.plan.rows) r.session.id: r.status,
      };
      expect(statuses[monday.id], SessionStatus.skipped);
      expect(statuses[wednesday.id], SessionStatus.completed,
          reason: 'moved to Thursday and done there');
    });

    test('saving goes through the sync tracker so a refusal is visible',
        () async {
      final refusing = _RefusingRepository();
      addTearDown(refusing.dispose);
      final other = await _rig(repo: refusing);
      other.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      await other.settle();

      expect(other.sync.hasFailure, isTrue);
      expect(other.plan.hasPlan, isTrue,
          reason: 'the screen keeps the plan the athlete just made');
    });

    test('a stream error keeps the plan on screen', () async {
      final flaky = _FlakyPlanRepository();
      addTearDown(flaky.dispose);
      final other = await _rig(repo: flaky);
      other.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      flaky.planErrors.addError(StateError('offline'));
      await other.settle();
      expect(other.plan.hasPlan, isTrue);
    });
  });

  group('what counts as having trained', () {
    late _Rig rig;

    setUp(() async {
      rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
    });

    TrainingLogEntry entry(TrainingSource source, {int? seconds}) =>
        TrainingLogEntry(
          id: 'e-${source.name}-$seconds',
          completedAt: DateTime(2026, 10, 19, 18),
          source: source,
          title: 'x',
          durationSeconds: seconds,
        );

    test('a Reaction drill never stands in for a session', () {
      rig.state.addTrainingLogEntry(entry(TrainingSource.reaction));
      expect(rig.plan.todaySession, isNotNull);
    });

    test('a timer session under twenty minutes does not either', () {
      rig.state.addTrainingLogEntry(
          entry(TrainingSource.timer, seconds: 19 * 60 + 59));
      expect(rig.plan.todaySession, isNotNull);
    });

    test('a timer session of twenty minutes or more fills the slot that day',
        () {
      rig.state.addTrainingLogEntry(entry(TrainingSource.timer,
          seconds: PlanController.minStandInSeconds));
      expect(rig.plan.todaySession, isNull);
      expect(rig.plan.todayRow!.status, SessionStatus.completed);
    });

    test('one entry completes at most one session', () {
      rig.state.addTrainingLogEntry(entry(TrainingSource.manual));
      expect(
          rig.plan.rows
              .where((r) => r.status == SessionStatus.completed)
              .length,
          1);
    });
  });

  group('rest days never punish', () {
    test('a week of doing nothing leaves only the planned days as missed',
        () async {
      // Sunday evening of a week with sessions on Mon, Wed and Fri.
      final rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
      rig.now = DateTime(2026, 10, 25, 20);

      final rows = rig.plan.weekDays(start: DateTime(2026, 10, 19));
      final missed = [
        for (final day in rows)
          for (final r in day.rows)
            if (r.status == SessionStatus.missed) r.date.weekday,
      ];
      expect(missed, [1, 3, 5]);
      for (final day in rows.where((d) => d.isRest)) {
        expect(day.emptyStatus, SessionStatus.rest);
      }
    });

    test('a recovery session nobody did is never a miss', () async {
      final rig = await _rig(repo: repo);
      rig.plan.startFresh(
          weeklyTrainingDays: 6, goal: 'Gain muscle', level: 'Beginner');
      rig.now = DateTime(2026, 10, 25, 20);

      final recovery = rig.plan.rows
          .where((r) => r.session.kind == SessionKind.recovery)
          .toList();
      for (final r in recovery) {
        expect(r.status, isNot(SessionStatus.missed));
      }
      expect(
        rig.plan.thisWeek.missed,
        rig.plan.rows
            .where((r) =>
                r.session.kind != SessionKind.recovery &&
                r.status == SessionStatus.missed &&
                r.date.isAfter(DateTime.utc(2026, 10, 18)) &&
                r.date.isBefore(DateTime.utc(2026, 10, 26)))
            .length,
      );
    });

    test('nothing before the plan began is ever planned or missed', () async {
      final rig = await _rig(repo: repo, at: DateTime(2026, 10, 22, 9));
      rig.plan.startFresh(
          weeklyTrainingDays: 6, goal: 'Gain muscle', level: 'Beginner');
      rig.now = DateTime(2026, 11, 2, 9);

      for (final row in rig.plan.rows) {
        expect(row.date.isBefore(DateTime.utc(2026, 10, 22)), isFalse,
            reason: '${row.session.id} is before the plan start');
      }
    });

    test('the dated week stays cheap to read after years of use', () async {
      final rig = await _rig(repo: repo, at: DateTime(2024, 1, 1, 9));
      rig.plan.startFresh(
          weeklyTrainingDays: 4, goal: 'Gain muscle', level: 'Beginner');
      rig.now = DateTime(2026, 10, 22, 9);

      // Only a year of weeks is generated, plus next week.
      final first = rig.plan.rows.first.date;
      expect(
          daysBetween(first, rig.now) <= 7 * (PlanController.historyWeeks + 1),
          isTrue);
      expect(rig.plan.todaySession, isNotNull);
    });
  });

  test('without a repository the plan lives in memory', () {
    final state = AppState(clock: () => _monday);
    final plan = PlanController(log: state);
    addTearDown(plan.dispose);
    addTearDown(state.dispose);

    expect(plan.loaded, isTrue);
    expect(plan.hasPlan, isFalse);
    plan.startFresh(
        weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
    expect(plan.hasPlan, isTrue);
    expect(plan.todaySession, isNotNull);
  });

  test('listeners hear about every change and none after dispose', () async {
    final state = AppState(clock: () => _monday);
    final plan = PlanController(log: state);
    addTearDown(state.dispose);
    var heard = 0;
    plan.addListener(() => heard++);

    plan.startFresh(
        weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
    expect(heard, 1);
    plan.complete(plan.todaySession!.session, title: 't');
    expect(heard, greaterThan(1), reason: 'the log changed under the plan');

    plan.dispose();
    state.addTrainingLogEntry(TrainingLogEntry(
      id: 'late',
      completedAt: _monday,
      source: TrainingSource.manual,
      title: 'late',
    ));
  });
}

/// A repository whose plan stream is driven by the test.
class _FlakyPlanRepository extends InMemoryDataRepository {
  final planErrors = StreamController<StoredTrainingPlan?>.broadcast();

  @override
  Stream<StoredTrainingPlan?> watchTrainingPlan(String userId) =>
      planErrors.stream;

  @override
  void dispose() {
    planErrors.close();
    super.dispose();
  }
}
