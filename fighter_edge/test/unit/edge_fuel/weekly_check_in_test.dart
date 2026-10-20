import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';

/// 80 kg athlete, target 2,400, floor 1,900, eating to plan, 6 days logged,
/// 5 weigh-ins. Override what a case is about.
WeeklyCheckInInput _in({
  NutritionGoal goal = NutritionGoal.loseFat,
  double target = 2400,
  double minimum = 1900,
  double? maximum,
  double weight = 80,
  double planned = 0.5,
  int days = 6,
  double? intake = 2400,
  double? change = -0.4,
  int weighIns = 5,
  bool fightWeek = false,
  bool recent = false,
}) =>
    WeeklyCheckInInput(
      goal: goal,
      currentTargetKcal: target,
      minimumKcal: minimum,
      maximumKcal: maximum,
      currentWeightKg: weight,
      plannedWeeklyChangePercent: planned,
      daysLogged: days,
      averageIntakeKcal: intake,
      weeklyWeightChangeKg: change,
      weighInsThisWeek: weighIns,
      inFightWeek: fightWeek,
      targetChangedInLast7Days: recent,
    );

WeeklyCheckInDecision _d(WeeklyCheckInInput i) => WeeklyCheckIn.decide(i);

void main() {
  group('hold', () {
    test('on pace: a 0.5% loss target and 0.4 kg lost holds', () {
      final d = _d(_in());
      expect(d.action, CheckInAction.hold);
      expect(d.proposedDeltaKcal, 0);
      expect(d.proposedTargetKcal, 2400);
      expect(d.reasons, [CheckInReason.onPace]);
      expect(d.observedChangePercent, closeTo(-0.5, 1e-9));
      expect(d.isProposal, isFalse);
    });

    test('faster than planned but under +50% still holds', () {
      // -0.6 kg = -0.75% of 80 kg: exactly 150% of 0.5%.
      expect(_d(_in(change: -0.55)).action, CheckInAction.hold);
    });

    test('fight week always holds', () {
      final d = _d(_in(fightWeek: true, change: 0.5));
      expect(d.action, CheckInAction.hold);
      expect(d.reasons, [CheckInReason.fightWeek]);
    });

    test('one step a week: a recent change holds', () {
      final d = _d(_in(recent: true, change: 0.5));
      expect(d.reasons, [CheckInReason.recentChange]);
    });

    test('too few days logged holds', () {
      for (var days = 0; days < WeeklyCheckIn.minDaysLogged; days++) {
        final d =
            _d(_in(days: days, intake: days == 0 ? null : 2400, change: 0.3));
        expect(d.action, CheckInAction.hold, reason: 'days $days');
        expect(d.reasons, contains(CheckInReason.insufficientLogging));
      }
    });

    test('too few weigh-ins or no trend holds', () {
      expect(_d(_in(weighIns: 2, change: 0.3)).reasons,
          [CheckInReason.insufficientWeighIns]);
      expect(
          _d(_in(change: null)).reasons, [CheckInReason.insufficientWeighIns]);
    });

    test('both gaps are reported together', () {
      final d = _d(_in(days: 2, intake: 2400, weighIns: 1));
      expect(d.reasons, [
        CheckInReason.insufficientLogging,
        CheckInReason.insufficientWeighIns,
      ]);
    });

    test('not eating to the plan holds: the plan has not been tested', () {
      expect(_d(_in(intake: 2800, change: 0.3)).reasons,
          [CheckInReason.intakeOffTarget]);
      expect(_d(_in(intake: 2000, change: 0.3)).reasons,
          [CheckInReason.intakeOffTarget]);
      // Just inside the 10% band is eating to plan.
      expect(
          _d(_in(intake: 2160, change: -0.1)).action, CheckInAction.decrease);
    });

    test('an implausible weekly change is ignored', () {
      // 2 kg in a week is 2.5% of 80 kg.
      final d = _d(_in(change: -2.0));
      expect(d.action, CheckInAction.hold);
      expect(d.reasons, [CheckInReason.implausibleWeightChange]);
      expect(d.observedChangePercent, closeTo(-2.5, 1e-9));
    });

    test('bad inputs hold with invalidInput, never throw', () {
      final bad = <WeeklyCheckInInput>[
        _in(target: 0),
        _in(target: double.nan),
        _in(minimum: -1),
        _in(weight: 0),
        _in(planned: -0.5),
        _in(planned: double.infinity),
        _in(days: 8),
        _in(days: -1),
        _in(weighIns: -1),
        _in(intake: -5),
        _in(intake: double.nan),
        _in(intake: null),
        _in(change: double.infinity),
        _in(maximum: double.nan),
      ];
      for (final input in bad) {
        final d = _d(input);
        expect(d.action, CheckInAction.hold);
        expect(d.reasons, [CheckInReason.invalidInput]);
        expect(d.proposedDeltaKcal, 0);
      }
    });
  });

  group('fat loss proposals', () {
    test('slower than planned while eating to plan: eat less', () {
      // -0.1 kg = -0.125%, planned -0.5%: 0.375 above, beyond 2x tolerance.
      final d = _d(_in(change: -0.1));
      expect(d.action, CheckInAction.decrease);
      expect(d.proposedDeltaKcal, -150);
      expect(d.proposedTargetKcal, 2250);
      expect(d.reasons, [CheckInReason.slowerThanPlanned]);
      expect(d.isProposal, isTrue);
    });

    test('a smaller miss gets the smaller step', () {
      // -0.25 kg = -0.3125%: 0.1875 above plan, 1.25x tolerance.
      final d = _d(_in(change: -0.25));
      expect(d.action, CheckInAction.decrease);
      expect(d.proposedDeltaKcal, -100);
    });

    test('gaining weight on a fat-loss plan asks for the larger step', () {
      final d = _d(_in(change: 0.4));
      expect(d.proposedDeltaKcal, -150);
    });

    test('faster than planned (+50%) while eating to plan: eat more', () {
      // -1.0 kg = -1.25%: well over 150% of 0.5%.
      final d = _d(_in(change: -1.0, maximum: 2800));
      expect(d.action, CheckInAction.increase);
      expect(d.proposedDeltaKcal, 150);
      expect(d.proposedTargetKcal, 2550);
      expect(d.reasons, [CheckInReason.fasterThanPlanned]);
    });

    test('a decrease is stopped at the floor', () {
      final d = _d(_in(target: 1960, minimum: 1900, intake: 1960, change: 0.3));
      // Only 60 kcal of room: smaller than a step, so hold.
      expect(d.action, CheckInAction.hold);
      expect(d.reasons, [CheckInReason.atCalorieFloor]);
      expect(d.proposedTargetKcal, 1960);
    });

    test('a decrease uses the room left when it is a full step or more', () {
      final d = _d(_in(target: 2020, minimum: 1900, intake: 2020, change: 0.3));
      expect(d.action, CheckInAction.decrease);
      expect(d.proposedTargetKcal, 1900);
      expect(d.proposedDeltaKcal, -120);
    });

    test('an increase is stopped at the ceiling', () {
      final held = _d(_in(change: -1.0, maximum: 2450));
      expect(held.action, CheckInAction.hold);
      expect(held.reasons, [CheckInReason.atCalorieCeiling]);
      final partial = _d(_in(change: -1.0, maximum: 2520));
      expect(partial.action, CheckInAction.increase);
      expect(partial.proposedTargetKcal, 2520);
    });
  });

  group('muscle gain mirrors fat loss', () {
    WeeklyCheckInInput gain({double change = 0.2, double? maximum}) => _in(
          goal: NutritionGoal.gainMuscle,
          planned: 0.25,
          change: change,
          maximum: maximum,
        );

    test('on pace holds', () {
      expect(_d(gain()).action, CheckInAction.hold);
    });

    test('slower than planned: eat more', () {
      final d = _d(gain(change: -0.1));
      expect(d.action, CheckInAction.increase);
      expect(d.reasons, [CheckInReason.slowerThanPlanned]);
      expect(d.proposedDeltaKcal, greaterThanOrEqualTo(100));
    });

    test('faster than planned: eat less', () {
      final d = _d(gain(change: 0.6));
      expect(d.action, CheckInAction.decrease);
      expect(d.reasons, [CheckInReason.fasterThanPlanned]);
      expect(d.proposedDeltaKcal, lessThanOrEqualTo(-100));
    });
  });

  group('maintenance', () {
    WeeklyCheckInInput keep(double change) => _in(
          goal: NutritionGoal.maintain,
          planned: 0,
          change: change,
        );

    test('a steady trend holds', () {
      expect(_d(keep(0.05)).action, CheckInAction.hold);
      expect(_d(keep(-0.1)).action, CheckInAction.hold);
    });

    test('drifting up: eat less', () {
      final d = _d(keep(0.4));
      expect(d.action, CheckInAction.decrease);
      expect(d.reasons, [CheckInReason.maintenanceDriftUp]);
    });

    test('drifting down: eat more', () {
      final d = _d(keep(-0.4));
      expect(d.action, CheckInAction.increase);
      expect(d.reasons, [CheckInReason.maintenanceDriftDown]);
    });
  });

  group('properties', () {
    test('a proposal is always 100-150 kcal, in range, and on a ten', () {
      final rng = Random(13);
      var proposals = 0;
      for (var n = 0; n < 4000; n++) {
        final goal = NutritionGoal.values[rng.nextInt(3)];
        final minimum = 1500.0 + rng.nextInt(600);
        final target = minimum + rng.nextInt(1500);
        final maximum = rng.nextBool() ? target + rng.nextInt(800) : null;
        final weight = 55.0 + rng.nextInt(60);
        final input = _in(
          goal: goal,
          target: target,
          minimum: minimum,
          maximum: maximum,
          weight: weight,
          planned: goal == NutritionGoal.maintain
              ? 0
              : (goal == NutritionGoal.loseFat ? 0.25 : 0.1) +
                  rng.nextInt(3) * 0.25,
          days: rng.nextInt(8),
          intake: target * (0.85 + rng.nextDouble() * 0.3),
          change: (rng.nextDouble() - 0.5) * 3,
          weighIns: rng.nextInt(8),
        );
        final d = _d(input);
        if (!d.isProposal) {
          expect(d.proposedDeltaKcal, 0);
          expect(d.proposedTargetKcal, target.round());
          continue;
        }
        proposals++;
        expect(d.proposedDeltaKcal.abs(), inInclusiveRange(100, 150));
        expect(d.proposedTargetKcal % 10, 0);
        expect(d.proposedTargetKcal, greaterThanOrEqualTo(minimum.round()));
        if (maximum != null && d.action == CheckInAction.increase) {
          expect(d.proposedTargetKcal, lessThanOrEqualTo(maximum));
        }
        expect(d.action == CheckInAction.decrease, d.proposedDeltaKcal < 0);
        // Only ever proposed on a week that was logged and weighed.
        expect(input.daysLogged,
            greaterThanOrEqualTo(WeeklyCheckIn.minDaysLogged));
        expect(input.weighInsThisWeek,
            greaterThanOrEqualTo(WeeklyCheckIn.minWeighIns));
      }
      expect(proposals, greaterThan(200));
    });

    test('the decision never moves the wrong way for a fat-loss goal', () {
      final rng = Random(21);
      for (var n = 0; n < 2000; n++) {
        final change = (rng.nextDouble() - 0.5) * 2.4;
        final d = _d(_in(change: change));
        if (change > -0.4 && d.isProposal) {
          expect(d.action, CheckInAction.decrease, reason: '$change');
        }
        if (change < -0.4 && d.isProposal) {
          expect(d.action, CheckInAction.increase, reason: '$change');
        }
      }
    });
  });
}
