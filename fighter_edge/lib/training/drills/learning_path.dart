import 'drill.dart';
import 'drill_catalog.dart';

/// Ordered prerequisites: practise each step before moving to the next.
/// The guided recommendation stays on that step until it is self-rated sharp.
class LearningPath {
  final DrillDiscipline discipline;
  final List<String> drillIds;
  const LearningPath(this.discipline, this.drillIds);

  static const all = [
    LearningPath(DrillDiscipline.striking, [
      'jab',
      'one_two',
      'lead_hook',
      'slip_counter',
      'pivot_angle',
      'teep',
      'round_kick',
      'low_kick_check',
    ]),
    LearningPath(DrillDiscipline.wrestling, [
      'stance_level_change',
      'double_leg',
      'sprawl',
    ]),
    LearningPath(DrillDiscipline.bjj, [
      'shrimp',
      'technical_standup',
      'mount_escape',
      'closed_guard_posture',
    ]),
    LearningPath(DrillDiscipline.clinch, ['plum_knees', 'pummeling']),
  ];

  static LearningPath forDiscipline(DrillDiscipline discipline) =>
      all.firstWhere((path) => path.discipline == discipline);
}

class PathRecommendation {
  final Drill drill;
  final bool locked;
  const PathRecommendation(this.drill, {required this.locked});
}

/// Never skips an unfinished prerequisite, even with out-of-order study logs.
/// A free account pauses at its first Pro step, including after a downgrade.
/// This is display guidance; the existing entitlement gate controls access.
PathRecommendation? nextDrill(
  LearningPath path,
  Map<String, DrillProgress> progress, {
  required bool isPro,
}) {
  for (final id in path.drillIds) {
    final drill = DrillCatalog.byId(id);
    if (drill == null) throw StateError('Unknown path drill: $id');
    if (!isPro && !drill.starter) {
      return PathRecommendation(drill, locked: true);
    }
    if (progress[id] != DrillProgress.sharp) {
      return PathRecommendation(drill, locked: false);
    }
  }
  return null;
}

enum LearningStage { foundations, building, sharp }

class LearningPathProgress {
  final int completed;
  final int total;
  const LearningPathProgress(this.completed, this.total);

  double get fraction => total == 0 ? 0 : completed / total;
  LearningStage get stage => total > 0 && completed == total
      ? LearningStage.sharp
      : completed == 0
          ? LearningStage.foundations
          : LearningStage.building;
}

/// Completion means sharp, not merely opened, studied or practised once.
LearningPathProgress pathProgress(
        LearningPath path, Map<String, DrillProgress> progress) =>
    LearningPathProgress(
      path.drillIds.where((id) => progress[id] == DrillProgress.sharp).length,
      path.drillIds.length,
    );
