import '../calculators/weekly_check_in.dart';
import '../models/nutrition_enums.dart';
import 'adaptive_check_in.dart';
import 'calendar_day.dart';

/// Why the calorie target changed.
enum TargetChangeKind {
  /// A new plan: first setup, a goal change or a recalculation. It restarts
  /// the data clock (Tier 0 again).
  planStart,

  /// The user applied a check-in step.
  checkInStep,

  /// The user applied an optional maintenance week.
  maintenanceWeek,

  /// The scheduled return to the previous target after a maintenance week.
  maintenanceWeekReturn,
}

/// One target change. Immutable. The target is a weekly-average kcal per day.
class TargetChange {
  const TargetChange({
    required this.day,
    required this.kind,
    required this.goal,
    required this.targetKcal,
    required this.policyVersion,
    this.previousKcal,
    this.reasons = const [],
  });

  /// The day the target takes effect.
  final CalendarDay day;
  final TargetChangeKind kind;
  final NutritionGoal goal;
  final int targetKcal;

  /// The target before; null for the first plan.
  final int? previousKcal;

  /// The check-in reasons behind it; empty for a plan start.
  final List<CheckInReason> reasons;

  /// The nutrition policy that produced the plan (2 today).
  final int policyVersion;
}

/// What a proposal offers.
enum ProposalKind { calorieStep, maintenanceWeek }

/// Where a proposal stands.
enum ProposalStatus {
  /// Waiting for Apply / Keep / Not now.
  pending,

  /// Apply: the target changed.
  applied,

  /// Keep current: a normal choice, remembered, not asked again soon.
  kept,

  /// Not now: no change; the next check-in may ask again.
  notNow,

  /// Never answered before the next check-in or plan, or no longer matched
  /// the target when answered.
  expired,
}

/// The user's answer to a proposal. The three buttons carry equal weight.
enum ProposalResponse { apply, keep, notNow }

/// A recommend-only change. Nothing happens until the user taps Apply.
class TargetProposal {
  const TargetProposal({
    required this.kind,
    required this.fromKcal,
    required this.toKcal,
    required this.reasons,
    this.days,
  });

  /// The proposal in [decision], or null when it proposes nothing.
  static TargetProposal? fromDecision(AdaptiveCheckInDecision decision) {
    if (!decision.isProposal || decision.deltaKcal == 0) return null;
    final isWeek = decision.outcome == CheckInOutcome.offerMaintenanceWeek;
    return TargetProposal(
      kind: isWeek ? ProposalKind.maintenanceWeek : ProposalKind.calorieStep,
      fromKcal: decision.proposedTargetKcal - decision.deltaKcal,
      toKcal: decision.proposedTargetKcal,
      reasons: decision.reasons,
      days: isWeek ? decision.maintenanceWeekDays : null,
    );
  }

  final ProposalKind kind;
  final int fromKcal;
  final int toKcal;
  final List<CheckInReason> reasons;

  /// Length of a maintenance week; null for a calorie step.
  final int? days;

  int get deltaKcal => toKcal - fromKcal;
}

/// One weekly check-in as it was shown, with the user's answer.
class CheckInRecord {
  const CheckInRecord({
    required this.day,
    required this.outcome,
    required this.reasons,
    this.observedWeeklyPercent,
    this.proposal,
    this.status,
    this.answeredOn,
  });

  final CalendarDay day;
  final CheckInOutcome outcome;
  final List<CheckInReason> reasons;

  /// The observed trend, signed percent of body weight per week.
  final double? observedWeeklyPercent;
  final TargetProposal? proposal;

  /// Null when there was no proposal.
  final ProposalStatus? status;
  final CalendarDay? answeredOn;

  CheckInRecord _withStatus(ProposalStatus s, CalendarDay? on) => CheckInRecord(
        day: day,
        outcome: outcome,
        reasons: reasons,
        observedWeeklyPercent: observedWeeklyPercent,
        proposal: proposal,
        status: s,
        answeredOn: on,
      );
}

/// The immutable record of targets and check-ins. Every change goes through
/// [TargetHistoryReducer]; the lists can not be modified.
class TargetHistory {
  TargetHistory._(
    List<TargetChange> changes,
    List<CheckInRecord> checkIns,
    this.lastEventDay,
  )   : changes = List.unmodifiable(changes),
        checkIns = List.unmodifiable(checkIns);

