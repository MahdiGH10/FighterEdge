import 'package:fighter_edge/features/training_plan/domain/models/discipline.dart';
import 'package:fighter_edge/features/training_plan/domain/models/experience_level.dart';
import 'package:fighter_edge/features/training_plan/domain/models/intensity.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_kind.dart';
import 'package:fighter_edge/features/training_plan/domain/models/session_template.dart';
import 'package:fighter_edge/features/training_plan/domain/models/training_phase.dart';
import 'package:fighter_edge/features/training_plan/domain/templates/generic_template_set.dart';
import 'package:fighter_edge/features/training_plan/domain/validation/template_validation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/placeholder_template_set.dart';

const _goodBlocks = [
  BlockTemplate(kind: BlockKind.warmUp, minutes: 10, cueKeys: ['cueOne']),
  BlockTemplate(
    kind: BlockKind.drillRounds,
    rounds: 4,
    workSec: 180,
    restSec: 60,
    drillIds: ['drillOne'],
  ),
  BlockTemplate(kind: BlockKind.coolDown, minutes: 5),
];

SessionTemplate _template({
  String id = 'test.one',
  int version = 1,
  SessionKind kind = SessionKind.skill,
  Discipline? discipline = Discipline.boxing,
  Set<ExperienceLevel> levels = const {ExperienceLevel.intermediate},
  Intensity intensity = Intensity.moderate,
  Set<TrainingPhase> phases = const {TrainingPhase.general},
  String titleKey = 'tplTestOne',
  int minutes = 60,
  double? energyMet,
  List<BlockTemplate> blocks = _goodBlocks,
}) =>
    SessionTemplate(
      id: id,
      version: version,
      kind: kind,
      discipline: discipline,
      levels: levels,
      intensity: intensity,
      phases: phases,
      titleKey: titleKey,
      estimatedMinutes: minutes,
      energyMet: energyMet,
      blocks: blocks,
    );

/// One template of every kind the generator needs, so only the template under
/// test can add issues.
List<SessionTemplate> _complete(SessionTemplate under) => [
      under,
      for (final kind in SessionKind.values)
        if (kind != SessionKind.sparring && kind != under.kind)
          _template(
            id: 'filler.${kind.name}',
            kind: kind,
            discipline: null,
            intensity: kind == SessionKind.recovery
                ? Intensity.light
                : Intensity.moderate,
            minutes: 30,
            blocks: kind == SessionKind.gymClass
                ? const []
                : const [BlockTemplate(kind: BlockKind.main, minutes: 30)],
          ),
    ];

List<TemplateIssue> _validate(SessionTemplate t, {int version = 1}) =>
    TemplateSetValidator.validate(
      TemplateSet(version: version, templates: _complete(t)),
    );

void expectIssue(List<TemplateIssue> issues, Pattern message) {
  expect(
    issues.map((i) => i.toString()),
    contains(matches(message)),
    reason: issues.join('\n'),
  );
}

