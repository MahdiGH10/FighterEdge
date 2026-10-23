import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/weight_rate_policy.dart';

final _now = DateTime(2026, 10, 20);

NutritionProfile _profile({
  NutritionGoal goal = NutritionGoal.maintain,
  double weight = 80,
  double height = 180,
  int age = 30,
  double? target,
  GoalPace? pace,
  EquationProfile equation = EquationProfile.higherOffset,
  ActivityLevel activity = ActivityLevel.moderate,
  NutritionSafetyFlags flags = const NutritionSafetyFlags(),
}) =>
    NutritionProfile(
      goal: goal,
      ageYears: age,
      heightCm: height,
      currentWeightKg: weight,
      targetWeightKg: target,
      goalPace: pace,
      equationProfile: equation,
      activityLevel: activity,
      safetyFlags: flags,
    );

PlannedFuelSession _s(
  int day, {
  FuelDiscipline d = FuelDiscipline.boxing,
  FuelIntensity i = FuelIntensity.moderate,
  int minutes = 60,
}) =>
    PlannedFuelSession(
      dayIndex: day,
      discipline: d,
      intensity: i,
      durationMinutes: minutes,
    );

/// Mon, Tue, Thu, Fri, Sat: five sessions of 75 min.
List<PlannedFuelSession> _fiveSessionWeek() => [
      _s(0, minutes: 75),
      _s(1, d: FuelDiscipline.strength, minutes: 60),
      _s(3, d: FuelDiscipline.muayThai, i: FuelIntensity.hard, minutes: 90),
      _s(4, d: FuelDiscipline.conditioning, minutes: 45),
      _s(5, d: FuelDiscipline.mma, i: FuelIntensity.hard, minutes: 75),
    ];

NutritionTargetV2 _calc(
  NutritionProfile p, {
  List<PlannedFuelSession>? week,
  double? rate,
  bool shift = true,
  bool camp = false,
  bool enablePendingEnergyAvailabilityFloor = false,
}) =>
    NutritionTargetCalculatorV2.calculate(
      p,
      plannedWeek: week ?? _fiveSessionWeek(),
      now: _now,
      weeklyRatePercent: rate,
      inFightCamp: camp,
      trainingDayShift: shift,
      enablePendingEnergyAvailabilityFloor:
          enablePendingEnergyAvailabilityFloor,
    );

/// Every invariant the safety rules promise, for any successful result.
void _expectInvariants(NutritionTargetV2 t, NutritionProfile p, String ctx) {
  expect(t.isSuccess, isTrue, reason: ctx);
  expect(t.policyVersion, 2, reason: ctx);
  expect(t.days, hasLength(7), reason: ctx);
  final w = p.currentWeightKg;
  final avg = t.weeklyAverageCalories!;
  final conflict = t.warnings.contains('carbFloorConflictsWithProteinTarget');

  // The week adds up to the target exactly.
  expect(t.weeklyCalories, avg * 7, reason: '$ctx weekly total');

  final rmr = t.estimatedRmrKcal!;
  for (final d in t.days) {
    final tag = '$ctx day ${d.dayIndex}';
    expect(d.calories % 10, 0, reason: tag);
    // Never below RMR (the v1 minimum). RMR is rounded, so allow 1 kcal.
    expect(d.calories, greaterThanOrEqualTo(rmr - 1), reason: '$tag rmr');
    // Protein, fat and carbohydrate floors, every day.
    expect(d.proteinGrams, greaterThanOrEqualTo((1.2 * w).ceil()),
        reason: '$tag protein');
    expect(d.fatGrams, greaterThanOrEqualTo((0.5 * w).ceil()),
        reason: '$tag fat');
    if (!conflict && !t.warnings.contains('carbGramsClampedToZero')) {
      expect(d.carbGrams, greaterThanOrEqualTo((3 * w).floor()),
          reason: '$tag carbs');
    }
    // Macro-derived calories reconcile with the day's calories.
    expect((d.calories - d.macroDerivedCalories).abs(), lessThanOrEqualTo(4),
        reason: '$tag macros');
    // Protein and fat do not move between days.
    expect(d.proteinGrams, t.proteinGrams, reason: tag);
    expect(d.fatGrams, t.fatGrams, reason: tag);
    if (!conflict) {
      expect(d.calories, greaterThanOrEqualTo(t.minimumDailyKcal!),
          reason: '$tag minimum');
    }
  }
  expect(avg, greaterThanOrEqualTo(rmr - 1), reason: '$ctx average vs rmr');

  // Loss never exceeds 1% of body weight or 1 kg a week (small rounding).
  if (p.goal == NutritionGoal.loseFat) {
    final cap = WeightRatePolicy.maxPercentFor(p.goal, w);
    expect(-t.appliedWeeklyChangePercent!, lessThanOrEqualTo(cap + 0.03),
        reason: '$ctx loss cap');
  }
  if (p.goal == NutritionGoal.gainMuscle) {
    expect(t.appliedWeeklyChangePercent!, lessThanOrEqualTo(0.5 + 0.03),
        reason: '$ctx gain cap');
  }
}

