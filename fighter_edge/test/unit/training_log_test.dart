import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Monday 2026-09-14 starts week 1; Monday 2026-09-21 starts week 2.
final _week1Tue = DateTime(2026, 9, 15, 18);
final _week2Mon = DateTime(2026, 9, 21, 9);

const _wrestling = LegacySessionSlot(
  id: 'Tue-Wrestling',
  day: 'Tue',
  title: 'Wrestling',
  subtitle: 'Entries, finishes + control',
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

    LegacySessionSlot doneSlot({int rpe = 7, String note = ''}) =>
        LegacySessionSlot(
          id: _wrestling.id,
          day: _wrestling.day,
          title: _wrestling.title,
          subtitle: _wrestling.subtitle,
          completed: true,
          completedAt: _week1Tue,
          rpe: rpe,
          note: note,
        );

    setUp(() async {
      repo = InMemoryDataRepository();
      addTearDown(repo.dispose);
      await repo.saveLegacySession('fighter', _wrestling);
      now = _week1Tue;
    });

    test('every week stays in the log and each day counts once', () async {
      await start();
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'a',
        completedAt: _week1Tue,
        source: TrainingSource.planned,
        title: 'Week 1',
        rpe: 8,
      ));
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'b',
        completedAt: _week2Mon,
        source: TrainingSource.planned,
        title: 'Week 2',
        rpe: 6,
      ));

      expect(state.trainingLog, hasLength(2));
      expect(state.trainingLog.last.title, 'Week 1',
          reason: 'logging week 2 did not overwrite week 1');
      expect(state.trainingDayKeys, {'2026-09-15', '2026-09-21'});

      // Stored, not just in memory.
      await _settle();
      expect(await repo.watchTrainingLog('fighter').first, hasLength(2));
    });

    test('removing an entry deletes it from the stored log too', () async {
      await start();
      state.addTrainingLogEntry(TrainingLogEntry(
        id: 'a',
        completedAt: _week1Tue,
        source: TrainingSource.planned,
        title: 'Week 1',
      ));
      await _settle();
      state.removeTrainingLogEntry('a');
      await _settle();
      expect(state.trainingLog, isEmpty);
      expect(await repo.watchTrainingLog('fighter').first, isEmpty);
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
      expect(state.trainingLog.single.title, 'Reaction · MMA');
      expect(state.trainingDayKeys, isEmpty);
      expect(state.completedSessionCount, 0);
    });

    test('an old completion on the plan moves into the log exactly once',
        () async {
      await repo.saveLegacySession(
          'fighter', doneSlot(rpe: 7, note: 'Legacy'));
      now = _week2Mon;
      await start();
      await _settle();

      final entry = state.trainingLog.single;
      expect(entry.id, 'plan-Tue-Wrestling-2026-09-15');
      expect(entry.rpe, 7);
      expect(entry.note, 'Legacy');

      // The slot's own completion is cleared once the entry is saved.
      final stored = (await repo.watchLegacySessions('fighter').first).single;
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
      await repo.saveLegacySession('fighter', doneSlot());
      await start();
      await _settle();
      final log = await repo.watchTrainingLog('fighter').first;
      expect(log, hasLength(1));
      expect(log.single.note, 'Edited later',
          reason: 'the saved entry wins over the old slot values');
    });
  });
}
