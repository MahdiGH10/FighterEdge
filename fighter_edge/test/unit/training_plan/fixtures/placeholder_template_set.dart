import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_template.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_phase.dart';

/// TEST-ONLY PLACEHOLDER. Not training advice and never shipped: it exists so
/// the tests can exercise selection, rotation, fallback and block scaling.
/// The structure is invented; the real set comes from the owner or a coach.
const int placeholderTemplateSetVersion = 7;

const _lowerLevels = {ExperienceLevel.beginner, ExperienceLevel.intermediate};
const _upperLevels = {
  ExperienceLevel.intermediate,
  ExperienceLevel.advanced,
  ExperienceLevel.competitor,
};
const _allLevels = {
  ExperienceLevel.beginner,
  ExperienceLevel.intermediate,
  ExperienceLevel.advanced,
  ExperienceLevel.competitor,
};
const _allPhases = {
  TrainingPhase.general,
  TrainingPhase.build,
  TrainingPhase.peak,
  TrainingPhase.taper,
  TrainingPhase.weighIn,
  TrainingPhase.refuel,
  TrainingPhase.fightDay,
  TrainingPhase.postFight,
};
const _hardPhases = {
  TrainingPhase.general,
  TrainingPhase.build,
  TrainingPhase.peak,
};

const _roundBlocks = [
  BlockTemplate(
    kind: BlockKind.warmUp,
    minutes: 10,
    cueKeys: ['cueTestWarmUp'],
  ),
  BlockTemplate(
    kind: BlockKind.drillRounds,
    rounds: 6,
    workSec: 180,
    restSec: 60,
    drillIds: ['drillTestOne'],
    cueKeys: ['cueTestWork'],
  ),
  BlockTemplate(kind: BlockKind.coolDown, minutes: 6),
];

SessionTemplate _template(
  String id,
  SessionKind kind,
  Intensity intensity, {
  Discipline? discipline,
  Set<ExperienceLevel> levels = _allLevels,
  Set<TrainingPhase> phases = _allPhases,
  int minutes = 45,
  List<BlockTemplate> blocks = _roundBlocks,
}) =>
    SessionTemplate(
      id: id,
      version: 1,
      kind: kind,
      discipline: discipline,
      levels: levels,
      intensity: intensity,
      phases: phases,
      titleKey: 'tplTest${id.replaceAll(RegExp(r'[^A-Za-z0-9]'), '')}',
      estimatedMinutes: minutes,
      blocks: blocks,
    );

List<SessionTemplate> _build() {
  final templates = <SessionTemplate>[];
  for (final discipline in [
    Discipline.boxing,
    Discipline.wrestling,
    Discipline.mma,
  ]) {
    for (final variant in ['a', 'b', 'c']) {
      templates
        ..add(_template(
          'test.${discipline.name}.skill.beginner.$variant',
          SessionKind.skill,
          Intensity.moderate,
          discipline: discipline,
          levels: _lowerLevels,
        ))
        ..add(_template(
          'test.${discipline.name}.skill.upper.$variant',
          SessionKind.skill,
          Intensity.moderate,
          discipline: discipline,
          levels: _upperLevels,
          minutes: 60,
        ));
    }
  }
  // Light skill session for the lighter phases.
  templates.add(_template(
    'test.boxing.skill.light.a',
    SessionKind.skill,
    Intensity.light,
    discipline: Discipline.boxing,
    phases: {TrainingPhase.taper, TrainingPhase.weighIn},
  ));
  for (final discipline in [Discipline.boxing, Discipline.wrestling]) {
    templates.add(_template(
      'test.${discipline.name}.sparring.upper.a',
      SessionKind.sparring,
      Intensity.hard,
      discipline: discipline,
      levels: _upperLevels,
      phases: _hardPhases,
      minutes: 60,
    ));
  }
  for (final variant in ['a', 'b']) {
    templates
      ..add(_template('test.conditioning.moderate.$variant',
          SessionKind.conditioning, Intensity.moderate))
      ..add(_template('test.conditioning.hard.$variant',
          SessionKind.conditioning, Intensity.hard,
          phases: _hardPhases))
      ..add(_template('test.strength.moderate.$variant', SessionKind.strength,
          Intensity.moderate))
      ..add(_template(
          'test.strength.hard.$variant', SessionKind.strength, Intensity.hard,
          phases: _hardPhases));
  }
  templates
    ..add(_template('test.recovery.a', SessionKind.recovery, Intensity.light,
        minutes: 30,
        blocks: const [BlockTemplate(kind: BlockKind.main, minutes: 30)]))
    ..add(_template('test.gymClass.a', SessionKind.gymClass, Intensity.moderate,
        minutes: 60, blocks: const []));
  return templates;
}

final TemplateSet placeholderTemplateSet = TemplateSet(
  version: placeholderTemplateSetVersion,
  templates: _build(),
);
