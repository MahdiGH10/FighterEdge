import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Monday 2026-09-14 starts week 1; Monday 2026-09-21 starts week 2.
final _week1Tue = DateTime(2026, 9, 15, 18);
final _week2Mon = DateTime(2026, 9, 21, 9);

const _wrestling = TrainingSession(
  day: 'Tue',
  title: 'Wrestling',
  subtitle: 'Entries, finishes + control',
  icon: Icons.sports_kabaddi,
  completed: false,
);

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  group('TrainingLogEntry', () {
    final entry = TrainingLogEntry(
      id: TrainingLogEntry.plannedId('Tue-Wrestling', _week1Tue),
      completedAt: _week1Tue,
      source: TrainingSource.planned,
      title: 'Wrestling',
      planSlotId: 'Tue-Wrestling',
      durationSeconds: 3600,
      rpe: 8,
      note: 'Good rounds',
      detail: const {'rounds': 6},
    );

    test('round-trips through JSON', () {
      final back = TrainingLogEntry.fromJson(entry.toJson())!;
      expect(back.id, entry.id);
      expect(back.completedAt, entry.completedAt);
      expect(back.source, TrainingSource.planned);
      expect(back.planSlotId, 'Tue-Wrestling');
      expect(back.durationSeconds, 3600);
      expect(back.rpe, 8);
      expect(back.note, 'Good rounds');
      expect(back.detail, {'rounds': 6});
      expect(back.dateKey, '2026-09-15');
    });

    test('a planned entry id is one per slot per day', () {
      expect(TrainingLogEntry.plannedId('Tue-Wrestling', _week1Tue),
          'plan-Tue-Wrestling-2026-09-15');
      expect(
        TrainingLogEntry.plannedId('Tue-Wrestling', DateTime(2026, 9, 15, 6)),
        TrainingLogEntry.plannedId('Tue-Wrestling', _week1Tue),
      );
    });

    test('reads what it can from an imperfect document', () {
      final legacy = TrainingLogEntry.fromJson({
        'completedAt': '2026-09-15T18:00:00.000',
        'source': 'something-new',
        'title': 'Rolls',
      }, id: 'doc-1')!;
      expect(legacy.id, 'doc-1');
      expect(legacy.completedAt, _week1Tue);
      expect(legacy.source, TrainingSource.manual);
      expect(TrainingLogEntry.fromJson({'title': 'no time'}), isNull);
    });

    test('a Reaction drill is logged but is not a training day', () {
      expect(TrainingSource.reaction.countsAsTrainingDay, isFalse);
      for (final source in [
        TrainingSource.planned,
        TrainingSource.timer,
        TrainingSource.manual,
      ]) {
        expect(source.countsAsTrainingDay, isTrue);
      }
    });
  });

  group('InMemoryDataRepository training log', () {
    test('saves, replaces, lists newest first and deletes, per user', () async {
      final repo = InMemoryDataRepository();
      addTearDown(repo.dispose);
      TrainingLogEntry at(String id, DateTime t) => TrainingLogEntry(
          id: id, completedAt: t, source: TrainingSource.manual, title: id);

      await repo.saveTrainingLogEntry('a', at('old', _week1Tue));
      await repo.saveTrainingLogEntry('a', at('new', _week2Mon));
      await repo.saveTrainingLogEntry('a', at('new', _week2Mon)); // replace
      await repo.saveTrainingLogEntry('b', at('other', _week2Mon));

      var log = await repo.watchTrainingLog('a').first;
      expect([for (final e in log) e.id], ['new', 'old']);

      await repo.deleteTrainingLogEntry('a', 'old');
      log = await repo.watchTrainingLog('a').first;
      expect([for (final e in log) e.id], ['new']);
      expect((await repo.watchTrainingLog('b').first).single.id, 'other');
    });
  });

  group('AppState on the training log', () {
    late InMemoryDataRepository repo;
    late DateTime now;
    late AppState state;

    Future<void> start() async {
      state = AppState(dataRepository: repo, clock: () => now)
        ..setUser('fighter');
      addTearDown(state.dispose);
      await _settle();
    }

    setUp(() async {
      repo = InMemoryDataRepository();
      addTearDown(repo.dispose);
      await repo.saveSession('fighter', _wrestling);
      now = _week1Tue;
    });

    test('the plan starts fresh every week and last week stays in history',
        () async {
      await start();
      state.completeSession(state.sessions.single, rpe: 8, note: 'Week 1');
      expect(state.sessions.single.completed, isTrue);

      now = _week2Mon; // a new week
      expect(state.sessions.single.completed, isFalse,
          reason: 'week 1 check marks do not carry into week 2');
      expect(state.completedSessionsDesc, hasLength(1),
          reason: 'but week 1 is still in history');

      state.completeSession(state.sessions.single, rpe: 6, note: 'Week 2');
      expect(state.sessions.single.completed, isTrue);
      expect(state.trainingLog, hasLength(2));
      expect(state.trainingLog.last.note, 'Week 1',
          reason: 'logging week 2 did not overwrite week 1');
      expect(state.trainingDayKeys, {'2026-09-15', '2026-09-21'});

      // Stored, not just in memory.
      await _settle();
      expect(await repo.watchTrainingLog('fighter').first, hasLength(2));
    });

    test('unticking removes only this week\'s entry', () async {
      await start();
      state.completeSession(state.sessions.single);
      now = _week2Mon;
      state.completeSession(state.sessions.single);
      state.toggleSession(state.sessions.single); // untick week 2
      expect(state.sessions.single.completed, isFalse);
      expect(state.trainingLog.single.dateKey, '2026-09-15');
    });

    test('logging twice in a week updates the entry, not a duplicate',
        () async {
      await start();
      state.completeSession(state.sessions.single, rpe: 6);
      now = now.add(const Duration(days: 1));
      state.completeSession(state.sessions.single, rpe: 9, note: 'Edited');
      expect(state.trainingLog, hasLength(1));
      expect(state.sessions.single.rpe, 9);
      expect(state.sessions.single.note, 'Edited');
      expect(state.trainingLog.single.completedAt, _week1Tue,
          reason: 'editing keeps when the session happened');
    });

    test('a Reaction drill shows in history but not in the streak days',
        () async {
      await start();
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'reaction-1',
        completedAt: now,
        source: TrainingSource.reaction,
        title: 'Reaction · MMA',
      ));
      expect(state.completedSessionsDesc.single.title, 'Reaction · MMA');
      expect(state.trainingDayKeys, isEmpty);
      expect(state.completedSessionCount, 0);
    });

    test('an old completion on the plan moves into the log exactly once',
        () async {
      await repo.saveSession(
        'fighter',
        _wrestling.copyWith(
            completed: true, completedAt: _week1Tue, rpe: 7, note: 'Legacy'),
      );
      now = _week2Mon;
      await start();
      await _settle();

      final entry = state.trainingLog.single;
      expect(entry.id, 'plan-Tue-Wrestling-2026-09-15');
      expect(entry.rpe, 7);
      expect(entry.note, 'Legacy');
      expect(state.sessions.single.completed, isFalse,
          reason: 'it was last week, so this week is still open');

      // The slot's own completion is cleared once the entry is saved.
      final stored = (await repo.watchSessions('fighter').first).single;
      expect(stored.completed, isFalse);
      expect(stored.completedAt, isNull);

      // A second launch finds nothing left to move and no duplicates.
      final again = AppState(dataRepository: repo, clock: () => now)
        ..setUser('fighter');
      addTearDown(again.dispose);
      await _settle();
      await _settle();
      expect(await repo.watchTrainingLog('fighter').first, hasLength(1));
    });

    test('re-running the migration over an existing entry never duplicates',
        () async {
      // Entry already saved, but the slot's completion was never cleared
      // (e.g. the app closed between the two writes).
      await repo.saveTrainingLogEntry(
        'fighter',
        TrainingLogEntry(
          id: 'plan-Tue-Wrestling-2026-09-15',
          completedAt: _week1Tue,
          source: TrainingSource.planned,
          title: 'Wrestling',
          planSlotId: 'Tue-Wrestling',
          rpe: 9,
          note: 'Edited later',
        ),
      );
      await repo.saveSession('fighter',
          _wrestling.copyWith(completed: true, completedAt: _week1Tue, rpe: 7));
      await start();
      await _settle();
      final log = await repo.watchTrainingLog('fighter').first;
      expect(log, hasLength(1));
      expect(log.single.note, 'Edited later',
          reason: 'the saved entry wins over the old slot values');
    });
  });

  group('offline demo', () {
    for (final (label, now) in [
      ('on a Monday morning', DateTime(2026, 9, 21, 8)),
      ('on a Sunday night', DateTime(2026, 9, 27, 22)),
    ]) {
      test('shows the same four sessions done $label', () {
        final state = AppState(clock: () => now);
        addTearDown(state.dispose);
        expect(state.sessions.where((s) => s.completed), hasLength(4));
        expect(
          state.trainingLog.every((e) => !e.completedAt.isAfter(now)),
          isTrue,
          reason: 'nothing is dated in the future',
        );
      });
    }
  });
}