  /// No plan yet.
  static final TargetHistory empty = TargetHistory._(const [], const [], null);

  /// Chronological by [TargetChange.day]. May hold one future entry: the
  /// scheduled return after a maintenance week.
  final List<TargetChange> changes;

  /// Chronological.
  final List<CheckInRecord> checkIns;

  /// The day of the last accepted event; older events are ignored.
  final CalendarDay? lastEventDay;

  /// The change in force on [day], or null before the first plan.
  TargetChange? activeOn(CalendarDay day) {
    for (var k = changes.length - 1; k >= 0; k--) {
      if (!changes[k].day.isAfter(day)) return changes[k];
    }
    return null;
  }

  /// The weekly-average target on [day].
  int? targetOn(CalendarDay day) => activeOn(day)?.targetKcal;

  /// When the current plan started (the data clock for the tiers).
  CalendarDay? planStartOn(CalendarDay day) {
    for (var k = changes.length - 1; k >= 0; k--) {
      final c = changes[k];
      if (!c.day.isAfter(day) && c.kind == TargetChangeKind.planStart) {
        return c.day;
      }
    }
    return null;
  }

  /// The day of the last check-in change in force on [day] within the current
  /// plan; null when the plan has not changed since it started (the data
  /// tiers already hold a new plan). A maintenance week's return counts, so
  /// the week after it is left alone.
  CalendarDay? lastChangeOn(CalendarDay day) {
    final active = activeOn(day);
    if (active == null || active.kind == TargetChangeKind.planStart) {
      return null;
    }
    return active.day;
  }

  /// Whole weeks the target has been a deficit without a break, on [day]: 0
  /// unless a fat-loss target (not a maintenance week) is in force. The run
  /// starts at the first fat-loss change after the last maintenance week or
  /// non-loss goal.
  int continuousDeficitWeeks(CalendarDay day) {
    CalendarDay? start;
    for (var k = changes.length - 1; k >= 0; k--) {
      final c = changes[k];
      if (c.day.isAfter(day)) continue;
      if (c.goal != NutritionGoal.loseFat ||
          c.kind == TargetChangeKind.maintenanceWeek) {
        break;
      }
      start = c.day;
      if (c.kind == TargetChangeKind.maintenanceWeekReturn) break;
    }
    return start == null ? 0 : start.daysUntil(day) ~/ 7;
  }

  /// A maintenance week was offered and kept-current within [days] before
  /// [day].
  bool maintenanceOfferDeclinedWithin(CalendarDay day, {int days = 28}) =>
      checkIns.any((r) =>
          r.proposal?.kind == ProposalKind.maintenanceWeek &&
          r.status == ProposalStatus.kept &&
          r.answeredOn != null &&
          !r.answeredOn!.isAfter(day) &&
          r.answeredOn!.daysUntil(day) < days);

  /// The observed trend at the last check-in before [day].
  double? previousObservedWeeklyPercent(CalendarDay day) {
    for (var k = checkIns.length - 1; k >= 0; k--) {
      final r = checkIns[k];
      if (r.day.isBefore(day)) return r.observedWeeklyPercent;
    }
    return null;
  }

  /// The proposal waiting for an answer, if any.
  CheckInRecord? get pending {
    if (checkIns.isEmpty) return null;
    final last = checkIns.last;
    return last.status == ProposalStatus.pending ? last : null;
  }
}

/// Something that happened to the target. Pure value.
sealed class TargetHistoryEvent {
  const TargetHistoryEvent(this.day);
  final CalendarDay day;
}

/// A new plan from the formula (setup, goal change, recalculation).
class PlanStarted extends TargetHistoryEvent {
  const PlanStarted(
    super.day, {
    required this.goal,
    required this.targetKcal,
    required this.policyVersion,
  });
  final NutritionGoal goal;
  final int targetKcal;
  final int policyVersion;
}

/// A weekly check-in was shown.
class CheckInShown extends TargetHistoryEvent {
  const CheckInShown(
    super.day, {
    required this.decision,
    this.observedWeeklyPercent,
  });
  final AdaptiveCheckInDecision decision;
  final double? observedWeeklyPercent;
}

/// The user answered the pending proposal.
class ProposalAnswered extends TargetHistoryEvent {
  const ProposalAnswered(super.day, this.response);
  final ProposalResponse response;
}

