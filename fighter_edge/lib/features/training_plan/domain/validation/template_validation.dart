import '../models/experience_level.dart';
import '../models/intensity.dart';
import '../models/session_kind.dart';
import '../models/session_template.dart';

/// One problem found in a template set.
class TemplateIssue {
  /// Id of the offending template, or `<index N>` when the id is missing, or
  /// `<set>` for a problem with the set itself.
  final String templateId;
  final String message;

  const TemplateIssue(this.templateId, this.message);

  @override
  String toString() => '$templateId: $message';
}

/// Schema and range checks for a [TemplateSet].
///
/// Templates are hand-written content, so they are the likeliest thing to be
/// quietly wrong. Run in unit tests (a bad template fails CI) and at load.
/// These are content-integrity checks, not training science: they cannot tell
/// a wise session from an unwise one.
class TemplateSetValidator {
  TemplateSetValidator._();

  static const int minEstimatedMinutes = 10;
  static const int maxEstimatedMinutes = 180;
  static const double minEnergyMet = 1;
  static const double maxEnergyMet = 20;
  static const int maxRounds = 30;
  static const int maxBlockMinutes = 120;
  static const int maxRoundSeconds = 600;

  /// How far the blocks' total may stray from
  /// [SessionTemplate.estimatedMinutes].
  static const double minBlockShare = 0.5;
  static const double maxBlockShare = 1.25;

  /// A title or cue key: lower camel case, never English text.
  static final RegExp keyPattern = RegExp(r'^[a-z][A-Za-z0-9]*$');

  static List<TemplateIssue> validate(TemplateSet set) {
    final issues = <TemplateIssue>[];
    if (set.version < 1) {
      issues.add(const TemplateIssue('<set>', 'version must be 1 or more'));
    }
    if (set.templates.isEmpty) {
      issues.add(const TemplateIssue('<set>', 'no templates'));
    }

    final seen = <String>{};
    for (var i = 0; i < set.templates.length; i++) {
      final template = set.templates[i];
      final id = template.id.isEmpty ? '<index $i>' : template.id;
      void add(String message) => issues.add(TemplateIssue(id, message));

      if (template.id.isEmpty) {
        add('missing id');
      } else if (!seen.add(template.id)) {
        add('duplicate id');
      }
      if (template.version < 1) add('version must be 1 or more');
      if (!keyPattern.hasMatch(template.titleKey)) {
        add('titleKey "${template.titleKey}" is not an l10n key');
      }
      if (template.levels.isEmpty) add('no levels');
      if (template.phases.isEmpty) add('no phases');
      if (template.estimatedMinutes < minEstimatedMinutes ||
          template.estimatedMinutes > maxEstimatedMinutes) {
        add('estimatedMinutes ${template.estimatedMinutes} outside '
            '$minEstimatedMinutes-$maxEstimatedMinutes');
      }
      final met = template.energyMet;
      if (met != null && (!(met >= minEnergyMet) || met > maxEnergyMet)) {
        add('energyMet $met outside $minEnergyMet-$maxEnergyMet');
      }
      if (template.kind == SessionKind.recovery &&
          template.intensity != Intensity.light) {
        add('recovery must be light');
      }
      if (template.kind == SessionKind.sparring) {
        if (template.levels.contains(ExperienceLevel.beginner)) {
          add('sparring must not include beginner');
        }
        if (template.discipline == null) add('sparring needs a discipline');
      }

      _checkBlocks(template, add);
    }

    // The generator needs something for every kind it plans.
    for (final kind in SessionKind.values) {
      if (kind == SessionKind.sparring) continue; // falls back to skill
      if (!set.templates.any((t) => t.kind == kind)) {
        issues.add(TemplateIssue('<set>', 'no template of kind ${kind.name}'));
      }
    }
    return issues;
  }

  static void _checkBlocks(
    SessionTemplate template,
    void Function(String) add,
  ) {
    if (template.kind == SessionKind.gymClass) {
      if (template.blocks.isNotEmpty) add('gym class must have no blocks');
      return;
    }
    if (template.blocks.isEmpty) {
      add('no blocks');
      return;
    }
    for (var b = 0; b < template.blocks.length; b++) {
      final block = template.blocks[b];
      final where = 'block $b (${block.kind.name})';
      if (block.isRounds) {
        final rounds = block.rounds!;
        final work = block.workSec;
        final rest = block.restSec;
        if (rounds < 1 || rounds > maxRounds) {
          add('$where rounds $rounds outside 1-$maxRounds');
        }
        if (work == null || work < 5 || work > maxRoundSeconds) {
          add('$where workSec outside 5-$maxRoundSeconds');
        }
        if (rest == null || rest < 0 || rest > maxRoundSeconds) {
          add('$where restSec outside 0-$maxRoundSeconds');
        }
      } else {
        final minutes = block.minutes;
        if (minutes == null || minutes < 1 || minutes > maxBlockMinutes) {
          add('$where minutes outside 1-$maxBlockMinutes');
        }
      }
      for (final key in block.cueKeys) {
        if (!keyPattern.hasMatch(key)) add('$where cue "$key" is not a key');
      }
      if (block.drillIds.any((id) => id.isEmpty)) {
        add('$where has an empty drill id');
      }
    }
    final total = template.totalBlockMinutes;
    final estimate = template.estimatedMinutes;
    if (total < estimate * minBlockShare || total > estimate * maxBlockShare) {
      add('blocks total ${total.toStringAsFixed(0)} min but '
          'estimatedMinutes is $estimate');
    }
  }
}
