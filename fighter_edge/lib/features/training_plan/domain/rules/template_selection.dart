import '../models/discipline.dart';
import '../models/experience_level.dart';
import '../models/intensity.dart';
import '../models/reason_code.dart';
import '../models/session_kind.dart';
import '../models/session_template.dart';
import '../models/training_phase.dart';

/// The result of picking a template for one slot.
class TemplateChoice {
  const TemplateChoice({
    required this.kind,
    this.template,
    this.reasons = const [],
  });

  /// The kind actually planned. Differs from the requested kind only when a
  /// sparring slot fell back to skill.
  final SessionKind kind;

  /// Null when the set has nothing usable.
  final SessionTemplate? template;
  final List<ReasonCode> reasons;
}

/// Picks a template for a slot: discipline x kind x level x intensity, rotated
/// by [rotationIndex] so weeks differ but stay predictable.
///
/// Matching relaxes in steps (intensity down, then phase, then level, then
/// intensity up) and says so with [ReasonCode.templateFallback]. Beginners
/// never get a sparring template, however far matching relaxes.
TemplateChoice selectTemplate({
  required TemplateSet templates,
  required SessionKind kind,
  Discipline? discipline,
  required ExperienceLevel level,
  required TrainingPhase phase,
  required Intensity intensity,
  required int rotationIndex,
}) {
  final direct = _select(
    templates,
    kind,
    discipline,
    level,
    phase,
    intensity,
    rotationIndex,
  );
  if (direct != null) return direct;
  if (kind == SessionKind.sparring) {
    final fallback = _select(
      templates,
      SessionKind.skill,
      discipline,
      level,
      phase,
      intensity.capAt(Intensity.moderate),
      rotationIndex,
    );
    if (fallback != null) {
      return TemplateChoice(
        kind: SessionKind.skill,
        template: fallback.template,
        reasons: [ReasonCode.sparringFallbackToSkill, ...fallback.reasons],
      );
    }
  }
  return TemplateChoice(
    kind: kind,
    reasons: const [ReasonCode.noTemplateAvailable],
  );
}

TemplateChoice? _select(
  TemplateSet templates,
  SessionKind kind,
  Discipline? discipline,
  ExperienceLevel level,
  TrainingPhase phase,
  Intensity intensity,
  int rotationIndex,
) {
  final ofKind = [
    for (final t in templates.templates)
      if (t.kind == kind &&
          (t.discipline == null || t.discipline == discipline) &&
          !(level == ExperienceLevel.beginner &&
              t.kind == SessionKind.sparring))
        t,
  ];

  // Each step is looser than the one before it.
  final steps = <bool Function(SessionTemplate)>[
    (t) =>
        t.intensity == intensity &&
        t.phases.contains(phase) &&
        t.levels.contains(level),
    (t) =>
        t.intensity.index <= intensity.index &&
        t.phases.contains(phase) &&
        t.levels.contains(level),
    (t) => t.intensity.index <= intensity.index && t.levels.contains(level),
    (t) => t.intensity.index <= intensity.index,
    (_) => true,
  ];

  for (var step = 0; step < steps.length; step++) {
    var candidates = ofKind.where(steps[step]).toList();
    if (candidates.isEmpty) continue;
    // A template made for this discipline beats a generic one.
    final exact = [
      for (final t in candidates)
        if (t.discipline != null) t,
    ];
    if (exact.isNotEmpty) candidates = exact;
    candidates.sort((a, b) => a.id.compareTo(b.id));
    final pick = candidates[rotationIndex % candidates.length];
    return TemplateChoice(
      kind: kind,
      template: pick,
      reasons: [
        if (step > 0) ReasonCode.templateFallback,
        if (candidates.length > 1) ReasonCode.templateRotation,
      ],
    );
  }
  return null;
}
