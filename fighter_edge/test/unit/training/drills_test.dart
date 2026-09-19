import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/training/corner_cues.dart';
import 'package:fighter_edge/training/drills/drill.dart';
import 'package:fighter_edge/training/drills/drill_catalog.dart';
import 'package:fighter_edge/training/drills/drill_progress_store.dart';

void main() {
  group('DrillCatalog', () {
    test('ids are unique', () {
      final ids = DrillCatalog.all.map((d) => d.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('every drill is complete: points, mistakes, and a way to drill it',
        () {
      for (final drill in DrillCatalog.all) {
        expect(drill.summary, isNotEmpty, reason: drill.id);
        expect(drill.keyPoints.length, greaterThanOrEqualTo(3),
            reason: drill.id);
        expect(drill.commonMistakes, isNotEmpty, reason: drill.id);
        expect(drill.prescription, isNotEmpty, reason: drill.id);
      }
    });

    test('a free account gets exactly one starter in every discipline', () {
      for (final discipline in DrillDiscipline.values) {
        final starters =
            DrillCatalog.byDiscipline(discipline).where((d) => d.starter);
        expect(starters, hasLength(1), reason: discipline.name);
      }
    });

    test('Pro has more to unlock in every discipline', () {
      for (final discipline in DrillDiscipline.values) {
        expect(
          DrillCatalog.byDiscipline(discipline).where((d) => !d.starter),
          isNotEmpty,
          reason: discipline.name,
        );
      }
    });
  });

  group('DrillProgressStore', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('persists progress and bookmarks per account', () async {
      final store = DrillProgressStore(userId: 'a');
      await store.load();
      await store.setProgress('jab', DrillProgress.drilled);
      await store.toggleBookmark('sprawl');

      final reloaded = DrillProgressStore(userId: 'a');
      await reloaded.load();
      expect(reloaded.progressOf('jab'), DrillProgress.drilled);
      expect(reloaded.isBookmarked('sprawl'), isTrue);

      final otherAccount = DrillProgressStore(userId: 'b');
      await otherAccount.load();
      expect(otherAccount.progressOf('jab'), DrillProgress.none);
      expect(otherAccount.isBookmarked('sprawl'), isFalse);
    });

    test('counts sharp drills and clears back to none', () async {
      final store = DrillProgressStore(userId: 'a');
      await store.load();
      await store.setProgress('jab', DrillProgress.sharp);
      await store.setProgress('teep', DrillProgress.sharp);
      expect(store.sharpCount, 2);

      await store.setProgress('jab', DrillProgress.none);
      expect(store.sharpCount, 1);
      expect(store.progressOf('jab'), DrillProgress.none);
    });

    test('a corrupt entry starts fresh instead of throwing', () async {
      SharedPreferences.setMockInitialValues({'drills.v1.a': 'not json'});
      final store = DrillProgressStore(userId: 'a');
      await store.load();
      expect(store.isLoaded, isTrue);
      expect(store.sharpCount, 0);
    });
  });

  group('CornerCues', () {
    test('stages split a session into early, middle, and final', () {
      RoundStage stage(int r) =>
          CornerCues.stageOf(upcomingRound: r, rounds: 12);
      expect(stage(2), RoundStage.early);
      expect(stage(4), RoundStage.early);
      expect(stage(5), RoundStage.middle);
      expect(stage(11), RoundStage.middle);
      expect(stage(12), RoundStage.finalRound);
    });

    test('the last rest always gets the final-round cue', () {
      for (final style in ['Boxing', 'MMA', 'BJJ']) {
        final cue =
            CornerCues.forRest(style: style, upcomingRound: 5, rounds: 5);
        expect(cue.tactical, startsWith('Last round'), reason: style);
      }
    });

    test('consecutive rests do not repeat the recovery cue', () {
      final first =
          CornerCues.forRest(style: 'MMA', upcomingRound: 2, rounds: 5);
      final second =
          CornerCues.forRest(style: 'MMA', upcomingRound: 3, rounds: 5);
      expect(first.recovery, isNot(second.recovery));
    });

    test('an unknown preset falls back instead of failing', () {
      final cue =
          CornerCues.forRest(style: 'Custom', upcomingRound: 2, rounds: 3);
      expect(cue.tactical, isNotEmpty);
    });
  });
}
