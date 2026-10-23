import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/adaptive/adaptive_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/calendar_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/data_tier.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/fuel_log_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/weight_slope.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';

final _today = CalendarDay(2026, 10, 22);

LogWindow _week({double? avg = 2200, int days = 7, int partial = 0}) =>
    LogWindow(
      daysCounted: days,
      partialDays: partial,
      daysWithEntries: days + partial,
      averageIntakeKcal: avg,
    );

DataTierAssessment _tier({
  DataTier tier = DataTier.tier1,
  List<CheckInReason> reasons = const [],
  LogWindow? thisWeek,
  LogWindow? lastWeek,
}) =>
    DataTierAssessment(
      tier: tier,
      reasons: reasons,
      dataDays: 28,
      thisWeek: thisWeek ?? _week(),
      lastWeek: lastWeek ?? _week(),
      weekBefore: _week(),
      weighInDaysThisWeek: 7,
      weighInDaysLastWeek: 7,
      weighInDaysIn21: 21,
    );

WeightSlope _slope(double kgPerWeek, {double band = 0.05}) => WeightSlope(
      status: WeightSlopeStatus.ok,
      windowDays: 21,
      slopeKgPerDay: kgPerWeek / 7,
      noiseBandKgPerWeek: band,
      residualSdKg: 0.3,
      pointsUsed: 21,
      spanDays: 20,
    );

/// 30-year-old, 80 kg, losing 0.5% a week (0.4 kg), target 2,200, floor
/// 1,700, eating to plan, on pace, safety questions answered 10 days ago.
AdaptiveCheckInInput _in({
  int? age = 30,
  NutritionGoal goal = NutritionGoal.loseFat,
  double target = 2200,
  double minimum = 1700,
  double? maximum = 2640,
  double? maintenance = 2640,
  double weight = 80,
  double planned = 0.5,
  double rmr = 1700,
  double session = 0,
  bool clinical = false,
  DataTierAssessment? tier,
  WeightSlope? slope,
  double observed = -0.4,
  bool fightWeek = false,
  bool camp = false,
  CalendarDay? lastChange,
  double? previous,
  LoggingSelfReport? report,
  int deficitWeeks = 0,
  bool declined = false,
  CalendarDay? screened,
  bool neverScreened = false,
}) =>
    AdaptiveCheckInInput(
      today: _today,
      ageYears: age,
      goal: goal,
      currentTargetKcal: target,
      minimumKcal: minimum,
      maximumKcal: maximum,
      maintenanceKcal: maintenance,
      currentWeightKg: weight,
      plannedWeeklyChangePercent: planned,
      restingEnergyKcal: rmr,
      averageSessionKcalPerDay: session,
      clinicalReviewNeeded: clinical,
      tier: tier ?? _tier(),
      slope: slope ?? _slope(observed),
      inFightWeek: fightWeek,
      inFightCamp: camp,
      lastTargetChangeDay: lastChange,
      previousObservedWeeklyPercent: previous,
      loggingSelfReport: report,
      continuousDeficitWeeks: deficitWeeks,
      maintenanceOfferRecentlyDeclined: declined,
      lastSafetyScreenDay:
          neverScreened ? null : (screened ?? _today.plusDays(-10)),
    );

AdaptiveCheckInDecision _d(AdaptiveCheckInInput i) =>
    AdaptiveWeeklyCheckIn.decide(i);

