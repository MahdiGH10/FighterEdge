import '../models/experience_level.dart';
import '../models/intensity.dart';
import '../models/session_kind.dart';
import '../models/session_template.dart';
import '../models/training_phase.dart';

/// LAUNCH PLACEHOLDER. OWNER / COACH SIGN-OFF PENDING.
///
/// Neutral, content-free sessions: "Skill session", "Conditioning session",
/// "Strength session", "Recovery session", "Gym class". There is no
/// prescribed drill, exercise or round structure: each session is one timed
/// block, and the title is an l10n key (the later ARB PR supplies the text).
/// Real methodology comes from the owner or a coach (proposal decision 2).
///
/// Lengths per level band are the proposal's session-length defaults
/// (decision 5: 45 / 60 / 75 minutes). The 30-minute recovery session is an
/// app default. No energy (MET) values are set: that is a dietitian decision.
class GenericTemplateSet {
  GenericTemplateSet._();

  static const int version = 1;

  static final TemplateSet instance = TemplateSet(
    version: version,
    templates: _build(),
  );

  static const Set<TrainingPhase> _allPhases = {
    TrainingPhase.general,
    TrainingPhase.build,
    TrainingPhase.peak,
    TrainingPhase.taper,
    TrainingPhase.weighIn,
    TrainingPhase.refuel,
    TrainingPhase.fightDay,
    TrainingPhase.postFight,
  };

  /// Level bands with their default length.
  static const _bands = <(String, Set<ExperienceLevel>, int)>[
    ('beginner', {ExperienceLevel.beginner}, 45),
    ('intermediate', {ExperienceLevel.intermediate}, 60),
    (
      'advanced',
      {ExperienceLevel.advanced, ExperienceLevel.competitor},
      75,
    ),
  ];

  static List<SessionTemplate> _build() {
    final templates = <SessionTemplate>[];
    void banded(SessionKind kind, Intensity intensity) {
      for (final (name, levels, minutes) in _bands) {
        templates.add(
          SessionTemplate(
            id: 'generic.${kind.name}.$name.${intensity.name}',
            version: 1,
            kind: kind,
            levels: levels,
            intensity: intensity,
            phases: _allPhases,
            titleKey: kind.fallbackTitleKey,
            estimatedMinutes: minutes,
            blocks: [BlockTemplate(kind: BlockKind.main, minutes: minutes)],
          ),
        );
      }
    }

    banded(SessionKind.skill, Intensity.moderate);
    banded(SessionKind.conditioning, Intensity.moderate);
    banded(SessionKind.conditioning, Intensity.hard);
    banded(SessionKind.strength, Intensity.moderate);
    banded(SessionKind.strength, Intensity.hard);

    templates
      ..add(
        SessionTemplate(
          id: 'generic.recovery.all.light',
          version: 1,
          kind: SessionKind.recovery,
          levels: ExperienceLevel.values.toSet(),
          intensity: Intensity.light,
          phases: _allPhases,
          titleKey: SessionKind.recovery.fallbackTitleKey,
          estimatedMinutes: 30,
          blocks: const [BlockTemplate(kind: BlockKind.main, minutes: 30)],
        ),
      )
      ..add(
        SessionTemplate(
          id: 'generic.gymClass.all.moderate',
          version: 1,
          kind: SessionKind.gymClass,
          levels: ExperienceLevel.values.toSet(),
          intensity: Intensity.moderate,
          phases: _allPhases,
          titleKey: SessionKind.gymClass.fallbackTitleKey,
          estimatedMinutes: 60,
        ),
      );
    return List.unmodifiable(templates);
  }
}
