import '../../../fight_camp/domain/calendar.dart';
import '../models/session_kind.dart';
import '../models/session_status.dart';
import '../session_status_resolver.dart';

/// The weekly target: every planned session, or one fewer when the week has
/// [slackFromPlannedSessions] or more (proposal decision 8; needs owner
/// confirmation).
class WeeklyTarget {
  WeeklyTarget._();

  static const int slackFromPlannedSessions = 5;

  static int forPlanned(int planned) =>
      planned >= slackFromPlannedSessions ? planned - 1 : planned;
}

/// Planned versus done for one week.
///
/// Rest days and recovery sessions are never counted: rest is planned, not
/// missed. A moved session counts once, in the week of its new date.
class WeeklyAdherence {
  const WeeklyAdherence({
    required this.weekStart,
    required this.planned,
    required this.completed,
    this.skipped = 0,
    this.missed = 0,
    this.upcoming = 0,
    this.freezeCovered = 0,
    required this.closed,
  });

  /// Counts the rows of [resolved] shown in the seven days from [weekStart].
  /// Pass the rows of every plan week: a session moved here from another week
  /// counts here, and a session moved away does not count.
  factory WeeklyAdherence.fromResolved({
    required DateTime weekStart,
    required Iterable<ResolvedSession> resolved,
    required DateTime today,
    int freezeCovered = 0,
  }) {
    final start = calendarDay(weekStart);
    var planned = 0;
    var completed = 0;
    var skipped = 0;
    var missed = 0;
    var upcoming = 0;
    for (final row in resolved) {
      final offset = daysBetween(start, row.date);
      if (offset < 0 || offset > 6) continue;
      if (row.movedTo != null) continue;
      if (row.session.kind == SessionKind.recovery) continue;
      planned++;
      switch (row.status) {
        case SessionStatus.completed:
          completed++;
        case SessionStatus.skipped:
          skipped++;
        case SessionStatus.missed:
          missed++;
        case SessionStatus.planned:
        case SessionStatus.today:
          upcoming++;
        case SessionStatus.beforeStart:
        case SessionStatus.moved:
        case SessionStatus.rest:
          break;
      }
    }
    return WeeklyAdherence(
      weekStart: start,
      planned: planned,
      completed: completed,
      skipped: skipped,
      missed: missed,
      upcoming: upcoming,
      freezeCovered: freezeCovered,
      closed: daysBetween(start, today) >= 7,
    );
  }

  final DateTime weekStart;
  final int planned;
  final int completed;
  final int skipped;
  final int missed;

  /// Planned or today, still possible to do.
  final int upcoming;

  /// Missed sessions a streak freeze covers this week.
  final int freezeCovered;

  /// The week is over.
  final bool closed;

  /// Nothing planned: a rest-only week. Neutral for the streak.
  bool get isRestOnly => planned == 0;

  int get target => WeeklyTarget.forPlanned(planned);

  int get effectiveCompleted => completed + freezeCovered;

  bool get met => effectiveCompleted >= target;

  /// The week can still meet its target (or already has).
  bool get alive => met || (!closed && effectiveCompleted + upcoming >= target);

  /// Completed over planned; 0 for a rest-only week.
  double get ratio => planned == 0 ? 0 : completed / planned;

  WeeklyAdherence withFreezeCovered(int covered) => WeeklyAdherence(
        weekStart: weekStart,
        planned: planned,
        completed: completed,
        skipped: skipped,
        missed: missed,
        upcoming: upcoming,
        freezeCovered: covered,
        closed: closed,
      );
}
