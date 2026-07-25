import '../models/nutrition_enums.dart';
import '../models/nutrition_profile.dart';
import '../models/nutrition_target.dart';
import '../policies/nutrition_policy.dart';
import '../policies/nutrition_safety_policy.dart';

/// Pure-Dart deterministic nutrition target engine (master prompt §7). No
/// Flutter, Firebase, clock, or network dependency — the caller injects
/// `now` so results are reproducible in tests. This is the ONLY place a
/// calorie or macro target may be produced; an AI gateway (later sprint)
/// may explain this output but must never recompute or override it
/// (master prompt §4.1–§4.2).
class NutritionTargetCalculator {
  const NutritionTargetCalculator._();

  static NutritionTarget calculate(
    NutritionProfile profile, {
    required DateTime now,
  }) {
    // 1. Missing-data pre-check — distinct from "unsupported": we simply
    // don't have enough information yet, not "this profile can never work."
    if (profile.goal != NutritionGoal.maintain) {
      final missing = <String>[
        if (profile.targetWeightKg == null) 'missingTargetWeight',
        if (profile.goalPace == null) 'missingGoalPace',
      ];
      if (missing.isNotEmpty) {
        return NutritionTarget(
          status: NutritionTargetStatus.needsMoreData,
          policyVersion: NutritionPolicy.version,
          calculatedAt: now,
          reasons: missing,
        );
      }
    }

    // 2. Safety gate — age, vitals, loss/gain target validity, clinical
    // flags. Never proceed to calculation if this doesn't return allowed.
    final safety = NutritionSafetyPolicy.evaluate(profile);
    if (!safety.isAllowed) {
      return NutritionTarget(
        status: safety.status,
        policyVersion: NutritionPolicy.version,
        calculatedAt: now,
        reasons: safety.reasons,
      );
    }

    // 3. Resting energy (Mifflin–St Jeor, §7.2).
    final base = 10 * profile.currentWeightKg +
        6.25 * profile.heightCm -
        5 * profile.ageYears;
    final higherOffset = base + 5;
    final lowerOffset = base - 161;
    final rmr = switch (profile.equationProfile) {
      EquationProfile.higherOffset => higherOffset,
      EquationProfile.lowerOffset => lowerOffset,
      EquationProfile.neutral => (higherOffset + lowerOffset) / 2,
    };
    if (rmr.isNaN || rmr.isInfinite || rmr <= 0) {
      return NutritionTarget(
        status: NutritionTargetStatus.unsupported,
        policyVersion: NutritionPolicy.version,
        calculatedAt: now,
        reasons: const ['rmrCalculationOutOfRange'],
      );
    }
    final estimatedRmrKcal = rmr.round();

    // 4. Maintenance range (§7.3). Neutral equation profile (the "prefer
    // not to answer" path) gets a wider range and lower confidence — never
    // false precision.
    final coefficient =
        NutritionPolicy.activityCoefficientFor(profile.activityLevel);
    final maintenanceKcal = rmr * coefficient;
    final isNeutralProfile = profile.equationProfile == EquationProfile.neutral;
    final rangeFraction = isNeutralProfile
        ? NutritionPolicy.maintenanceRangeFraction * 1.5
        : NutritionPolicy.maintenanceRangeFraction;
    final maintenanceLow = (maintenanceKcal * (1 - rangeFraction)).round();
    final maintenanceHigh = (maintenanceKcal * (1 + rangeFraction)).round();

    // 5. Goal adjustment (§7.4).
    final fraction = NutritionPolicy.adjustmentFractionFor(
      profile.goalPace,
      profile.goal,
    );
    double rawTarget = switch (profile.goal) {
      NutritionGoal.loseFat => maintenanceKcal * (1 - fraction),
      NutritionGoal.gainMuscle => maintenanceKcal * (1 + fraction),
      NutritionGoal.maintain => maintenanceKcal,
    };

    final warnings = <String>[];

    // 6. Protein reference weight + grams (§7.5). Only "losing" uses the
    // lower of current/target weight; safety gate already guarantees
    // target < current for a valid loseFat profile.
    final referenceWeightKg = profile.goal == NutritionGoal.loseFat
        ? profile.targetWeightKg!
        : profile.currentWeightKg;
    final proteinGPerKg = NutritionPolicy.proteinGPerKgFor(profile.goal);
    final proteinGrams =
        NutritionPolicy.roundGrams(referenceWeightKg * proteinGPerKg);
    final proteinKcal = proteinGrams * 4;

    // 7. Never let the automated target fall below RMR (§7.4). Only a
    // deficit (loseFat) can trigger this — gain/maintain are always >= RMR
    // because every activity coefficient is >= 1.0.
    if (profile.goal == NutritionGoal.loseFat && rawTarget < rmr) {
      rawTarget = rmr;
      warnings.add('goalPaceReducedToProtectRmr');
    }

    // 8. Fat + carbohydrate, with a closed-form carb-performance-floor
    // correction for a fat-loss deficit under high/very-high training load
    // (§7.5: "reduce the deficit ... rather than hiding the conflict").
    const fatPercent = NutritionPolicy.fatPercentOfEnergyDefault;
    final carbFloorApplies = profile.goal == NutritionGoal.loseFat &&
        (profile.activityLevel == ActivityLevel.high ||
            profile.activityLevel == ActivityLevel.veryHigh);
    if (carbFloorApplies) {
      final floorKcal = NutritionPolicy.carbPerformanceFloorGPerKg *
          profile.currentWeightKg *
          4;
      final minTargetForCarb = (floorKcal + proteinKcal) / (1 - fatPercent);
      if (rawTarget < minTargetForCarb) {
        if (minTargetForCarb <= maintenanceKcal) {
          rawTarget = minTargetForCarb;
          warnings.add('goalPaceReducedForCarbPerformanceFloor');
        } else {
          // Even maintenance-level calories can't satisfy the carb floor
          // alongside this protein target. Don't push a "loss" goal above
          // maintenance to fix it — flag the conflict instead.
          rawTarget = maintenanceKcal;
          warnings.add('carbFloorConflictsWithProteinTarget');
        }
      }
    }

    final targetCalories = NutritionPolicy.roundCaloriesToNearestTen(rawTarget);
    final fatGrams =
        NutritionPolicy.roundGrams(targetCalories * fatPercent / 9);
    var carbGrams = NutritionPolicy.roundGrams(
      (targetCalories - proteinKcal - fatGrams * 9) / 4,
    );
    if (carbGrams < 0) {
      carbGrams = 0;
      warnings.add('carbGramsClampedToZero');
    }

    // 9. Macro-derived-calorie reconciliation invariant (§7.6): nudge carbs
    // deterministically rather than silently drifting outside tolerance.
    final macroKcal = proteinGrams * 4 + carbGrams * 4 + fatGrams * 9;
    final kcalDiff = targetCalories - macroKcal;
    if (kcalDiff.abs() > NutritionPolicy.macroReconciliationToleranceKcal) {
      carbGrams = (carbGrams + (kcalDiff / 4).round()).clamp(0, 1 << 30);
    }

    // 10. Fiber range (§7.5).
    final fiberLow = NutritionPolicy.roundGrams(
      targetCalories / 1000 * NutritionPolicy.fiberGPer1000KcalLow,
    );
    final fiberHigh = NutritionPolicy.roundGrams(
      targetCalories / 1000 * NutritionPolicy.fiberGPer1000KcalHigh,
    );

    // 11. Applied adjustment (may differ from requested pace if step 7/8
    // reduced it) and confidence label.
    final appliedGoalAdjustmentPercent = switch (profile.goal) {
      NutritionGoal.loseFat =>
        (maintenanceKcal - targetCalories) / maintenanceKcal,
      NutritionGoal.gainMuscle =>
        (targetCalories - maintenanceKcal) / maintenanceKcal,
      NutritionGoal.maintain => 0.0,
    };
    final confidence = isNeutralProfile
        ? ConfidenceLabel.low
        : (warnings.isNotEmpty ? ConfidenceLabel.medium : ConfidenceLabel.high);

    return NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: NutritionPolicy.version,
      calculatedAt: now,
      warnings: warnings,
      estimatedRmrKcal: estimatedRmrKcal,
      maintenanceRangeLowKcal: maintenanceLow,
      maintenanceRangeHighKcal: maintenanceHigh,
      targetCalories: targetCalories,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbGrams: carbGrams,
      fiberGramsLow: fiberLow,
      fiberGramsHigh: fiberHigh,
      proteinReferenceWeightKg: referenceWeightKg,
      equationProfileUsed: profile.equationProfile,
      activityCoefficientUsed: coefficient,
      appliedGoalAdjustmentPercent: appliedGoalAdjustmentPercent,
      confidence: confidence,
    );
  }
}
