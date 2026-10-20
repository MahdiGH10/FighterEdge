import '../../fight_camp/domain/calendar.dart';
import 'models/planned_day.dart';
import 'models/planned_session.dart';
import 'models/planned_week.dart';
import 'models/session_kind.dart';
import 'models/session_status.dart';

/// One logged piece of training, reduced to what the plan needs. A later PR
/// adds `plannedSessionId` to `TrainingLogEntry` and maps entries to this.
///
/// The caller decides which entries are passed: a Reaction drill or a very
/// short timer session should be left out (proposal decision 9).
class CompletionRecord {
  const CompletionRecord({this.plannedSessionId, required this.date});

  /// The planned session this record fulfils, if the log knows.
  final String? plannedSessionId;

  /// The calendar day it happened.
  final DateTime date;
}

enum AdjustmentKind { skipped, moved }

/// The athlete skipped or moved a planned session.
class SessionAdjustment {
  const SessionAdjustment.skipped(this.sessionId)
      : kind = AdjustmentKind.skipped,
        movedTo = null;

  const SessionAdjustment.moved(this.sessionId, DateTime this.movedTo)
      : kind = AdjustmentKind.moved;

  final String sessionId;
  final AdjustmentKind kind;
  final DateTime? movedTo;
}

/// A planned session as shown on one date, with its status.
class ResolvedSession {
  const ResolvedSession({
    required this.session,
    required this.date,
    required this.status,
    this.movedTo,
    this.movedFrom,
  });

  final PlannedSession session;

  /// The date this row is shown on: the planned date, or the new date of a
  /// moved session.
  final DateTime date;
  final SessionStatus status;

  /// Set on the original-date row of a moved session ("Moved to Thu").
  final DateTime? movedTo;

  /// Set on the new-date row of a moved session.
  final DateTime? movedFrom;
}

/// Joins the plan with what the athlete did. The plan says what should
/// happen, the log says what did; nothing is stored.
class SessionStatusResolver {
  const SessionStatusResolver();

  /// Status of every session in [weeks], one row per displayed date. A moved
  /// session gives two rows: [SessionStatus.moved] on its original date and
  /// its real status on the new date.
  ///
  /// A record completes the session it names. A record without an id
  /// completes a session planned on the same date that no named record
  /// already completed. Each record completes at most one session.
  List<ResolvedSession> resolve({
    required Iterable<PlannedWeek> weeks,
    required DateTime today,
    Iterable<CompletionRecord> completions = const [],
    Iterable<SessionAdjustment> adjustments = const [],
  }) {
    final byId = {for (final a in adjustments) a.sessionId: a};
    final sessions = [for (final w in weeks) ...w.sessions];

    // Rows to resolve: (session, date shown, movedFrom).
    final rows = <({PlannedSession session, DateTime date, DateTime? from})>[];
    final moves = <ResolvedSession>[];
    for (final session in sessions) {
      final adjustment = byId[session.id];
      if (adjustment?.kind == AdjustmentKind.moved) {
        final to = calendarDay(adjustment!.movedTo!);
        moves.add(ResolvedSession(
          session: session,
          date: session.date,
          status: SessionStatus.moved,
          movedTo: to,
        ));
        rows.add((session: session, date: to, from: session.date));
      } else {
        rows.add((session: session, date: session.date, from: null));
      }
    }
    rows.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.session.id.compareTo(b.session.id);
    });

    // Completions: named records first, then unnamed ones by date.
    final records = completions.toList();
    final used = <int>{};
    final completedOn = <int, DateTime>{};
    for (var i = 0; i < rows.length; i++) {
      final index = records.indexWhere(
        (r) => r.plannedSessionId == rows[i].session.id,
      );
      if (index >= 0 && used.add(index)) completedOn[i] = records[index].date;
    }
    for (var i = 0; i < rows.length; i++) {
      if (completedOn.containsKey(i)) continue;
      for (var j = 0; j < records.length; j++) {
        if (used.contains(j) ||
            records[j].plannedSessionId != null ||
            daysBetween(records[j].date, rows[i].date) != 0) {
          continue;
        }
        used.add(j);
        completedOn[i] = records[j].date;
        break;
      }
    }

    final resolved = <ResolvedSession>[...moves];
    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      final skipped = byId[row.session.id]?.kind == AdjustmentKind.skipped;
      resolved.add(ResolvedSession(
        session: row.session,
        date: row.date,
        status: statusOf(
          row.session,
          date: row.date,
          today: today,
          completed: completedOn.containsKey(i),
          skipped: skipped,
        ),
        movedFrom: row.from,
      ));
    }
    resolved.sort((a, b) {
      final byDate = a.date.compareTo(b.date);
      return byDate != 0 ? byDate : a.session.id.compareTo(b.session.id);
    });
    return resolved;
  }

  /// The status of a single session shown on [date].
  SessionStatus statusOf(
    PlannedSession session, {
    required DateTime date,
    required DateTime today,
    bool completed = false,
    bool skipped = false,
  }) {
    if (completed) return SessionStatus.completed;
    if (skipped) return SessionStatus.skipped;
    final fromToday = daysBetween(today, date);
    if (fromToday == 0) return SessionStatus.today;
    if (fromToday > 0) return SessionStatus.planned;
    // A recovery session nobody did is never a miss.
    return session.kind == SessionKind.recovery
        ? SessionStatus.rest
        : SessionStatus.missed;
  }

  /// The status of a day with no session: [SessionStatus.beforeStart] before
  /// the plan began, [SessionStatus.rest] otherwise.
  SessionStatus emptyDayStatus(PlannedWeek week, PlannedDay day) =>
      daysBetween(week.planStart, day.date) < 0
          ? SessionStatus.beforeStart
          : SessionStatus.rest;
}
