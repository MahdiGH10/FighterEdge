import 'planned_day.dart';
import 'planned_session.dart';
import 'reason_code.dart';

/// Seven dated days, generated deterministically.
class PlannedWeek {
  const PlannedWeek({
    required this.weekStart,
    required this.planStart,
    required this.days,
    required this.generatorVersion,
    required this.templateSetVersion,
    required this.inputsHash,
    this.reasons = const [],
  });

  final DateTime weekStart;

  /// The plan's start date. Days before it are rest days that never count.
  final DateTime planStart;
  final List<PlannedDay> days;
  final int generatorVersion;
  final int templateSetVersion;
  final String inputsHash;

  /// Week-level reasons (days chosen, goal, level, no fight).
  final List<ReasonCode> reasons;

  Iterable<PlannedSession> get sessions => days.expand((d) => d.sessions);

  /// A canonical map for storage and for byte-for-byte comparison.
  Map<String, Object?> toJson() => {
        'weekStart': weekStart.toIso8601String(),
        'planStart': planStart.toIso8601String(),
        'generatorVersion': generatorVersion,
        'templateSetVersion': templateSetVersion,
        'inputsHash': inputsHash,
        'reasons': [for (final r in reasons) r.name],
        'days': [for (final d in days) d.toJson()],
      };
}