/// The only way a [TargetHistory] changes. Pure: same history and event, same
/// result. An event that does not apply returns the same instance.
class TargetHistoryReducer {
  const TargetHistoryReducer._();

  /// An answer older than this many days after its check-in has expired.
  static const int answerWindowDays = 7;

  static TargetHistory reduce(TargetHistory h, TargetHistoryEvent e) {
    final lastDay = h.lastEventDay;
    if (lastDay != null && e.day.isBefore(lastDay)) return h;
    return switch (e) {
      PlanStarted() => _planStarted(h, e),
      CheckInShown() => _checkInShown(h, e),
      ProposalAnswered() => _answered(h, e),
    };
  }

  /// Folds [events] in order.
  static TargetHistory replay(
    Iterable<TargetHistoryEvent> events, {
    TargetHistory? from,
  }) =>
      events.fold(from ?? TargetHistory.empty, reduce);

  static TargetHistory _planStarted(TargetHistory h, PlanStarted e) {
    if (e.targetKcal <= 0) return h;
    // A scheduled return after the new plan's day no longer applies.
    final kept = [
      for (final c in h.changes)
        if (!c.day.isAfter(e.day)) c,
    ];
    final previous = h.targetOn(e.day);
    return TargetHistory._(
      [
        ...kept,
        TargetChange(
          day: e.day,
          kind: TargetChangeKind.planStart,
          goal: e.goal,
          targetKcal: e.targetKcal,
          previousKcal: previous,
          policyVersion: e.policyVersion,
        ),
      ],
      _expirePending(h.checkIns),
      e.day,
    );
  }

  static TargetHistory _checkInShown(TargetHistory h, CheckInShown e) {
    final proposal = TargetProposal.fromDecision(e.decision);
    final record = CheckInRecord(
      day: e.day,
      outcome: e.decision.outcome,
      reasons: e.decision.reasons,
      observedWeeklyPercent: e.observedWeeklyPercent,
      proposal: proposal,
      status: proposal == null ? null : ProposalStatus.pending,
    );
    return TargetHistory._(
      h.changes,
      [..._expirePending(h.checkIns), record],
      e.day,
    );
  }

  static TargetHistory _answered(TargetHistory h, ProposalAnswered e) {
    final record = h.pending;
    if (record == null) return h;
    final proposal = record.proposal!;
    final before = h.checkIns.sublist(0, h.checkIns.length - 1);
    final active = h.activeOn(e.day);
    final stale = active == null ||
        active.targetKcal != proposal.fromKcal ||
        record.day.daysUntil(e.day) >= answerWindowDays ||
        h.changes.any((c) => c.day.isAfter(e.day));
    if (stale) {
      return TargetHistory._(
        h.changes,
        [...before, record._withStatus(ProposalStatus.expired, e.day)],
        e.day,
      );
    }
    switch (e.response) {
      case ProposalResponse.keep:
      case ProposalResponse.notNow:
        final status = e.response == ProposalResponse.keep
            ? ProposalStatus.kept
            : ProposalStatus.notNow;
        return TargetHistory._(
          h.changes,
          [...before, record._withStatus(status, e.day)],
          e.day,
        );
      case ProposalResponse.apply:
        final isWeek = proposal.kind == ProposalKind.maintenanceWeek;
        final change = TargetChange(
          day: e.day,
          kind: isWeek
              ? TargetChangeKind.maintenanceWeek
              : TargetChangeKind.checkInStep,
          goal: active.goal,
          targetKcal: proposal.toKcal,
          previousKcal: proposal.fromKcal,
          reasons: proposal.reasons,
          policyVersion: active.policyVersion,
        );
        final back = isWeek
            ? TargetChange(
                day: e.day.plusDays(proposal.days ?? 7),
                kind: TargetChangeKind.maintenanceWeekReturn,
                goal: active.goal,
                targetKcal: proposal.fromKcal,
                previousKcal: proposal.toKcal,
                reasons: proposal.reasons,
                policyVersion: active.policyVersion,
              )
            : null;
        return TargetHistory._(
          [...h.changes, change, if (back != null) back],
          [...before, record._withStatus(ProposalStatus.applied, e.day)],
          e.day,
        );
    }
  }

  static List<CheckInRecord> _expirePending(List<CheckInRecord> records) => [
        for (final r in records)
          r.status == ProposalStatus.pending
              ? r._withStatus(ProposalStatus.expired, null)
              : r,
      ];
}
