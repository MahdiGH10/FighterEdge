import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/training/drills/drill.dart';
import 'package:fighter_edge/training/drills/drill_catalog.dart';
import 'package:fighter_edge/training/drills/learning_path.dart';

void main() {
  group('LearningPath', () {
    test('all four paths start with their free starter and cover the catalog',
        () {
      final allIds = <String>[];
      final expectedStart = {
        DrillDiscipline.striking: 'jab',
        DrillDiscipline.wrestling: 'stance_level_change',
        DrillDiscipline.bjj: 'shrimp',
        DrillDiscipline.clinch: 'plum_knees',
      };
      for (final discipline in DrillDiscipline.values) {
        final path = LearningPath.forDiscipline(discipline);
        expect(path.drillIds.first, expectedStart[discipline]);
        expect(DrillCatalog.byId(path.drillIds.first)!.starter, isTrue);
        for (final id in path.drillIds) {
          expect(DrillCatalog.byId(id)!.discipline, discipline);
        }
        allIds.addAll(path.drillIds);
      }
      expect(allIds.toSet(), hasLength(DrillCatalog.all.length));
      expect(allIds.toSet(), DrillCatalog.all.map((drill) => drill.id).toSet());
      expect(
          LearningPath.forDiscipline(DrillDiscipline.striking).drillIds.take(3),
          ['jab', 'one_two', 'lead_hook']);
      expect(
          LearningPath.forDiscipline(DrillDiscipline.wrestling)
              .drillIds
              .take(2),
          ['stance_level_change', 'double_leg']);
    });

    test('empty progress starts at the first drill and foundations', () {
      final path = LearningPath.forDiscipline(DrillDiscipline.striking);
      final next = nextDrill(path, {}, isPro: true)!;
      expect(next.drill.id, 'jab');
      expect(next.locked, isFalse);
      final status = pathProgress(path, {});
      expect(status.completed, 0);
      expect(status.total, path.drillIds.length);
      expect(status.fraction, 0);
      expect(status.stage, LearningStage.foundations);
    });

    test('does not skip a prerequisite that is below drilled', () {
      final path = LearningPath.forDiscipline(DrillDiscipline.striking);
      final progress = {
        'jab': DrillProgress.studied,
        'one_two': DrillProgress.sharp,
        'lead_hook': DrillProgress.sharp,
      };
      expect(nextDrill(path, progress, isPro: true)!.drill.id, 'jab');
      progress['jab'] = DrillProgress.drilled;
      expect(nextDrill(path, progress, isPro: true)!.drill.id, 'jab');
      progress['jab'] = DrillProgress.sharp;
      expect(nextDrill(path, progress, isPro: true)!.drill.id, 'slip_counter');
    });

    test('free stops at its first Pro drill, including a downgraded account',
        () {
      final path = LearningPath.forDiscipline(DrillDiscipline.striking);
      final progress = {
        for (final id in path.drillIds) id: DrillProgress.sharp
      };
      final next = nextDrill(path, progress, isPro: false)!;
      expect(next.drill.id, 'one_two');
      expect(next.locked, isTrue);
      expect(nextDrill(path, progress, isPro: true), isNull);
    });

    test('progress counts sharp only and exposes building and complete stages',
        () {
      final path = LearningPath.forDiscipline(DrillDiscipline.clinch);
      final partial = pathProgress(path, {
        'plum_knees': DrillProgress.sharp,
        'pummeling': DrillProgress.drilled
      });
      expect(partial.completed, 1);
      expect(partial.fraction, 0.5);
      expect(partial.stage, LearningStage.building);
      final complete = pathProgress(path, {
        for (final id in path.drillIds) id: DrillProgress.sharp,
      });
      expect(complete.completed, complete.total);
      expect(complete.fraction, 1);
      expect(complete.stage, LearningStage.sharp);
    });

    test('empty path is safe and an unknown catalog id fails clearly', () {
      const empty = LearningPath(DrillDiscipline.clinch, []);
      expect(nextDrill(empty, {}, isPro: true), isNull);
      expect(pathProgress(empty, {}).fraction, 0);
      expect(pathProgress(empty, {}).stage, LearningStage.foundations);
      const invalid = LearningPath(DrillDiscipline.clinch, ['missing']);
      expect(() => nextDrill(invalid, {}, isPro: true), throwsStateError);
    });
  });
}