void main() {
  group('accepts', () {
    test('a well-formed template', () {
      expect(_validate(_template()), isEmpty);
    });

    test('the bundled generic launch set', () {
      expect(
          TemplateSetValidator.validate(GenericTemplateSet.instance), isEmpty);
    });

    test('the test placeholder set', () {
      expect(TemplateSetValidator.validate(placeholderTemplateSet), isEmpty);
    });

    test('a gym class with no blocks, and an energy value in range', () {
      expect(
        _validate(_template(
          id: 'gym',
          kind: SessionKind.gymClass,
          discipline: null,
          blocks: const [],
          energyMet: 6.5,
        )),
        isEmpty,
      );
    });
  });

  group('rejects', () {
    test('an empty set', () {
      final issues = TemplateSetValidator.validate(
        const TemplateSet(version: 1, templates: []),
      );
      expectIssue(issues, 'no templates');
    });

    test('a set version below 1', () {
      expectIssue(_validate(_template(), version: 0), 'version must be 1');
    });

    test('a missing id', () {
      expectIssue(_validate(_template(id: '')), 'missing id');
    });

    test('a duplicate id', () {
      final issues = TemplateSetValidator.validate(TemplateSet(
        version: 1,
        templates: [..._complete(_template()), _template()],
      ));
      expectIssue(issues, 'duplicate id');
    });

    test('a template version below 1', () {
      expectIssue(_validate(_template(version: 0)), 'version must be 1');
    });

    test('a title that is not an l10n key', () {
      for (final bad in ['', 'Boxing Basics', '1abc', 'with-dash']) {
        expectIssue(_validate(_template(titleKey: bad)), 'not an l10n key');
      }
    });

    test('no levels or no phases', () {
      expectIssue(_validate(_template(levels: {})), 'no levels');
      expectIssue(_validate(_template(phases: {})), 'no phases');
    });

    test('a length outside the allowed range', () {
      expectIssue(_validate(_template(minutes: 5)), 'estimatedMinutes');
      expectIssue(_validate(_template(minutes: 500)), 'estimatedMinutes');
    });

    test('an energy value out of range or not a number', () {
      expectIssue(_validate(_template(energyMet: 0.2)), 'energyMet');
      expectIssue(_validate(_template(energyMet: 40)), 'energyMet');
      expectIssue(_validate(_template(energyMet: double.nan)), 'energyMet');
    });

    test('a recovery session that is not light', () {
      expectIssue(
        _validate(_template(
          id: 'rec',
          kind: SessionKind.recovery,
          intensity: Intensity.moderate,
          discipline: null,
        )),
        'recovery must be light',
      );
    });

    test('sparring for beginners, or without a discipline', () {
      expectIssue(
        _validate(_template(
          id: 'spar',
          kind: SessionKind.sparring,
          intensity: Intensity.hard,
          levels: {ExperienceLevel.beginner, ExperienceLevel.advanced},
        )),
        'sparring must not include beginner',
      );
      expectIssue(
        _validate(_template(
          id: 'spar',
          kind: SessionKind.sparring,
          intensity: Intensity.hard,
          discipline: null,
        )),
        'sparring needs a discipline',
      );
    });

    test('a gym class with blocks', () {
      expectIssue(
        _validate(_template(id: 'gym', kind: SessionKind.gymClass)),
        'gym class must have no blocks',
      );
    });

    test('a session with no blocks', () {
      expectIssue(_validate(_template(blocks: const [])), 'no blocks');
    });

    test('bad rounds', () {
      for (final block in const [
        BlockTemplate(
            kind: BlockKind.drillRounds, rounds: 0, workSec: 180, restSec: 60),
        BlockTemplate(
            kind: BlockKind.drillRounds, rounds: 99, workSec: 180, restSec: 60),
        BlockTemplate(
            kind: BlockKind.drillRounds, rounds: 4, workSec: 1, restSec: 60),
        BlockTemplate(
            kind: BlockKind.drillRounds, rounds: 4, workSec: 9000, restSec: 60),
        BlockTemplate(kind: BlockKind.drillRounds, rounds: 4, workSec: 180),
        BlockTemplate(kind: BlockKind.drillRounds, rounds: 4, restSec: 60),
        BlockTemplate(
            kind: BlockKind.drillRounds, rounds: 4, workSec: 180, restSec: -5),
      ]) {
        expectIssue(
          _validate(_template(minutes: 60, blocks: [block])),
          'block 0',
        );
      }
    });

    test('bad timed blocks', () {
      for (final block in const [
        BlockTemplate(kind: BlockKind.warmUp),
        BlockTemplate(kind: BlockKind.warmUp, minutes: 0),
        BlockTemplate(kind: BlockKind.warmUp, minutes: 500),
      ]) {
        expectIssue(
          _validate(_template(minutes: 60, blocks: [block])),
          'block 0',
        );
      }
    });

    test('a bad cue key or an empty drill id', () {
      expectIssue(
        _validate(_template(blocks: const [
          BlockTemplate(
              kind: BlockKind.main, minutes: 60, cueKeys: ['Do a jab']),
        ])),
        'is not a key',
      );
      expectIssue(
        _validate(_template(blocks: const [
          BlockTemplate(kind: BlockKind.main, minutes: 60, drillIds: ['']),
        ])),
        'empty drill id',
      );
    });

    test('blocks that do not add up to the stated length', () {
      expectIssue(
        _validate(_template(
          minutes: 60,
          blocks: const [BlockTemplate(kind: BlockKind.main, minutes: 10)],
        )),
        'blocks total',
      );
      expectIssue(
        _validate(_template(
          minutes: 20,
          blocks: const [BlockTemplate(kind: BlockKind.main, minutes: 60)],
        )),
        'blocks total',
      );
    });

    test('a set missing a kind the generator plans', () {
      final issues = TemplateSetValidator.validate(TemplateSet(
        version: 1,
        templates: [_template()],
      ));
      expectIssue(issues, 'no template of kind strength');
      expectIssue(issues, 'no template of kind recovery');
      expectIssue(issues, 'no template of kind gymClass');
    });

    test('a set without sparring is fine (sparring falls back to skill)', () {
      expect(
        TemplateSetValidator.validate(GenericTemplateSet.instance)
            .where((i) => i.message.contains('sparring')),
        isEmpty,
      );
    });

    test('reports every problem, with the template id', () {
      final issues = _validate(_template(
        id: 'broken',
        titleKey: 'Bad Title',
        minutes: 5,
        levels: {},
      ));
      expect(issues.length, greaterThanOrEqualTo(3));
      expect(issues.every((i) => i.templateId == 'broken'), isTrue);
      expect(issues.first.toString(), startsWith('broken: '));
    });
  });
}
