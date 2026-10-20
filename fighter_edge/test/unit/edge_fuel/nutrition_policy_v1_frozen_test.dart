import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy.dart';

/// Policy v1 outputs, recorded before policy v2 existed. Existing users hold
/// these targets until they accept a v2 proposal, so the v1 engine must keep
/// reproducing them exactly. If one of these fails, v1 was changed: restore
/// it, do not edit the expectation.
class _Frozen {
  const _Frozen(
    this.profile, {
    this.status = NutritionTargetStatus.success,
    this.reasons = const [],
    this.rmr,
    this.low,
    this.high,
    this.kcal,
    this.protein,
    this.fat,
    this.carb,
    this.fiberLow,
    this.fiberHigh,
    this.refKg,
    this.coefficient,
    this.adjustment,
    this.confidence,
  });

  final NutritionProfile profile;
  final NutritionTargetStatus status;
  final List<String> reasons;
  final int? rmr, low, high, kcal, protein, fat, carb, fiberLow, fiberHigh;
  final double? refKg, coefficient, adjustment;
  final ConfidenceLabel? confidence;
}

const _higher = EquationProfile.higherOffset;

const _frozen = <String, _Frozen>{
  'maintainModerate': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.maintain,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      equationProfile: _higher,
      activityLevel: ActivityLevel.moderate,
    ),
    rmr: 1780,
    low: 2403,
    high: 2937,
    kcal: 2670,
    protein: 128,
    fat: 82,
    carb: 355,
    fiberLow: 32,
    fiberHigh: 43,
    refKg: 80.0,
    coefficient: 1.5,
    adjustment: 0.0,
    confidence: ConfidenceLabel.high,
  ),
  'maintainNeutralLight': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.maintain,
      ageYears: 41,
      heightCm: 168,
      currentWeightKg: 66.5,
      equationProfile: EquationProfile.neutral,
      activityLevel: ActivityLevel.light,
    ),
    rmr: 1432,
    low: 1643,
    high: 2223,
    kcal: 1930,
    protein: 106,
    fat: 59,
    carb: 244,
    fiberLow: 23,
    fiberHigh: 31,
    refKg: 66.5,
    coefficient: 1.35,
    adjustment: 0.0,
    confidence: ConfidenceLabel.low,
  ),
  'loseStandardModerate': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      targetWeightKg: 74,
      goalPace: GoalPace.standard,
      equationProfile: _higher,
      activityLevel: ActivityLevel.moderate,
    ),
    rmr: 1780,
    low: 2403,
    high: 2937,
    kcal: 2270,
    protein: 133,
    fat: 69,
    carb: 279,
    fiberLow: 27,
    fiberHigh: 36,
    refKg: 74.0,
    coefficient: 1.5,
    adjustment: 0.149812734082397,
    confidence: ConfidenceLabel.high,
  ),
  'loseGentleLower': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 27,
      heightCm: 165,
      currentWeightKg: 62,
      targetWeightKg: 58,
      goalPace: GoalPace.gentle,
      equationProfile: EquationProfile.lowerOffset,
      activityLevel: ActivityLevel.light,
    ),
    rmr: 1355,
    low: 1647,
    high: 2013,
    kcal: 1650,
    protein: 104,
    fat: 50,
    carb: 196,
    fiberLow: 20,
    fiberHigh: 26,
    refKg: 58.0,
    coefficient: 1.35,
    adjustment: 0.09815737153866655,
    confidence: ConfidenceLabel.high,
  ),
  'loseUpperHigh': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      targetWeightKg: 74,
      goalPace: GoalPace.upperLimit,
      equationProfile: _higher,
      activityLevel: ActivityLevel.high,
    ),
    rmr: 1780,
    low: 2723,
    high: 3329,
    kcal: 2420,
    protein: 133,
    fat: 74,
    carb: 306,
    fiberLow: 29,
    fiberHigh: 39,
    refKg: 74.0,
    coefficient: 1.7,
    adjustment: 0.2002643754130866,
    confidence: ConfidenceLabel.high,
  ),
  'loseVeryHighStandard': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 25,
      heightCm: 175,
      currentWeightKg: 70,
      targetWeightKg: 66,
      goalPace: GoalPace.standard,
      equationProfile: _higher,
      activityLevel: ActivityLevel.veryHigh,
    ),
    rmr: 1674,
    low: 2862,
    high: 3498,
    kcal: 2700,
    protein: 119,
    fat: 83,
    carb: 369,
    fiberLow: 32,
    fiberHigh: 43,
    refKg: 66.0,
    coefficient: 1.9,
    adjustment: 0.15097676978106206,
    confidence: ConfidenceLabel.high,
  ),
  'gainStandard': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.gainMuscle,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      targetWeightKg: 85,
      goalPace: GoalPace.gainStandard,
      equationProfile: _higher,
      activityLevel: ActivityLevel.moderate,
    ),
    rmr: 1780,
    low: 2403,
    high: 2937,
    kcal: 2880,
    protein: 144,
    fat: 88,
    carb: 378,
    fiberLow: 35,
    fiberHigh: 46,
    refKg: 80.0,
    coefficient: 1.5,
    adjustment: 0.07865168539325842,
    confidence: ConfidenceLabel.high,
  ),
  'gainConservativeVeryLow': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.gainMuscle,
      ageYears: 22,
      heightCm: 172,
      currentWeightKg: 64,
      targetWeightKg: 68,
      goalPace: GoalPace.conservative,
      equationProfile: EquationProfile.lowerOffset,
      activityLevel: ActivityLevel.veryLow,
    ),
    rmr: 1444,
    low: 1560,
    high: 1906,
    kcal: 1820,
    protein: 115,
    fat: 56,
    carb: 214,
    fiberLow: 22,
    fiberHigh: 29,
    refKg: 64.0,
    coefficient: 1.2,
    adjustment: 0.05032317636195755,
    confidence: ConfidenceLabel.high,
  ),
  'minor': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.maintain,
      ageYears: 16,
      heightCm: 170,
      currentWeightKg: 60,
      equationProfile: _higher,
      activityLevel: ActivityLevel.moderate,
    ),
    status: NutritionTargetStatus.unsupported,
    reasons: ['underAge'],
  ),
  'pregnant': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.maintain,
      ageYears: 29,
      heightCm: 165,
      currentWeightKg: 62,
      equationProfile: EquationProfile.lowerOffset,
      activityLevel: ActivityLevel.moderate,
      safetyFlags: NutritionSafetyFlags(pregnantOrBreastfeeding: true),
    ),
    status: NutritionTargetStatus.needsProfessionalReview,
    reasons: ['pregnantOrBreastfeeding'],
  ),
  'missingTarget': _Frozen(
    NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 30,
      heightCm: 180,
      currentWeightKg: 80,
      goalPace: GoalPace.standard,
      equationProfile: _higher,
      activityLevel: ActivityLevel.moderate,
    ),
    status: NutritionTargetStatus.needsMoreData,
    reasons: ['missingTargetWeight'],
  ),
};

