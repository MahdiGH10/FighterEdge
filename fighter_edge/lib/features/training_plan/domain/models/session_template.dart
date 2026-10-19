import 'discipline.dart';
import 'experience_level.dart';
import 'intensity.dart';
import 'session_kind.dart';
import 'training_phase.dart';

/// The kind of a block inside a session.
enum BlockKind { warmUp, drillRounds, conditioning, strength, main, coolDown }

/// One block of a session template: either a timed block ([minutes]) or
/// timed rounds ([rounds] x [workSec] with [restSec] between).
///
/// Curated data. The domain never writes any of it.
class BlockTemplate {
  const BlockTemplate({
    required this.kind,
    this.minutes,
    this.rounds,
    this.workSec,
    this.restSec,
    this.drillIds = const [],
    this.cueKeys = const [],
  });

  final BlockKind kind;
  final int? minutes;
  final int? rounds;
  final int? workSec;
  final int? restSec;

  /// Ids from the drill catalog. Empty for the launch placeholder set.
  final List<String> drillIds;

  /// l10n keys of the cues to show, never literal text.
  final List<String> cueKeys;

  /// Whether this block is rounds rather than a single timed block.
  bool get isRounds => rounds != null;

  /// Planned length in minutes, from [minutes] or the rounds.
  double get totalMinutes => isRounds
      ? rounds! * ((workSec ?? 0) + (restSec ?? 0)) / 60
      : (minutes ?? 0).toDouble();
}

/// A curated session: selection keys, display keys and blocks.
class SessionTemplate {
  const SessionTemplate({
    required this.id,
    required this.version,
    required this.kind,
    this.discipline,
    required this.levels,
    required this.intensity,
    required this.phases,
    required this.titleKey,
    required this.estimatedMinutes,
    this.energyMet,
    this.blocks = const [],
  });

  /// Stable reference from `PlannedSession`.
  final String id;
  final int version;
  final SessionKind kind;

  /// Null means the template fits any discipline.
  final Discipline? discipline;
  final Set<ExperienceLevel> levels;
  final Intensity intensity;
  final Set<TrainingPhase> phases;

  /// l10n key of the title, never literal text.
  final String titleKey;
  final int estimatedMinutes;

  /// Metabolic equivalent for Fuel's session energy. Owner/dietitian decision
  /// (proposal decision 12); null until reviewed.
  final double? energyMet;

  /// Empty for gym-class templates.
  final List<BlockTemplate> blocks;

  double get totalBlockMinutes =>
      blocks.fold(0.0, (sum, block) => sum + block.totalMinutes);
}

/// A versioned collection of [SessionTemplate]s. Bundled content lives in the
/// data layer; the domain only reads it.
class TemplateSet {
  const TemplateSet({required this.version, required this.templates});

  final int version;
  final List<SessionTemplate> templates;
}
