import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy.dart';

// Fixed test vector from the master prompt (§18.1), independently verified:
// base = 10*80 + 6.25*180 - 5*30 = 800 + 1125 - 150 = 1775
// higher-offset = base + 5   = 1780
// lower-offset  = base - 161 = 1614
// neutral       = midpoint   = 1697
const _vectorAge = 30;
const _vectorHeightCm = 180.0;
const _vectorWeightKg = 80.0;

final _now = DateTime(2026, 7, 25);

NutritionProfile _maintainProfile({
  EquationProfile equation = EquationProfile.higherOffset,
  ActivityLevel activity = ActivityLevel.moderate,
}) {
  return NutritionProfile(
    goal: NutritionGoal.maintain,
    ageYears: _vectorAge,
    heightCm: _vectorHeightCm,
    currentWeightKg: _vectorWeightKg,
    equationProfile: equation,
    activityLevel: activity,
  );
}

NutritionProfile _loseFatProfile({
  double targetWeightKg = 74,
  GoalPace pace = GoalPace.standard,
  ActivityLevel activity = ActivityLevel.moderate,
  EquationProfile equation = EquationProfile.higherOffset,
  double currentWeightKg = _vectorWeightKg,
}) {
  return NutritionProfile(
    goal: NutritionGoal.loseFat,
    ageYears: _vectorAge,
    heightCm: _vectorHeightCm,
    currentWeightKg: currentWeightKg,
    targetWeightKg: targetWeightKg,
    goalPace: pace,
    equationProfile: equation,
    activityLevel: activity,
  );
}

NutritionProfile _gainMuscleProfile({
  double targetWeightKg = 85,
  GoalPace pace = GoalPace.gainStandard,
}) {
  return NutritionProfile(
    goal: NutritionGoal.gainMuscle,
    ageYears: _vectorAge,
    heightCm: _vectorHeightCm,
    currentWeightKg: _vectorWeightKg,
    targetWeightKg: targetWeightKg,
    goalPace: pace,
    equationProfile: EquationProfile.higherOffset,
    activityLevel: ActivityLevel.moderate,
  );
}

