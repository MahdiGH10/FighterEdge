import 'discipline.dart';
import 'intensity.dart';
import 'planned_block.dart';
import 'reason_code.dart';
import 'session_kind.dart';

/// One dated session of the plan. At most one per day (proposal decision 11).
class PlannedSession {
  const PlannedSession({
    required this.id,
    required this.date,
    this.templateId,
    this.templateVersion,
    required this.kind,
    this.discipline,
    required this.intensity,
    required this.titleKey,
    this.blocks = const [],
    required this.estimatedMinutes,
    this.reasons = const [],
  });

  /// Stable and deterministic: the date plus the kind, so the same plan
  /// always yields the same ids.
  final String id;
  final DateTime date;

  /// Null when the template set had nothing for this slot
  /// ([ReasonCode.noTemplateAvailable]).
  final String? templateId;
  final int? templateVersion;
  final SessionKind kind;
  final Discipline? discipline;
  final Intensity intensity;

  /// l10n key.
  final String titleKey;
  final List<PlannedBlock> blocks;
  final int estimatedMinutes;
  final List<ReasonCode> reasons;

  Map<String, Object?> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'templateId': templateId,
        'templateVersion': templateVersion,
        'kind': kind.name,
        'discipline': discipline?.name,
        'intensity': intensity.name,
        'titleKey': titleKey,
        'blocks': [for (final b in blocks) b.toJson()],
        'estimatedMinutes': estimatedMinutes,
        'reasons': [for (final r in reasons) r.name],
      };
}