void main() {
  group('age', () {
    test('unknown age or under 18: not eligible, no numbers at all', () {
      for (final age in [null, 17, 0]) {
        final d = _d(_in(age: age, observed: 0));
        expect(d.outcome, CheckInOutcome.notEligible);
        expect(d.reasons, [CheckInReason.ageNotEligible]);
        expect(d.deltaKcal, 0);
        expect(d.proposedTargetKcal, 0);
        expect(d.isProposal, isFalse);
        expect(d.safetyReaskDue, isFalse);
      }
    });

    test('age beats every other rule, even a safety referral', () {
      final d = _d(_in(age: 16, clinical: true));
      expect(d.outcome, CheckInOutcome.notEligible);
    });

    test('18 is eligible', () {
      expect(_d(_in(age: 18)).outcome, CheckInOutcome.hold);
      expect(AdaptiveWeeklyCheckIn.isEligibleAge(18), isTrue);
      expect(AdaptiveWeeklyCheckIn.isEligibleAge(17), isFalse);
      expect(AdaptiveWeeklyCheckIn.isEligibleAge(null), isFalse);
    });
  });

  group('invalid input holds', () {
    final broken = <String, AdaptiveCheckInInput>{
      'target': _in(target: double.nan),
      'minimum': _in(minimum: 0),
      'weight': _in(weight: -1),
      'rmr': _in(rmr: double.infinity),
      'planned': _in(planned: -0.5),
      'planned nan': _in(planned: double.nan),
      'session': _in(session: double.nan),
      'session negative': _in(session: -1),
      'maximum': _in(maximum: 0),
      'maintenance': _in(maintenance: double.nan),
      'previous': _in(previous: double.nan),
      'deficit weeks': _in(deficitWeeks: -1),
      'slope': _in(slope: _slope(double.nan)),
      'band': _in(slope: _slope(-0.4, band: double.infinity)),
      'intake': _in(tier: _tier(thisWeek: _week(avg: double.nan))),
      'intake negative': _in(tier: _tier(lastWeek: _week(avg: -5))),
    };
    for (final e in broken.entries) {
      test(e.key, () {
        final d = _d(e.value);
        expect(d.outcome, CheckInOutcome.hold);
        expect(d.reasons, [CheckInReason.invalidInput]);
        expect(d.deltaKcal, 0);
        expect(d.safetyReaskDue, isFalse);
      });
    }
  });

  group('safety escalation', () {
    test('a clinical flag is a referral, never a number', () {
      final d = _d(_in(clinical: true, observed: 0));
      expect(d.outcome, CheckInOutcome.referral);
      expect(d.isReferral, isTrue);
      expect(d.reasons, [CheckInReason.clinicalReviewFlagged]);
      expect(d.deltaKcal, 0);
      expect(d.proposedTargetKcal, 2200);
    });

    test('logged intake under resting energy two weeks running', () {
      final low = _tier(thisWeek: _week(avg: 1600), lastWeek: _week(avg: 1650));
      final d = _d(_in(tier: low));
      expect(d.outcome, CheckInOutcome.referral);
      expect(d.reasons, [CheckInReason.lowIntakeSafety]);
    });

    test('one low week, or a thin week, is not chronic', () {
      final oneWeek = _d(_in(tier: _tier(thisWeek: _week(avg: 1600))));
      expect(oneWeek.outcome, isNot(CheckInOutcome.referral));
      expect(oneWeek.reasons, [CheckInReason.intakeOffTarget]);
      final thin = _d(_in(
        tier: _tier(
          thisWeek: _week(avg: 1600, days: 4),
          lastWeek: _week(avg: 1600),
        ),
      ));
      expect(thin.outcome, isNot(CheckInOutcome.referral));
    });

    test('loss above 1% a week two check-ins running', () {
      // -0.9 kg at 80 kg is -1.125% a week.
      final d = _d(_in(observed: -0.9, previous: -1.2));
      expect(d.outcome, CheckInOutcome.referral);
      expect(d.reasons, [CheckInReason.lossAboveCap]);
      expect(d.deltaKcal, 0);
      final once = _d(_in(observed: -0.9, previous: -0.8));
      expect(once.outcome, isNot(CheckInOutcome.referral));
    });

    test('every reason that applies is listed, clinical first', () {
      final d = _d(_in(
        clinical: true,
        tier: _tier(thisWeek: _week(avg: 1600), lastWeek: _week(avg: 1600)),
        observed: -0.9,
        previous: -1.5,
      ));
      expect(d.reasons, [
        CheckInReason.clinicalReviewFlagged,
        CheckInReason.lowIntakeSafety,
        CheckInReason.lossAboveCap,
      ]);
    });

    test('safety beats fight week, recent change and Tier 0', () {
      for (final i in [
        _in(clinical: true, fightWeek: true),
        _in(clinical: true, lastChange: _today.plusDays(-1)),
        _in(clinical: true, tier: _tier(tier: DataTier.tier0)),
      ]) {
        expect(_d(i).outcome, CheckInOutcome.referral);
      }
    });

    test('one fast week asks for more food, never less', () {
      final d = _d(_in(observed: -0.9));
      expect(d.outcome, CheckInOutcome.propose);
      expect(d.deltaKcal, 200);
      expect(d.reasons, [
        CheckInReason.fasterThanPlanned,
        CheckInReason.lossAboveCap,
      ]);
    });

    test('one fast week rides along on any hold', () {
      final fightWeek = _d(_in(observed: -0.9, fightWeek: true));
      expect(fightWeek.reasons,
          [CheckInReason.fightWeek, CheckInReason.lossAboveCap]);
      final offTarget = _d(_in(
        observed: -0.9,
        tier: _tier(thisWeek: _week(avg: 1800)),
      ));
      expect(offTarget.reasons,
          [CheckInReason.intakeOffTarget, CheckInReason.lossAboveCap]);
      final implausible = _d(_in(observed: -2.0));
      expect(implausible.reasons, [
        CheckInReason.implausibleWeightChange,
        CheckInReason.lossAboveCap,
      ]);
    });

    test('a camp plan losing 1% on pace is still flagged when beyond 1%', () {
      final d = _d(_in(camp: true, planned: 1.0, observed: -0.85));
      expect(d.outcome, CheckInOutcome.hold);
      expect(d.reasons, [CheckInReason.onPace, CheckInReason.lossAboveCap]);
    });
  });

  group('holds before the numbers', () {
    test('fight week', () {
      final d = _d(_in(fightWeek: true, observed: 0));
      expect(d.reasons, [CheckInReason.fightWeek]);
    });

    test('one change a week', () {
      final recent = _d(_in(lastChange: _today.plusDays(-6), observed: 0));
      expect(recent.reasons, [CheckInReason.recentChange]);
      final weekOld = _d(_in(lastChange: _today.plusDays(-7), observed: 0));
      expect(weekOld.outcome, CheckInOutcome.propose);
    });

    test('Tier 0 passes its reasons on, or says the plan is new', () {
      final tier0 = _d(_in(
        tier: _tier(
          tier: DataTier.tier0,
          reasons: const [
            CheckInReason.insufficientLogging,
            CheckInReason.insufficientWeighIns,
          ],
        ),
      ));
      expect(tier0.reasons, [
        CheckInReason.insufficientLogging,
        CheckInReason.insufficientWeighIns,
      ]);
      expect(tier0.tier, DataTier.tier0);
      final bare = _d(_in(tier: _tier(tier: DataTier.tier0)));
      expect(bare.reasons, [CheckInReason.programTooNew]);
    });

    test('partial days, or a "some"/"none" answer, are not data', () {
      final partial = _d(_in(tier: _tier(thisWeek: _week(partial: 1))));
      expect(partial.reasons, [CheckInReason.partialLoggingFlagged]);
      for (final r in [LoggingSelfReport.some, LoggingSelfReport.none]) {
        expect(
            _d(_in(report: r)).reasons, [CheckInReason.partialLoggingFlagged]);
      }
      for (final r in [LoggingSelfReport.all, LoggingSelfReport.most]) {
        expect(_d(_in(report: r)).reasons, [CheckInReason.onPace]);
      }
    });

    test('no usable slope', () {
      final d = _d(_in(slope: const WeightSlope.none()));
      expect(d.reasons, [CheckInReason.insufficientWeighIns]);
      expect(d.observedKgPerWeek, isNull);
    });

    test('implausible change', () {
      final d = _d(_in(observed: 1.8)); // +2.25% a week
      expect(d.reasons, [CheckInReason.implausibleWeightChange]);
    });

    test('no intake figure, or intake off target', () {
      final none = _d(_in(tier: _tier(thisWeek: _week(avg: null))));
      expect(none.reasons, [CheckInReason.insufficientLogging]);
      final off = _d(_in(tier: _tier(thisWeek: _week(avg: 2450))));
      expect(off.reasons, [CheckInReason.intakeOffTarget]);
      final close = _d(_in(tier: _tier(thisWeek: _week(avg: 2400))));
      expect(close.reasons, [CheckInReason.onPace]);
    });
  });

  group('the weekly formula', () {
    test('on pace holds and shows its numbers', () {
      final d = _d(_in());
      expect(d.outcome, CheckInOutcome.hold);
      expect(d.reasons, [CheckInReason.onPace]);
      expect(d.copyKey, 'fuel.checkIn.hold.onPace');
      expect(d.plannedKgPerWeek, closeTo(-0.4, 1e-9));
      expect(d.observedKgPerWeek, closeTo(-0.4, 1e-9));
      expect(d.errorKgPerWeek, closeTo(0, 1e-9));
      expect(d.deadBandKgPerWeek, closeTo(0.1, 1e-9));
    });

    test('a wide noise band widens on pace', () {
      final d = _d(_in(observed: -0.12, slope: _slope(-0.12, band: 0.4)));
      expect(d.reasons, [CheckInReason.onPace]);
      expect(d.deadBandKgPerWeek, closeTo(0.4, 1e-9));
    });

    test('error 0.4 kg: correction -440, step clamped to 200', () {
      final d = _d(_in(observed: 0));
      expect(d.outcome, CheckInOutcome.propose);
      expect(d.reasons, [CheckInReason.slowerThanPlanned]);
      expect(d.errorKgPerWeek, closeTo(0.4, 1e-9));
      expect(d.correctionKcalPerDay, closeTo(-440, 1e-6));
      expect(d.stepKcal, 200);
      expect(d.deltaKcal, -200);
      expect(d.proposedTargetKcal, 2000);
      expect(d.copyKeys, ['fuel.checkIn.propose.slowerThanPlanned']);
    });

    test('error 0.28 kg: half of 308 is 154, rounded to 150', () {
      final d = _d(_in(observed: -0.12));
      expect(d.stepKcal, 150);
      expect(d.proposedTargetKcal, 2050);
    });

    test('error 0.15 kg: half of 165 is under 100, lifted to 100', () {
      final d = _d(_in(observed: -0.25));
      expect(d.stepKcal, 100);
      expect(d.proposedTargetKcal, 2100);
    });

    test('faster than planned asks for more, up to the ceiling', () {
      final d = _d(_in(observed: -0.75));
      expect(d.outcome, CheckInOutcome.propose);
      expect(d.reasons, [CheckInReason.fasterThanPlanned]);
      expect(d.deltaKcal, 190);
      final capped = _d(_in(observed: -0.75, maximum: 2250));
      expect(capped.outcome, CheckInOutcome.hold);
      expect(capped.reasons, [CheckInReason.atCalorieCeiling]);
      final partly = _d(_in(observed: -0.75, maximum: 2345));
      expect(partly.proposedTargetKcal, 2340);
    });

    test('the plan rate is capped: 0.75% outside a camp, 1% inside', () {
      double plan(double pct, {bool camp = false, double kg = 80}) =>
          AdaptiveWeeklyCheckIn.signedPlannedPercent(
            goal: NutritionGoal.loseFat,
            weightKg: kg,
            requestedPercent: pct,
            inFightCamp: camp,
          );
      expect(plan(1.0), -0.75);
      expect(plan(1.0, camp: true), -1.0);
      expect(plan(1.0, camp: true, kg: 150), closeTo(-1 / 1.5, 1e-12));
      expect(
        AdaptiveWeeklyCheckIn.signedPlannedPercent(
          goal: NutritionGoal.gainMuscle,
          weightKg: 80,
          requestedPercent: 2,
        ),
        0.5,
      );
      expect(
        AdaptiveWeeklyCheckIn.signedPlannedPercent(
          goal: NutritionGoal.maintain,
          weightKg: 80,
          requestedPercent: 2,
        ),
        0,
      );
      final d = _d(_in(planned: 1.0, observed: -0.6));
      expect(d.plannedKgPerWeek, closeTo(-0.6, 1e-9));
      expect(d.reasons, [CheckInReason.onPace]);
    });

    test('muscle gain mirrors it', () {
      final slow = _d(_in(
        goal: NutritionGoal.gainMuscle,
        planned: 0.25,
        maximum: null,
        observed: 0,
      ));
      expect(slow.reasons, [CheckInReason.slowerThanPlanned]);
      expect(slow.deltaKcal, 110);
      final fast = _d(_in(
        goal: NutritionGoal.gainMuscle,
        planned: 0.25,
        maximum: null,
        observed: 0.6,
      ));
      expect(fast.reasons, [CheckInReason.fasterThanPlanned]);
      expect(fast.deltaKcal, -200);
    });

    test('maintenance corrects drift both ways', () {
      final up = _d(_in(
          goal: NutritionGoal.maintain,
          planned: 0,
          maximum: null,
          observed: 0.32));
      expect(up.reasons, [CheckInReason.maintenanceDriftUp]);
      expect(up.deltaKcal, -180);
      final down = _d(_in(
          goal: NutritionGoal.maintain,
          planned: 0,
          maximum: null,
          observed: -0.32));
      expect(down.reasons, [CheckInReason.maintenanceDriftDown]);
      expect(down.deltaKcal, 180);
    });

    test('stepFor clamps to 100..200 on tens', () {
      expect(AdaptiveWeeklyCheckIn.stepFor(0), 100);
      expect(AdaptiveWeeklyCheckIn.stepFor(-150), 100);
      expect(AdaptiveWeeklyCheckIn.stepFor(260), 130);
      expect(AdaptiveWeeklyCheckIn.stepFor(-370), 190);
      expect(AdaptiveWeeklyCheckIn.stepFor(5000), 200);
      expect(AdaptiveWeeklyCheckIn.kcalPerKgPerWeekPerDay, 1100);
      expect(AdaptiveWeeklyCheckIn.signOffPending, isTrue);
    });
  });

  group('floors', () {
    test('a step down stops at the floor; less than 100 left is a hold', () {
      final d = _d(_in(
        target: 1750,
        maintenance: null,
        tier: _tier(thisWeek: _week(avg: 1750), lastWeek: _week(avg: 1750)),
        observed: 0,
      ));
      expect(d.outcome, CheckInOutcome.hold);
      expect(d.reasons, [CheckInReason.atCalorieFloor]);
      expect(d.floorKcal, 1700);
      final room = _d(_in(
        target: 1820,
        maintenance: null,
        tier: _tier(thisWeek: _week(avg: 1820), lastWeek: _week(avg: 1820)),
        observed: 0,
      ));
      expect(room.proposedTargetKcal, 1700);
      expect(room.deltaKcal, -120);
    });

    test('the energy-availability floor protects a training athlete', () {
      // 1,700 + 0.5 x 200 = 1,800 is above the 1,700 minimum day.
      final d = _d(_in(
        target: 1850,
        session: 200,
        maintenance: null,
        tier: _tier(thisWeek: _week(avg: 1850), lastWeek: _week(avg: 1850)),
        observed: 0,
      ));
      expect(d.floorKcal, 1800);
      expect(d.reasons, [CheckInReason.atEnergyAvailabilityFloor]);
    });

    test('at the floor the next step is a maintenance week', () {
      final d = _d(_in(
        target: 1750,
        tier: _tier(thisWeek: _week(avg: 1750), lastWeek: _week(avg: 1750)),
        observed: 0,
      ));
      expect(d.outcome, CheckInOutcome.offerMaintenanceWeek);
      expect(d.reasons, [CheckInReason.plateauAtFloor]);
      expect(d.proposedTargetKcal, 2640);
      expect(d.maintenanceWeekDays, 7);
      expect(d.isProposal, isTrue);
    });

    test('a target under the floor is lifted back to it first', () {
      final d = _d(_in(target: 1650, lastChange: _today.plusDays(-1)));
      expect(d.outcome, CheckInOutcome.propose);
      expect(d.reasons,
          [CheckInReason.targetBelowFloor, CheckInReason.atCalorieFloor]);
      expect(d.proposedTargetKcal, 1700);
      final ea = _d(_in(target: 1650, session: 400));
      expect(ea.reasons, [
        CheckInReason.targetBelowFloor,
        CheckInReason.atEnergyAvailabilityFloor,
      ]);
      expect(ea.proposedTargetKcal, 1900);
    });

    test('due safety questions block a cut, not a step up', () {
      final cut = _d(_in(neverScreened: true, observed: 0));
      expect(cut.outcome, CheckInOutcome.hold);
      expect(cut.reasons, [CheckInReason.safetyReaskDue]);
      expect(cut.safetyReaskDue, isTrue);
      final more = _d(_in(neverScreened: true, observed: -0.75));
      expect(more.outcome, CheckInOutcome.propose);
      expect(more.safetyReaskDue, isTrue);
      final old = _d(_in(screened: _today.plusDays(-56), observed: 0));
      expect(old.reasons, [CheckInReason.safetyReaskDue]);
    });
  });

  group('deficit duration', () {
    test('10 weeks of deficit offers an optional maintenance week', () {
      final d = _d(_in(deficitWeeks: 10));
      expect(d.outcome, CheckInOutcome.offerMaintenanceWeek);
      expect(d.reasons, [CheckInReason.deficitDurationReached]);
      expect(d.proposedTargetKcal, 2640);
      expect(d.deltaKcal, 440);
      expect(d.copyKey,
          'fuel.checkIn.offerMaintenanceWeek.deficitDurationReached');
    });

    test('not offered after a decline, in camp, too early, or without room',
        () {
      for (final i in [
        _in(deficitWeeks: 10, declined: true),
        _in(deficitWeeks: 10, camp: true),
        _in(deficitWeeks: 9),
        _in(deficitWeeks: 10, maintenance: null),
        _in(deficitWeeks: 10, maintenance: 2250),
        _in(deficitWeeks: 10, goal: NutritionGoal.maintain, planned: 0),
      ]) {
        expect(_d(i).outcome, isNot(CheckInOutcome.offerMaintenanceWeek));
      }
    });
  });

  test('properties hold for random weeks', () {
    final rng = Random(20261022);
    for (var n = 0; n < 2000; n++) {
      final goal = NutritionGoal.values[rng.nextInt(3)];
      // Targets live on tens (every plan and step is rounded to ten).
      final target = 1500 + 10 * rng.nextInt(200).toDouble();
      final rmr = 1300 + rng.nextInt(500).toDouble();
      final i = _in(
        goal: goal,
        target: target,
        minimum: rmr,
        rmr: rmr,
        session: rng.nextDouble() * 600,
        maximum:
            goal == NutritionGoal.loseFat ? target + rng.nextInt(800) : null,
        maintenance: target + rng.nextInt(800),
        planned: rng.nextDouble(),
        camp: rng.nextBool(),
        observed: rng.nextDouble() * 3 - 1.5,
        previous: rng.nextBool() ? rng.nextDouble() * 3 - 2 : null,
        deficitWeeks: rng.nextInt(14),
        tier: _tier(
          thisWeek: _week(avg: target * (0.85 + rng.nextDouble() * 0.3)),
          lastWeek: _week(avg: target * (0.85 + rng.nextDouble() * 0.3)),
        ),
      );
      final d = _d(i);
      expect(d.reasons, isNotEmpty);
      if (!d.isProposal) {
        expect(d.deltaKcal, 0);
        expect(d.proposedTargetKcal, target.round());
        continue;
      }
      expect(d.proposedTargetKcal % 10, 0);
      if (d.deltaKcal < 0) {
        expect(d.proposedTargetKcal, greaterThanOrEqualTo(d.floorKcal));
        expect(d.deltaKcal, inInclusiveRange(-200, -100));
        expect(d.reasons, isNot(contains(CheckInReason.lossAboveCap)));
        expect(d.safetyReaskDue, isFalse);
      } else if (d.outcome == CheckInOutcome.propose &&
          d.reasons.first != CheckInReason.targetBelowFloor) {
        expect(d.deltaKcal, inInclusiveRange(100, 200));
      }
    }
  });
}