void main() {
  group('policy v1 outputs are frozen', () {
    for (final entry in _frozen.entries) {
      test(entry.key, () {
        final f = entry.value;
        final t = NutritionTargetCalculator.calculate(
          f.profile,
          now: DateTime.utc(2026, 7, 25),
        );
        expect(t.policyVersion, 1);
        expect(t.status, f.status);
        expect(t.reasons, f.reasons);
        expect(t.estimatedRmrKcal, f.rmr);
        expect(t.maintenanceRangeLowKcal, f.low);
        expect(t.maintenanceRangeHighKcal, f.high);
        expect(t.targetCalories, f.kcal);
        expect(t.proteinGrams, f.protein);
        expect(t.fatGrams, f.fat);
        expect(t.carbGrams, f.carb);
        expect(t.fiberGramsLow, f.fiberLow);
        expect(t.fiberGramsHigh, f.fiberHigh);
        expect(t.proteinReferenceWeightKg, f.refKg);
        expect(t.activityCoefficientUsed, f.coefficient);
        expect(t.appliedGoalAdjustmentPercent, f.adjustment);
        expect(t.confidence, f.confidence);
        expect(t.warnings, isEmpty);
      });
    }
  });

  group('v1 stays reachable next to v2', () {
    test('the constants name both versions', () {
      expect(NutritionPolicy.v1, 1);
      expect(NutritionPolicy.version, 2);
    });

    test('v1 constants did not change', () {
      expect(
          NutritionPolicy.activityCoefficientFor(ActivityLevel.moderate), 1.50);
      expect(NutritionPolicy.proteinGPerKgLoseOrGain, 1.8);
      expect(NutritionPolicy.proteinGPerKgMaintain, 1.6);
      expect(NutritionPolicy.fatLossDeficitDefault, 0.15);
      expect(NutritionPolicy.muscleGainSurplusDefault, 0.08);
      expect(NutritionPolicy.carbPerformanceFloorGPerKg, 3.0);
    });
  });
}
