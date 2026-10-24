import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/adaptive/adaptive_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/calendar_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/data_tier.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/target_history.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';

final _start = CalendarDay(2026, 8, 1);

AdaptiveCheckInDecision _decision({
  CheckInOutcome outcome = CheckInOutcome.propose,
  int from = 2200,
  int to = 2000,
  List<CheckInReason> reasons = const [CheckInReason.slowerThanPlanned],
  int? weekDays,
}) =>
    AdaptiveCheckInDecision(
      outcome: outcome,
      deltaKcal: to - from,
      proposedTargetKcal: to,
      reasons: reasons,
      tier: DataTier.tier1,
      floorKcal: 1700,
      safetyReaskDue: false,
      maintenanceWeekDays: weekDays,
    );

AdaptiveCheckInDecision _hold() => _decision(
      outcome: CheckInOutcome.hold,
      to: 2200,
      reasons: const [CheckInReason.onPace],
    );

AdaptiveCheckInDecision _week() => _decision(
      outcome: CheckInOutcome.offerMaintenanceWeek,
      to: 2640,
      reasons: const [CheckInReason.deficitDurationReached],
      weekDays: 7,
    );

TargetHistory _started({
  NutritionGoal goal = NutritionGoal.loseFat,
  int kcal = 2200,
}) =>
    TargetHistoryReducer.reduce(
      TargetHistory.empty,
      PlanStarted(_start, goal: goal, targetKcal: kcal, policyVersion: 2),
    );

TargetHistory _r(TargetHistory h, TargetHistoryEvent e) =>
    TargetHistoryReducer.reduce(h, e);