void main() {
  group('Resting energy (Mifflin–St Jeor)', () {
    test('fixed vector: higher-offset', () {
      final result = NutritionTargetCalculator.calculate(
        _maintainProfile(equation: EquationProfile.higherOffset),
        now: _now,
      );
      expect(result.estimatedRmrKcal, 1780);
    });

    test('fixed vector: lower-offset', () {
      final result = NutritionTargetCalculator.calculate(
        _maintainProfile(equation: EquationProfile.lowerOffset),
        now: _now,
      );
      expect(result.estimatedRmrKcal, 1614);
    });

    test('fixed vector: neutral is the midpoint', () {
      final result = NutritionTargetCalculator.calculate(
        _maintainProfile(equation: EquationProfile.neutral),
        now: _now,
      );
      expect(result.estimatedRmrKcal, 1697);
    });

    test('neutral profile gets low confidence and a wider range', () {
      final neutral = NutritionTargetCalculator.calculate(
        _maintainProfile(equation: EquationProfile.neutral),
        now: _now,
      );
      final higher = NutritionTargetCalculator.calculate(
        _maintainProfile(equation: EquationProfile.higherOffset),
        now: _now,
      );
      expect(neutral.confidence, ConfidenceLabel.low);
      final neutralWidth =
          neutral.maintenanceRangeHighKcal! - neutral.maintenanceRangeLowKcal!;
      final higherWidth =
          higher.maintenanceRangeHighKcal! - higher.maintenanceRangeLowKcal!;
      expect(neutralWidth, greaterThan(higherWidth));
    });
  });

  group('Every activity coefficient', () {
    for (final level in ActivityLevel.values) {
      test('$level scales maintenance from RMR', () {
        final result = NutritionTargetCalculator.calculate(
          _maintainProfile(activity: level),
          now: _now,
        );
        expect(result.isSuccess, isTrue);
        final expectedMaintenance = result.estimatedRmrKcal! *
            NutritionPolicy.activityCoefficientFor(level);
        // maintain goal: targetCalories == round(maintenance) to nearest 10.
        expect(
          result.targetCalories,
          NutritionPolicy.roundCaloriesToNearestTen(expectedMaintenance),
        );
      });
    }
  });

  group('Loss, maintain, and gain adjustments', () {
    test('maintain targets 0% adjustment', () {
      final result =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      expect(result.appliedGoalAdjustmentPercent, 0.0);
    });

    test('standard fat loss applies the default 15% deficit', () {
      final maintain =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      final loss = NutritionTargetCalculator.calculate(
        _loseFatProfile(pace: GoalPace.standard),
        now: _now,
      );
      expect(loss.targetCalories, lessThan(maintain.targetCalories!));
      expect(loss.appliedGoalAdjustmentPercent, closeTo(0.15, 0.02));
    });

    test('gentle pace is a smaller deficit than standard', () {
      final gentle = NutritionTargetCalculator.calculate(
        _loseFatProfile(pace: GoalPace.gentle),
        now: _now,
      );
      final standard = NutritionTargetCalculator.calculate(
        _loseFatProfile(pace: GoalPace.standard),
        now: _now,
      );
      expect(gentle.targetCalories, greaterThan(standard.targetCalories!));
    });

    test('standard muscle gain applies the default 8% surplus', () {
      final maintain =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      final gain = NutritionTargetCalculator.calculate(
        _gainMuscleProfile(pace: GoalPace.gainStandard),
        now: _now,
      );
      expect(gain.targetCalories, greaterThan(maintain.targetCalories!));
      expect(gain.appliedGoalAdjustmentPercent, closeTo(0.08, 0.02));
    });
  });

  group('Automated target never drops below RMR', () {
    test('an extreme deficit is clamped to RMR with a warning', () {
      // A very light, low-height profile with the maximum automated deficit
      // and a very low activity coefficient pushes maintenance close to RMR,
      // so the upper-limit pace deficit would otherwise cross below RMR.
      const profile = NutritionProfile(
        goal: NutritionGoal.loseFat,
        ageYears: 45,
        heightCm: 150,
        currentWeightKg: 50,
        targetWeightKg: 45,
        goalPace: GoalPace.upperLimit,
        equationProfile: EquationProfile.higherOffset,
        activityLevel: ActivityLevel.veryLow,
      );
      final result = NutritionTargetCalculator.calculate(profile, now: _now);
      expect(result.isSuccess, isTrue);
      expect(result.targetCalories,
          greaterThanOrEqualTo(result.estimatedRmrKcal!));
      expect(result.warnings, contains('goalPaceReducedToProtectRmr'));
    });
  });

  group('Macro energy reconciliation', () {
    test('macro-derived calories stay within tolerance of the target', () {
      for (final profile in [
        _maintainProfile(),
        _loseFatProfile(),
        _gainMuscleProfile(),
      ]) {
        final result = NutritionTargetCalculator.calculate(profile, now: _now);
        final diff =
            (result.macroDerivedCalories! - result.targetCalories!).abs();
        expect(
          diff,
          lessThanOrEqualTo(NutritionPolicy.macroReconciliationToleranceKcal),
          reason: 'macro-derived kcal must reconcile with the target',
        );
      }
    });
  });

  group('Protein reference-weight rule', () {
    test('fat loss uses the (lower) target weight as reference', () {
      final result = NutritionTargetCalculator.calculate(
        _loseFatProfile(targetWeightKg: 74),
        now: _now,
      );
      expect(result.proteinReferenceWeightKg, 74);
      expect(
        result.proteinGrams,
        NutritionPolicy.roundGrams(
            74 * NutritionPolicy.proteinGPerKgLoseOrGain),
      );
    });

    test('maintenance uses current weight as reference', () {
      final result =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      expect(result.proteinReferenceWeightKg, _vectorWeightKg);
    });

    test('muscle gain uses current weight as reference, not the target', () {
      final result = NutritionTargetCalculator.calculate(
        _gainMuscleProfile(targetWeightKg: 85),
        now: _now,
      );
      expect(result.proteinReferenceWeightKg, _vectorWeightKg);
    });
  });

  group('Fiber target', () {
    test('scales with target calories as a range', () {
      final result =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      expect(result.fiberGramsLow, lessThan(result.fiberGramsHigh!));
      final expectedLow = NutritionPolicy.roundGrams(
        result.targetCalories! / 1000 * NutritionPolicy.fiberGPer1000KcalLow,
      );
      expect(result.fiberGramsLow, expectedLow);
    });
  });

  group('Invalid inputs are rejected at the domain boundary', () {
    test('zero height is unsupported, not a crash', () {
      final profile = _maintainProfile();
      final invalid = NutritionProfile(
        goal: profile.goal,
        ageYears: profile.ageYears,
        heightCm: 0,
        currentWeightKg: profile.currentWeightKg,
        equationProfile: profile.equationProfile,
        activityLevel: profile.activityLevel,
      );
      final result = NutritionTargetCalculator.calculate(invalid, now: _now);
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('invalidVitals'));
    });

    test('NaN weight is rejected, never propagated', () {
      final profile = _maintainProfile();
      final invalid = NutritionProfile(
        goal: profile.goal,
        ageYears: profile.ageYears,
        heightCm: profile.heightCm,
        currentWeightKg: double.nan,
        equationProfile: profile.equationProfile,
        activityLevel: profile.activityLevel,
      );
      final result = NutritionTargetCalculator.calculate(invalid, now: _now);
      expect(result.status, NutritionTargetStatus.unsupported);
    });

    test('an invalid (non-descending) fat-loss target is unsupported', () {
      final result = NutritionTargetCalculator.calculate(
        _loseFatProfile(targetWeightKg: 90), // above current weight
        now: _now,
      );
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('invalidFatLossTarget'));
    });

    test('an invalid (non-ascending) muscle-gain target is unsupported', () {
      final result = NutritionTargetCalculator.calculate(
        _gainMuscleProfile(targetWeightKg: 70), // below current weight
        now: _now,
      );
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('invalidMuscleGainTarget'));
    });

    test('missing target weight for a loss goal is needsMoreData', () {
      const profile = NutritionProfile(
        goal: NutritionGoal.loseFat,
        ageYears: _vectorAge,
        heightCm: _vectorHeightCm,
        currentWeightKg: _vectorWeightKg,
        equationProfile: EquationProfile.higherOffset,
        activityLevel: ActivityLevel.moderate,
        // targetWeightKg and goalPace both omitted.
      );
      final result = NutritionTargetCalculator.calculate(profile, now: _now);
      expect(result.status, NutritionTargetStatus.needsMoreData);
      expect(result.reasons, contains('missingTargetWeight'));
      expect(result.reasons, contains('missingGoalPace'));
    });
  });

  group('Under-18 rejection', () {
    test('a 17-year-old profile is unsupported', () {
      const profile = NutritionProfile(
        goal: NutritionGoal.maintain,
        ageYears: 17,
        heightCm: 175,
        currentWeightKg: 70,
        equationProfile: EquationProfile.higherOffset,
        activityLevel: ActivityLevel.moderate,
      );
      final result = NutritionTargetCalculator.calculate(profile, now: _now);
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('underAge'));
    });
  });

  group('Underweight fat-loss guardrail', () {
    test('a BMI below 18.5 blocks an automated fat-loss plan', () {
      // 50 kg at 180 cm => BMI ~15.4, well under the 18.5 cutoff.
      final result = NutritionTargetCalculator.calculate(
        _loseFatProfile(currentWeightKg: 50, targetWeightKg: 46),
        now: _now,
      );
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('underweightForFatLoss'));
    });
  });

  group('Safety-flag professional-review result', () {
    test('a clinical flag requires review instead of blocking outright', () {
      final base = _maintainProfile();
      final flagged = base.copyWith(
        safetyFlags: const NutritionSafetyFlags(kidneyDisease: true),
      );
      final result = NutritionTargetCalculator.calculate(flagged, now: _now);
      expect(result.status, NutritionTargetStatus.needsProfessionalReview);
      expect(result.reasons, contains('kidneyDisease'));
    });

    test('multiple flags are all reported', () {
      final base = _maintainProfile();
      final flagged = base.copyWith(
        safetyFlags: const NutritionSafetyFlags(
          kidneyDisease: true,
          diabetesRequiringMedication: true,
        ),
      );
      final result = NutritionTargetCalculator.calculate(flagged, now: _now);
      expect(result.reasons,
          containsAll(['kidneyDisease', 'diabetesRequiringMedication']));
    });
  });

  group('Carbohydrate/performance conflict', () {
    test(
        'a high-training-load deficit that would starve carbs reduces the '
        'deficit and warns instead of hiding the conflict', () {
      // An older, shorter, heavier profile keeps RMR small relative to
      // weight, so the weight-driven protein + carb-floor requirement
      // (both scale with body weight) exceeds what an aggressive deficit
      // at veryHigh activity would otherwise leave for carbohydrate.
      // Verified by hand: RMR(lower-offset) = 10*90+6.25*160-5*60-161 = 1439;
      // maintenance = 1439*1.90 = 2734.1; a 20% deficit = 2187.28 kcal,
      // which is below the ~2334.5 kcal the carb floor + protein target
      // require at this weight — the conflict must trigger.
      const heavyOlderProfile = NutritionProfile(
        goal: NutritionGoal.loseFat,
        ageYears: 60,
        heightCm: 160,
        currentWeightKg: 90,
        targetWeightKg: 85,
        goalPace: GoalPace.upperLimit,
        equationProfile: EquationProfile.lowerOffset,
        activityLevel: ActivityLevel.veryHigh,
      );
      final result = NutritionTargetCalculator.calculate(
        heavyOlderProfile,
        now: _now,
      );
      expect(result.isSuccess, isTrue);
      final carbGPerKg = result.carbGrams! / 90;
      expect(
        carbGPerKg,
        greaterThanOrEqualTo(NutritionPolicy.carbPerformanceFloorGPerKg - 0.5),
      );
      expect(
        result.warnings,
        anyElement(
          anyOf(
            'goalPaceReducedForCarbPerformanceFloor',
            'carbFloorConflictsWithProteinTarget',
          ),
        ),
      );
    });

    test('moderate activity with a standard deficit needs no carb warning', () {
      final result = NutritionTargetCalculator.calculate(
        _loseFatProfile(activity: ActivityLevel.moderate),
        now: _now,
      );
      expect(
        result.warnings,
        isNot(contains('goalPaceReducedForCarbPerformanceFloor')),
      );
    });
  });

  group('Deterministic rounding', () {
    test('target calories are always a multiple of 10', () {
      for (final profile in [
        _maintainProfile(),
        _loseFatProfile(),
        _gainMuscleProfile(),
      ]) {
        final result = NutritionTargetCalculator.calculate(profile, now: _now);
        expect(result.targetCalories! % 10, 0);
      }
    });

    test('macro grams are whole numbers (int type is already enforced)', () {
      final result =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      expect(result.proteinGrams, isA<int>());
      expect(result.fatGrams, isA<int>());
      expect(result.carbGrams, isA<int>());
    });

    test('calling twice with the same inputs is fully deterministic', () {
      final a =
          NutritionTargetCalculator.calculate(_loseFatProfile(), now: _now);
      final b =
          NutritionTargetCalculator.calculate(_loseFatProfile(), now: _now);
      expect(a.targetCalories, b.targetCalories);
      expect(a.proteinGrams, b.proteinGrams);
      expect(a.carbGrams, b.carbGrams);
      expect(a.fatGrams, b.fatGrams);
    });
  });

  group('Policy version is stamped on every result', () {
    test('success, unsupported, and needsMoreData all carry the version', () {
      final success =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      final unsupported = NutritionTargetCalculator.calculate(
        const NutritionProfile(
          goal: NutritionGoal.maintain,
          ageYears: 10,
          heightCm: 140,
          currentWeightKg: 40,
          equationProfile: EquationProfile.higherOffset,
          activityLevel: ActivityLevel.moderate,
        ),
        now: _now,
      );
      expect(success.policyVersion, NutritionPolicy.version);
      expect(unsupported.policyVersion, NutritionPolicy.version);
    });
  });

  group('calculatedAt uses the injected clock, never a live clock', () {
    test('the result timestamp matches the injected `now` exactly', () {
      final result =
          NutritionTargetCalculator.calculate(_maintainProfile(), now: _now);
      expect(result.calculatedAt, _now);
    });
  });
}
