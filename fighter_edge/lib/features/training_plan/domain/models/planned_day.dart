import 'day_type.dart';
import 'planned_session.dart';
import 'reason_code.dart';

/// One calendar day of a planned week.
class PlannedDay {
  const PlannedDay({
    required this.date,
    required this.type,
    this.sessions = const [],
    this.reasons = const [],
  });

  final DateTime date;
  final DayType type;

  /// Empty on a rest day; one session otherwise.
  final List<PlannedSession> sessions;

  /// Why the day is what it is, when no session carries the reason (a fight
  /// day, a rest day after the weigh-in).
  final List<ReasonCode> reasons;

  Map<String, Object?> toJson() => {
        'date': date.toIso8601String(),
        'type': type.name,
        'sessions': [for (final s in sessions) s.toJson()],
        'reasons': [for (final r in reasons) r.name],
      };
}