void main() {
  test('empty history has no target and nothing pending', () {
    final h = TargetHistory.empty;
    expect(h.targetOn(_start), isNull);
    expect(h.planStartOn(_start), isNull);
    expect(h.lastChangeOn(_start), isNull);
    expect(h.pending, isNull);
    expect(h.continuousDeficitWeeks(_start), 0);
    expect(h.previousObservedWeeklyPercent(_start), isNull);
    expect(h.lastEventDay, isNull);
  });

  test('a plan start sets the target and the data clock', () {
    final h = _started();
    expect(h.targetOn(_start), 2200);
    expect(h.targetOn(_start.plusDays(-1)), isNull);
    expect(h.planStartOn(_start.plusDays(30)), _start);
    expect(h.changes.single.kind, TargetChangeKind.planStart);
    expect(h.changes.single.previousKcal, isNull);
    expect(h.changes.single.policyVersion, 2);
    // A new plan is not a check-in change: the tiers already hold it.
    expect(h.lastChangeOn(_start.plusDays(3)), isNull);
  });

  test('a plan with no positive target is ignored', () {
    final h = _r(
      TargetHistory.empty,
      PlanStarted(_start,
          goal: NutritionGoal.maintain, targetKcal: 0, policyVersion: 2),
    );
    expect(identical(h, TargetHistory.empty), isTrue);
  });

  group('Apply / Keep / Not now', () {
    final shownOn = _start.plusDays(21);

    TargetHistory shown([AdaptiveCheckInDecision? d]) => _r(
          _started(),
          CheckInShown(
            shownOn,
            decision: d ?? _decision(),
            observedWeeklyPercent: -0.1,
          ),
        );

    test('a proposal waits; nothing changes until Apply', () {
      final h = shown();
      expect(h.pending, isNotNull);
      expect(h.pending!.status, ProposalStatus.pending);
      expect(h.pending!.proposal!.kind, ProposalKind.calorieStep);
      expect(h.pending!.proposal!.deltaKcal, -200);
      expect(h.targetOn(shownOn), 2200);
    });

    test('Apply changes the target and records why', () {
      final h = _r(shown(),
          ProposalAnswered(shownOn.plusDays(1), ProposalResponse.apply));
      final day = shownOn.plusDays(1);
      expect(h.targetOn(day), 2000);
      expect(h.targetOn(shownOn), 2200);
      final change = h.changes.last;
      expect(change.kind, TargetChangeKind.checkInStep);
      expect(change.previousKcal, 2200);
      expect(change.reasons, [CheckInReason.slowerThanPlanned]);
      expect(change.goal, NutritionGoal.loseFat);
      expect(h.checkIns.last.status, ProposalStatus.applied);
      expect(h.checkIns.last.answeredOn, day);
      expect(h.pending, isNull);
      expect(h.lastChangeOn(day.plusDays(3)), day);
    });

    test('Keep and Not now leave the target alone', () {
      final kept =
          _r(shown(), ProposalAnswered(shownOn, ProposalResponse.keep));
      expect(kept.targetOn(shownOn), 2200);
      expect(kept.checkIns.last.status, ProposalStatus.kept);
      final later =
          _r(shown(), ProposalAnswered(shownOn, ProposalResponse.notNow));
      expect(later.checkIns.last.status, ProposalStatus.notNow);
      expect(later.changes, hasLength(1));
    });

    test('an answer with nothing pending changes nothing', () {
      final h = _r(_started(), CheckInShown(shownOn, decision: _hold()));
      expect(h.pending, isNull);
      expect(h.checkIns.single.status, isNull);
      final same = _r(h, ProposalAnswered(shownOn, ProposalResponse.apply));
      expect(identical(same, h), isTrue);
    });

    test('an answer a week late has expired', () {
      final h = _r(shown(),
          ProposalAnswered(shownOn.plusDays(7), ProposalResponse.apply));
      expect(h.targetOn(shownOn.plusDays(7)), 2200);
      expect(h.checkIns.last.status, ProposalStatus.expired);
    });

    test('a proposal made against another target has expired', () {
      final h = shown(_decision(from: 2300, to: 2100));
      final answered = _r(h, ProposalAnswered(shownOn, ProposalResponse.apply));
      expect(answered.targetOn(shownOn), 2200);
      expect(answered.checkIns.last.status, ProposalStatus.expired);
    });

    test('the next check-in or a new plan expires an unanswered proposal', () {
      final next =
          _r(shown(), CheckInShown(shownOn.plusDays(7), decision: _hold()));
      expect(next.checkIns.first.status, ProposalStatus.expired);
      expect(next.pending, isNull);
      final plan = _r(
        shown(),
        PlanStarted(shownOn.plusDays(2),
            goal: NutritionGoal.maintain, targetKcal: 2600, policyVersion: 2),
      );
      expect(plan.checkIns.single.status, ProposalStatus.expired);
      expect(plan.targetOn(shownOn.plusDays(2)), 2600);
      expect(plan.changes.last.previousKcal, 2200);
    });

    test('events older than the last one are ignored', () {
      final h = shown();
      final old =
          _r(h, ProposalAnswered(shownOn.plusDays(-1), ProposalResponse.apply));
      expect(identical(old, h), isTrue);
    });

    test('a zero-delta proposal is stored as a hold', () {
      final h =
          _r(_started(), CheckInShown(shownOn, decision: _decision(to: 2200)));
      expect(h.pending, isNull);
      expect(h.checkIns.single.proposal, isNull);
    });

    test('the observed trend of the last check-in is remembered', () {
      final h = shown();
      expect(h.previousObservedWeeklyPercent(shownOn), isNull);
      expect(h.previousObservedWeeklyPercent(shownOn.plusDays(7)), -0.1);
    });
  });

  group('maintenance week', () {
    final shownOn = _start.plusDays(70);

    TargetHistory applied() => _r(
          _r(_started(), CheckInShown(shownOn, decision: _week())),
          ProposalAnswered(shownOn, ProposalResponse.apply),
        );

    test('Apply runs 7 days at maintenance, then returns', () {
      final h = applied();
      expect(h.targetOn(shownOn), 2640);
      expect(h.targetOn(shownOn.plusDays(6)), 2640);
      expect(h.targetOn(shownOn.plusDays(7)), 2200);
      expect(h.changes.map((c) => c.kind), [
        TargetChangeKind.planStart,
        TargetChangeKind.maintenanceWeek,
        TargetChangeKind.maintenanceWeekReturn,
      ]);
      // The week after the return is left alone.
      expect(h.lastChangeOn(shownOn.plusDays(10)), shownOn.plusDays(7));
    });

    test('the deficit clock counts weeks and restarts after the week', () {
      final before = _started();
      expect(before.continuousDeficitWeeks(_start.plusDays(69)), 9);
      expect(before.continuousDeficitWeeks(_start.plusDays(70)), 10);
      final h = applied();
      expect(h.continuousDeficitWeeks(shownOn.plusDays(3)), 0);
      expect(h.continuousDeficitWeeks(shownOn.plusDays(7)), 0);
      expect(h.continuousDeficitWeeks(shownOn.plusDays(21)), 2);
    });

    test('steps inside one deficit run do not restart the clock', () {
      var h = _r(
          _started(), CheckInShown(_start.plusDays(21), decision: _decision()));
      h = _r(h, ProposalAnswered(_start.plusDays(21), ProposalResponse.apply));
      expect(h.continuousDeficitWeeks(_start.plusDays(35)), 5);
    });

    test('no deficit clock for a maintain or gain plan', () {
      expect(
        _started(goal: NutritionGoal.maintain)
            .continuousDeficitWeeks(_start.plusDays(100)),
        0,
      );
      final switched = _r(
        _started(goal: NutritionGoal.maintain),
        PlanStarted(_start.plusDays(50),
            goal: NutritionGoal.loseFat, targetKcal: 2100, policyVersion: 2),
      );
      expect(switched.continuousDeficitWeeks(_start.plusDays(71)), 3);
    });

    test('a new plan during the week drops the scheduled return', () {
      final h = _r(
        applied(),
        PlanStarted(shownOn.plusDays(3),
            goal: NutritionGoal.maintain, targetKcal: 2500, policyVersion: 2),
      );
      expect(h.targetOn(shownOn.plusDays(10)), 2500);
      expect(h.changes.last.kind, TargetChangeKind.planStart);
    });

    test('an answer while a return is scheduled has expired', () {
      final h = _r(
        _r(
            applied(),
            CheckInShown(shownOn.plusDays(2),
                decision: _decision(from: 2640, to: 2440))),
        ProposalAnswered(shownOn.plusDays(2), ProposalResponse.apply),
      );
      expect(h.checkIns.last.status, ProposalStatus.expired);
      expect(h.targetOn(shownOn.plusDays(2)), 2640);
    });

    test('Keep on a maintenance week is remembered for 4 weeks', () {
      final h = _r(
        _r(_started(), CheckInShown(shownOn, decision: _week())),
        ProposalAnswered(shownOn, ProposalResponse.keep),
      );
      expect(h.maintenanceOfferDeclinedWithin(shownOn.plusDays(27)), isTrue);
      expect(h.maintenanceOfferDeclinedWithin(shownOn.plusDays(28)), isFalse);
      expect(h.maintenanceOfferDeclinedWithin(shownOn.plusDays(-1)), isFalse);
      final notNow = _r(
        _r(_started(), CheckInShown(shownOn, decision: _week())),
        ProposalAnswered(shownOn, ProposalResponse.notNow),
      );
      expect(
          notNow.maintenanceOfferDeclinedWithin(shownOn.plusDays(7)), isFalse);
    });
  });

  test('the history cannot be edited in place', () {
    final h = _started();
    expect(
      () => h.changes.add(h.changes.first),
      throwsUnsupportedError,
    );
    expect(() => h.checkIns.clear(), throwsUnsupportedError);
  });

  test('replay folds the events in order', () {
    final events = <TargetHistoryEvent>[
      PlanStarted(_start,
          goal: NutritionGoal.loseFat, targetKcal: 2200, policyVersion: 2),
      CheckInShown(_start.plusDays(21), decision: _decision()),
      ProposalAnswered(_start.plusDays(22), ProposalResponse.apply),
    ];
    final h = TargetHistoryReducer.replay(events);
    expect(h.targetOn(_start.plusDays(22)), 2000);
    expect(h.lastEventDay, _start.plusDays(22));
    final again = TargetHistoryReducer.replay(events.skip(1), from: _started());
    expect(again.targetOn(_start.plusDays(22)), 2000);
  });
}