void main() {
  group('a worked example (80 kg, 180 cm, 30 y, higher offset, maintain)', () {
    test('no sessions: RMR 1780 x 1.40 = 2492 rounds to 2490', () {
      final t = _calc(_profile(), week: const []);
      expect(t.estimatedRmrKcal, 1780);
      expect(t.nonTrainingFactorUsed, 1.40);
      expect(t.sessionEnergyKcalPerWeek, 0);
      expect(t.maintenanceKcal, 2492);
      expect(t.weeklyAverageCalories, 2490);
      expect(t.proteinGrams, 144); // 1.8 g/kg x 80
      expect(t.fatGrams, 76); // 27.5% of 2490 / 9
      expect(t.warnings, contains('noPlannedSessions'));
      expect(t.trainingDayShiftApplied, isFalse);
      expect(t.days.every((d) => d.calories == 2490), isTrue);
      expect(t.days.every((d) => d.kind == FuelDayKind.rest), isTrue);
    });

    test('one 60-min moderate boxing session lifts that day and the week', () {
      final t = _calc(_profile(), week: [_s(2)]);
      // (7.0 - 1) x 80 x 1 h = 480 kcal.
      expect(t.sessionEnergyKcalPerWeek, 480);
      expect(t.maintenanceKcal, 2561); // 2492 + 480 / 7
      expect(t.weeklyAverageCalories, 2560);
      final training = t.days[2];
      final rest = t.days[0];
      expect(training.calories, greaterThan(rest.calories));
      expect(training.carbGrams, greaterThan(rest.carbGrams));
      expect(training.sessionKcal, 480);
      expect(t.weeklyCalories, 2560 * 7);
      expect(t.trainingDayShiftApplied, isTrue);
      _expectInvariants(t, _profile(), 'one session');
    });
  });

  group('training now changes the target (the audit finding)', () {
    test('five sessions a week give a higher target than none', () {
      final none = _calc(_profile(), week: const []);
      final five = _calc(_profile(), week: _fiveSessionWeek());
      expect(five.weeklyAverageCalories!,
          greaterThan(none.weeklyAverageCalories!));
      expect(five.sessionEnergyKcalPerWeek!, greaterThan(1500));
    });

    test('more training never lowers the maintenance target', () {
      var last = 0;
      for (var n = 0; n <= 7; n++) {
        final week = [for (var d = 0; d < n; d++) _s(d)];
        final t = _calc(_profile(), week: week);
        expect(t.weeklyAverageCalories!, greaterThanOrEqualTo(last));
        last = t.weeklyAverageCalories!;
      }
    });

    test('a longer or harder session raises the target', () {
      int avgFor(PlannedFuelSession s) =>
          _calc(_profile(), week: [s]).weeklyAverageCalories!;
      expect(
          avgFor(_s(1, minutes: 120)), greaterThan(avgFor(_s(1, minutes: 45))));
      expect(avgFor(_s(1, i: FuelIntensity.hard)),
          greaterThan(avgFor(_s(1, i: FuelIntensity.light))));
    });

    test('the day a session falls on does not change the weekly target', () {
      final a = _calc(_profile(), week: [_s(0)]);
      final b = _calc(_profile(), week: [_s(6)]);
      expect(a.weeklyAverageCalories, b.weeklyAverageCalories);
    });

    test('day kinds follow the sessions', () {
      final t = _calc(_profile(), week: [
        _s(0, i: FuelIntensity.light, minutes: 30),
        _s(2, i: FuelIntensity.hard)
      ]);
      expect(t.days[0].kind, FuelDayKind.light);
      expect(t.days[1].kind, FuelDayKind.rest);
      expect(t.days[2].kind, FuelDayKind.hard);
    });

    test('two moderate sessions on one day make a hard day by energy', () {
      final t = _calc(_profile(), week: [
        _s(4, minutes: 90),
        _s(4, d: FuelDiscipline.mma, minutes: 90)
      ]);
      expect(t.days[4].kind, FuelDayKind.hard);
    });
  });

  group('training-day / rest-day shift', () {
    test('protein and fat are constant, carbohydrate carries the shift', () {
      final t = _calc(_profile());
      expect(t.days.map((d) => d.proteinGrams).toSet(), hasLength(1));
      expect(t.days.map((d) => d.fatGrams).toSet(), hasLength(1));
      expect(t.days.map((d) => d.carbGrams).toSet().length, greaterThan(1));
    });

    test('hard days eat more than rest days', () {
      final t = _calc(_profile());
      final hardest =
          t.days.reduce((a, b) => a.sessionKcal >= b.sessionKcal ? a : b);
      final rest = t.days.firstWhere((d) => d.kind == FuelDayKind.rest);
      expect(hardest.calories, greaterThan(rest.calories));
    });

    test('turning the shift off gives a flat week at the same average', () {
      final on = _calc(_profile());
      final off = _calc(_profile(), shift: false);
      expect(off.weeklyAverageCalories, on.weeklyAverageCalories);
      expect(off.days.map((d) => d.calories).toSet(), hasLength(1));
      expect(off.trainingDayShiftApplied, isFalse);
    });

    test('the shift never pushes a rest day under the minimum', () {
      // A lean, losing athlete with one huge day.
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 74, pace: GoalPace.upperLimit);
      final t = _calc(p, week: [
        _s(3, d: FuelDiscipline.mma, i: FuelIntensity.hard, minutes: 240),
      ]);
      _expectInvariants(t, p, 'huge day');
    });
  });

  group('weight change as a percent of body weight per week', () {
    test('standard loss is 0.5% of body weight, near 440 kcal a day', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 70, pace: GoalPace.standard);
      final t = _calc(p);
      // A trained week leaves room above the carbohydrate floor, so the
      // whole 0.5% gap is taken.
      expect(t.maintenanceKcal! - t.weeklyAverageCalories!, closeTo(440, 15));
      expect(t.appliedWeeklyChangePercent, closeTo(-0.5, 0.05));
    });

    test('each loss pace is slower than the next', () {
      int avgFor(GoalPace pace) => _calc(
            _profile(goal: NutritionGoal.loseFat, target: 70, pace: pace),
          ).weeklyAverageCalories!;
      expect(avgFor(GoalPace.gentle), greaterThan(avgFor(GoalPace.standard)));
      expect(
          avgFor(GoalPace.standard), greaterThan(avgFor(GoalPace.upperLimit)));
    });

    test('an explicit camp rate overrides the pace and is clamped to 1%', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 70, pace: GoalPace.gentle);
      final camp = _calc(p, rate: 1.0, camp: true);
      expect(camp.appliedWeeklyChangePercent, closeTo(-1.0, 0.1));
      final tooFast = _calc(p, rate: 4.0, camp: true);
      expect(tooFast.warnings, contains('weightRateAdjusted'));
      expect(tooFast.weeklyAverageCalories, camp.weeklyAverageCalories);
    });

    test('outside a camp the same rate is clamped to 0.75%', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 70, pace: GoalPace.gentle);
      final t = _calc(p, rate: 1.0);
      expect(t.warnings, contains('weightRateAdjusted'));
      expect(t.appliedWeeklyChangePercent, closeTo(-0.75, 0.05));
    });

    test('a hard-training loser is held at the energy-availability floor', () {
      // Light, short athlete training five times a week: resting energy plus
      // half the session energy is above maintenance minus the camp rate.
      final p = _profile(
        goal: NutritionGoal.loseFat,
        weight: 60,
        height: 165,
        age: 25,
        target: 55,
        equation: EquationProfile.lowerOffset,
        activity: ActivityLevel.veryLow,
      );
      final withoutSignOff = _calc(p, rate: 1.0, camp: true);
      expect(withoutSignOff.energyAvailabilityFloorKcal, isNull);
      expect(withoutSignOff.warnings,
          isNot(contains('goalRateReducedForEnergyAvailability')));

      final t = _calc(p,
          rate: 1.0, camp: true, enablePendingEnergyAvailabilityFloor: true);
      expect(t.isSuccess, isTrue);
      final ea = t.energyAvailabilityFloorKcal!;
      expect(ea, greaterThan(t.estimatedRmrKcal!));
      expect(
        ea,
        NutritionPolicyV2.ceilToTen(
          t.estimatedRmrKcal! + 0.5 * t.sessionEnergyKcalPerWeek! / 7,
        ),
      );
      expect(t.weeklyAverageCalories, greaterThanOrEqualTo(ea - 10));
      expect(t.warnings, contains('goalRateReducedForEnergyAvailability'));
    });

    test('a heavy athlete is held to 1 kg a week, below 1%', () {
      final p = _profile(
          goal: NutritionGoal.loseFat,
          weight: 130,
          height: 190,
          target: 120,
          pace: GoalPace.upperLimit);
      final t = _calc(p, rate: 1.0, week: _fiveSessionWeek());
      expect(-t.appliedWeeklyChangePercent!, lessThanOrEqualTo(0.77 + 0.03));
      _expectInvariants(t, p, 'heavy');
    });

    test('muscle gain adds the same way', () {
      final p = _profile(
          goal: NutritionGoal.gainMuscle,
          target: 85,
          pace: GoalPace.gainStandard);
      final t = _calc(p, week: const []);
      // 0.25% of 80 kg = 220 kcal a day.
      expect(t.weeklyAverageCalories! - t.maintenanceKcal!, closeTo(220, 10));
      expect(t.proteinGrams, 144);
      expect(t.proteinReferenceWeightKg, 80);
    });

    test('while losing, protein follows target weight at 2.0 g/kg', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 72, pace: GoalPace.standard);
      final t = _calc(p);
      expect(t.proteinGrams, 144);
      expect(t.proteinReferenceWeightKg, 72);
    });

    test('protein never drops under 1.2 g/kg of current weight', () {
      // Target far below current: 2.0 x 55 = 110 g < 1.2 x 100 = 120 g.
      final p = _profile(
          goal: NutritionGoal.loseFat,
          weight: 100,
          height: 190,
          target: 55,
          pace: GoalPace.gentle);
      final t = _calc(p);
      expect(t.proteinGrams, 120);
    });
  });

  group('floors and conflicts', () {
    test('losing fat lifts the average to protect the carbohydrate floor', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 74, pace: GoalPace.standard);
      final t = _calc(p, week: const []);
      expect(t.warnings, contains('goalRateReducedForCarbFloor'));
      for (final d in t.days) {
        expect(d.carbGrams, greaterThanOrEqualTo(240));
      }
    });

    test('when even maintenance cannot hold the floor, it says so', () {
      final p = _profile(
        goal: NutritionGoal.loseFat,
        weight: 120,
        height: 170,
        age: 50,
        target: 118,
        pace: GoalPace.gentle,
        activity: ActivityLevel.veryLow,
      );
      final t = _calc(p, week: const []);
      expect(t.warnings, contains('carbFloorConflictsWithProteinTarget'));
      expect(
          t.weeklyAverageCalories, lessThanOrEqualTo(t.maintenanceKcal! + 5));
      expect(t.days.map((d) => d.calories).toSet(), hasLength(1));
    });

    test('the target is never below RMR', () {
      // A small, inactive athlete at the upper pace would land under RMR.
      final p = _profile(
        goal: NutritionGoal.loseFat,
        weight: 52,
        height: 160,
        age: 40,
        target: 48,
        pace: GoalPace.upperLimit,
        equation: EquationProfile.lowerOffset,
        activity: ActivityLevel.veryLow,
      );
      final t = _calc(p, week: const []);
      expect(t.isSuccess, isTrue);
      expect(
          t.weeklyAverageCalories!, greaterThanOrEqualTo(t.estimatedRmrKcal!));
      _expectInvariants(t, p, 'small');
    });

    test('minimumDailyKcal is at least RMR and the carbohydrate floor', () {
      final p = _profile(
          goal: NutritionGoal.loseFat, target: 74, pace: GoalPace.standard);
      final t = _calc(p);
      expect(t.minimumDailyKcal!, greaterThanOrEqualTo(t.estimatedRmrKcal!));
      final floorKcal = t.proteinGrams! * 4 + t.fatGrams! * 9 + 3 * 80 * 4;
      expect(t.minimumDailyKcal!, greaterThanOrEqualTo(floorKcal));
    });
  });

  group('safety exclusions are shared with v1', () {
    test('minors get no target', () {
      final t = _calc(_profile(age: 17));
      expect(t.status, NutritionTargetStatus.unsupported);
      expect(t.reasons, contains('underAge'));
      expect(t.days, isEmpty);
      expect(t.weeklyAverageCalories, isNull);
    });

    test('pregnancy / breastfeeding needs professional review', () {
      final t = _calc(_profile(
          flags: const NutritionSafetyFlags(pregnantOrBreastfeeding: true)));
      expect(t.status, NutritionTargetStatus.needsProfessionalReview);
      expect(t.reasons, contains('pregnantOrBreastfeeding'));
      expect(t.weeklyAverageCalories, isNull);
    });

    test('every clinical flag blocks the calculation', () {
      for (final flags in const [
        NutritionSafetyFlags(eatingDisorderHistoryOrSymptoms: true),
        NutritionSafetyFlags(diabetesRequiringMedication: true),
        NutritionSafetyFlags(kidneyDisease: true),
        NutritionSafetyFlags(seriousLiverDisease: true),
        NutritionSafetyFlags(otherClinicianManagedDiet: true),
      ]) {
        final t = _calc(_profile(flags: flags));
        expect(t.status, NutritionTargetStatus.needsProfessionalReview);
      }
    });

    test('invalid fat-loss targets and underweight are refused', () {
      expect(
        _calc(_profile(
                goal: NutritionGoal.loseFat,
                target: 90,
                pace: GoalPace.standard))
            .status,
        NutritionTargetStatus.unsupported,
      );
      expect(
        _calc(_profile(
          goal: NutritionGoal.loseFat,
          weight: 50,
          height: 180,
          target: 48,
          pace: GoalPace.standard,
        )).reasons,
        contains('underweightForFatLoss'),
      );
    });

    test('missing inputs are needsMoreData, not a guess', () {
      final noTarget =
          _calc(_profile(goal: NutritionGoal.loseFat, pace: GoalPace.standard));
      expect(noTarget.status, NutritionTargetStatus.needsMoreData);
      expect(noTarget.reasons, ['missingTargetWeight']);
      final noPace = _calc(_profile(goal: NutritionGoal.loseFat, target: 74));
      expect(noPace.reasons, ['missingGoalPace']);
      // An explicit rate stands in for a pace.
      expect(
        _calc(_profile(goal: NutritionGoal.loseFat, target: 74), rate: 0.5)
            .isSuccess,
        isTrue,
      );
    });

    test('a gain pace on a fat-loss goal does not count as a pace', () {
      final t = _calc(_profile(
          goal: NutritionGoal.loseFat,
          target: 74,
          pace: GoalPace.gainStandard));
      expect(t.status, NutritionTargetStatus.needsMoreData);
    });

    test('invalid vitals are unsupported', () {
      expect(
          _calc(_profile(height: 0)).status, NutritionTargetStatus.unsupported);
    });

    test('an out-of-range RMR is unsupported', () {
      final t = _calc(_profile(
        weight: 10,
        height: 50,
        age: 110,
        equation: EquationProfile.lowerOffset,
      ));
      expect(t.status, NutritionTargetStatus.unsupported);
      expect(t.reasons, ['rmrCalculationOutOfRange']);
    });
  });

  group('inputs and reporting', () {
    test('sessions on impossible days are ignored with a warning', () {
      final good = _calc(_profile(), week: [_s(1)]);
      final withBad = _calc(_profile(), week: [_s(1), _s(9), _s(-1)]);
      expect(withBad.warnings, contains('plannedSessionsIgnored'));
      expect(withBad.weeklyAverageCalories, good.weeklyAverageCalories);
    });

    test('zero-length sessions cost nothing', () {
      final t = _calc(_profile(), week: [_s(1, minutes: 0)]);
      expect(t.sessionEnergyKcalPerWeek, 0);
      expect(t.days[1].kind, FuelDayKind.rest);
    });

    test('the neutral equation path has low confidence and a wider range', () {
      final neutral =
          _calc(_profile(equation: EquationProfile.neutral), week: const []);
      final known = _calc(_profile(), week: const []);
      expect(neutral.confidence, ConfidenceLabel.low);
      final nSpan =
          neutral.maintenanceRangeHighKcal! - neutral.maintenanceRangeLowKcal!;
      final kSpan =
          known.maintenanceRangeHighKcal! - known.maintenanceRangeLowKcal!;
      expect(nSpan, greaterThan(kSpan));
    });

    test('confidence is high only with no warnings on a known equation', () {
      final t = _calc(_profile());
      expect(t.warnings, isEmpty);
      expect(t.confidence, ConfidenceLabel.high);
      expect(
          _calc(_profile(), week: const []).confidence, ConfidenceLabel.medium);
    });

    test('same inputs always give the same result', () {
      final a = _calc(_profile());
      final b = _calc(_profile());
      expect(a.days.map((d) => d.calories), b.days.map((d) => d.calories));
      expect(a.calculatedAt, _now);
    });

    test('toNutritionTarget stamps version 2 and carries the weekly average',
        () {
      final t = _calc(_profile());
      final n = t.toNutritionTarget();
      expect(n.policyVersion, 2);
      expect(n.targetCalories, t.weeklyAverageCalories);
      expect(n.proteinGrams, t.proteinGrams);
      expect(n.fatGrams, t.fatGrams);
      expect(n.carbGrams, t.carbGrams);
      expect(n.isSuccess, isTrue);
      expect((n.targetCalories! - n.macroDerivedCalories!).abs(), lessThan(8));
      expect(n.activityCoefficientUsed, 1.40);
      expect(n.appliedGoalAdjustmentPercent, closeTo(0, 0.01));
    });

    test('toNutritionTarget on a refusal keeps the reasons', () {
      final n = _calc(_profile(age: 16)).toNutritionTarget();
      expect(n.policyVersion, 2);
      expect(n.status, NutritionTargetStatus.unsupported);
      expect(n.reasons, contains('underAge'));
      expect(n.targetCalories, isNull);
    });
  });

  group('v1 is untouched and keeps its own version', () {
    test('v1 still stamps version 1 and ignores training', () {
      final v1 = NutritionTargetCalculator.calculate(_profile(), now: _now);
      expect(v1.policyVersion, 1);
      expect(v1.targetCalories, 2670); // 1780 x 1.50, byte-identical to before
      final v2 = _calc(_profile());
      expect(v2.policyVersion, 2);
      expect(v2.weeklyAverageCalories, isNot(v1.targetCalories));
    });

    test('v1 refusals are stamped version 1 too', () {
      final v1 =
          NutritionTargetCalculator.calculate(_profile(age: 12), now: _now);
      expect(v1.policyVersion, 1);
    });
  });

  group('property checks over many random athletes', () {
    test('every successful week balances and respects every floor', () {
      final rng = Random(5404);
      var successes = 0;
      var shifted = 0;
      for (var n = 0; n < 1500; n++) {
        final goal = NutritionGoal.values[rng.nextInt(3)];
        final weight = 50.0 + rng.nextInt(80);
        final height = 150.0 + rng.nextInt(50);
        final age = 18 + rng.nextInt(45);
        final target = switch (goal) {
          NutritionGoal.loseFat => weight * (0.88 + rng.nextDouble() * 0.1),
          NutritionGoal.gainMuscle => weight * (1.03 + rng.nextDouble() * 0.1),
          NutritionGoal.maintain => null,
        };
        final pace = switch (goal) {
          NutritionGoal.loseFat => GoalPace.values[rng.nextInt(3)],
          NutritionGoal.gainMuscle => GoalPace.values[3 + rng.nextInt(2)],
          NutritionGoal.maintain => null,
        };
        final p = _profile(
          goal: goal,
          weight: weight,
          height: height,
          age: age,
          target: target,
          pace: pace,
          equation: EquationProfile.values[rng.nextInt(3)],
          activity: ActivityLevel.values[rng.nextInt(5)],
        );
        final week = [
          for (var s = 0; s < rng.nextInt(9); s++)
            PlannedFuelSession(
              dayIndex: rng.nextInt(7),
              discipline: FuelDiscipline.values[rng.nextInt(9)],
              intensity: FuelIntensity.values[rng.nextInt(3)],
              durationMinutes: rng.nextInt(200),
            ),
        ];
        final rate = rng.nextBool() ? null : rng.nextDouble() * 2;
        final t = _calc(p, week: week, rate: rate, shift: rng.nextInt(5) != 0);
        if (!t.isSuccess) continue;
        successes++;
        if (t.trainingDayShiftApplied) shifted++;
        _expectInvariants(t, p, 'case $n');
      }
      expect(successes, greaterThan(800));
      expect(shifted, greaterThan(200));
    });

    test('NutritionPolicyV2 constants stay inside the research bands', () {
      expect(NutritionPolicyV2.proteinGPerKgLosing, inInclusiveRange(1.6, 2.2));
      expect(NutritionPolicyV2.proteinGPerKgOther, inInclusiveRange(1.6, 2.2));
      expect(NutritionPolicyV2.proteinFloorGPerKg, 1.2);
      expect(NutritionPolicyV2.fatFloorGPerKg, 0.5);
      expect(NutritionPolicyV2.carbFloorGPerKg, 3.0);
      expect(
          NutritionPolicyV2.fatPercentOfEnergy, inInclusiveRange(0.25, 0.30));
      for (final f in NutritionPolicyV2.nonTrainingFactors.values) {
        expect(f, inInclusiveRange(1.20, 1.55));
      }
      expect(NutritionPolicyV2.roundToTen(2494), 2490);
      expect(NutritionPolicyV2.ceilToTen(2491), 2500);
    });
  });
}
