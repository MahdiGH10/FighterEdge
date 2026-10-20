import '../models/nutrition_enums.dart';
import '../models/nutrition_profile.dart';
import '../models/nutrition_target_v2.dart';
import '../models/planned_fuel_session.dart';
import '../policies/nutrition_policy.dart';
import '../policies/nutrition_policy_v2.dart';
import '../policies/nutrition_safety_policy.dart';
import '../policies/session_energy_table.dart';
import '../policies/weight_rate_policy.dart';

/// Pure-Dart training-aware nutrition engine (policy version 2).
///
/// ```text
/// RMR            = Mifflin-St Jeor (same as v1)
/// Base           = RMR x non-training factor (1.20-1.55)
/// Session energy = sum over planned sessions of (MET - 1) x kg x hours
/// Maintenance    = Base + Session energy / 7
/// Weekly average = Maintenance -/+ (rate % of body weight x 7,700 kcal/kg / 7)
/// Day i          = average + shift x (session energy i - weekly mean)
/// ```
///
/// The day split only moves energy between days. Protein and fat grams are
/// constant, so carbohydrate carries the difference, and the seven days always
/// sum to seven times the weekly average.
///
/// Safety is shared with v1: the same [NutritionSafetyPolicy] gate (adults
/// only, clinical flags, valid targets) runs first, and no day is ever set
/// below RMR or below the protein, fat and carbohydrate floors.
///
/// v1 ([NutritionTargetCalculator]) is untouched. A v2 result is a proposal
/// until the user accepts it; callers must keep storing the v1 target until
/// then. No Flutter, Firebase, clock or network dependency: the caller injects
/// `now`.
class NutritionTargetCalculatorV2 {
  const NutritionTargetCalculatorV2._();

  /// [plannedWeek] is the week Fuel is sizing for, as simple pure inputs.
  /// [weeklyRatePercent] overrides the rate implied by `profile.goalPace`
  /// (a fight-camp path supplies it); it is clamped to the safe range either
  /// way. [trainingDayShift] turns the carbohydrate shift off.
  static NutritionTargetV2 calculate(
    NutritionProfile profile, {
    required List<PlannedFuelSession> plannedWeek,
    required DateTime now,
    double? weeklyRatePercent,
    bool trainingDayShift = true,
  }) {
    // 1. Missing data.
    if (profile.goal != NutritionGoal.maintain) {
      final hasRate = weeklyRatePercent != null ||
          WeightRatePolicy.percentForPace(profile.goalPace, profile.goal) !=
              null;
      final missing = <String>[
        if (profile.targetWeightKg == null) 'missingTargetWeight',
        if (!hasRate) 'missingGoalPace',
      ];
      if (missing.isNotEmpty) {
        return NutritionTargetV2(
          status: NutritionTargetStatus.needsMoreData,
          calculatedAt: now,
          reasons: missing,
        );
      }
    }

    // 2. The shared safety gate. Never calculate past a refusal.
    final safety = NutritionSafetyPolicy.evaluate(profile);
    if (!safety.isAllowed) {
      return NutritionTargetV2(
        status: safety.status,
        calculatedAt: now,
        reasons: safety.reasons,
      );
    }

    // 3. Resting energy (Mifflin-St Jeor), identical to v1.
    final base = 10 * profile.currentWeightKg +
        6.25 * profile.heightCm -
        5 * profile.ageYears;
    final rmr = switch (profile.equationProfile) {
      EquationProfile.higherOffset => base + 5,
      EquationProfile.lowerOffset => base - 161,
      EquationProfile.neutral => base + (5 - 161) / 2,
    };
    if (rmr.isNaN || rmr.isInfinite || rmr <= 0) {
      return NutritionTargetV2(
        status: NutritionTargetStatus.unsupported,
        calculatedAt: now,
        reasons: const ['rmrCalculationOutOfRange'],
      );
    }

    final weightKg = profile.currentWeightKg;
    final warnings = <String>[];

    // 4. Planned session energy, per day.
    final dayKcal = List<double>.filled(7, 0);
    final dayHasHard = List<bool>.filled(7, false);
    final dayHasSession = List<bool>.filled(7, false);
    var ignored = 0;
    for (final session in plannedWeek) {
      if (!session.hasValidDay) {
        ignored++;
        continue;
      }
      final kcal = SessionEnergyTable.sessionKcal(session, weightKg);
      if (kcal <= 0) continue;
      dayKcal[session.dayIndex] += kcal;
      dayHasSession[session.dayIndex] = true;
      if (session.intensity == FuelIntensity.hard) {
        dayHasHard[session.dayIndex] = true;
      }
    }
    if (ignored > 0) warnings.add('plannedSessionsIgnored');
    final weekSessionKcal = dayKcal.fold<double>(0, (a, b) => a + b);
    if (weekSessionKcal <= 0) warnings.add('noPlannedSessions');

    // 5. Maintenance, including planned training.
    final factor =
        NutritionPolicyV2.nonTrainingFactorFor(profile.activityLevel);
    final maintenance = rmr * factor + weekSessionKcal / 7;
    final isNeutral = profile.equationProfile == EquationProfile.neutral;
    final rangeFraction = isNeutral
        ? NutritionPolicy.maintenanceRangeFraction * 1.5
        : NutritionPolicy.maintenanceRangeFraction;

    // 6. Weight change as a percent of body weight per week, clamped.
    final requested = weeklyRatePercent ??
        WeightRatePolicy.percentForPace(profile.goalPace, profile.goal);
    final rate = WeightRatePolicy.apply(
      goal: profile.goal,
      weightKg: weightKg,
      requestedPercent: requested,
    );
    if (rate.wasClamped) warnings.add('weightRateAdjusted');
    final dailyGap =
        WeightRatePolicy.dailyKcalFor(rate.percentPerWeek, weightKg);
    var rawAverage = switch (profile.goal) {
      NutritionGoal.loseFat => maintenance - dailyGap,
      NutritionGoal.gainMuscle => maintenance + dailyGap,
      NutritionGoal.maintain => maintenance,
    };

    // 7. Macro anchors that do not move between days.
    final isLosing = profile.goal == NutritionGoal.loseFat;
    final referenceWeightKg = isLosing ? profile.targetWeightKg! : weightKg;
    final proteinPerKg = isLosing
        ? NutritionPolicyV2.proteinGPerKgLosing
        : NutritionPolicyV2.proteinGPerKgOther;
    final proteinFloor =
        (NutritionPolicyV2.proteinFloorGPerKg * weightKg).ceil();
    final computedProtein = (referenceWeightKg * proteinPerKg).round();
    final proteinGrams =
        computedProtein < proteinFloor ? proteinFloor : computedProtein;
    final proteinKcal = proteinGrams * 4;
    final fatFloorGrams = (NutritionPolicyV2.fatFloorGPerKg * weightKg).ceil();
    int fatFor(int kcal) {
      final byEnergy =
          (kcal * NutritionPolicyV2.fatPercentOfEnergy / 9).round();
      return byEnergy < fatFloorGrams ? fatFloorGrams : byEnergy;
    }

    final carbFloorKcal = NutritionPolicyV2.carbFloorGPerKg * weightKg * 4;

    // 8. Never below RMR (the v1 minimum).
    final rmrFloor = NutritionPolicyV2.ceilToTen(rmr);
    if (isLosing && rawAverage < rmr) {
      rawAverage = rmr;
      warnings.add('goalRateReducedToProtectRmr');
    }
    var average = NutritionPolicyV2.roundToTen(rawAverage);
    if (average < rmrFloor) average = rmrFloor;

    // 9. While losing fat, carbohydrate stays at its floor. Lift the average
    // first; if even maintenance cannot hold the floor beside this protein,
    // stay at maintenance and say so rather than lifting a loss goal above it.
    if (isLosing) {
      final before = average;
      var guard = 0;
      while (average - proteinKcal - fatFor(average) * 9 < carbFloorKcal &&
          guard++ < 5000) {
        average += 10;
      }
      if (average > before) {
        if (average <= NutritionPolicyV2.ceilToTen(maintenance)) {
          warnings.add('goalRateReducedForCarbFloor');
        } else {
          final atMaintenance = NutritionPolicyV2.roundToTen(maintenance);
          average = atMaintenance > before ? atMaintenance : before;
          warnings.add('carbFloorConflictsWithProteinTarget');
        }
      }
    }

    // 10. Fixed fat, and the lowest any single day may go.
    final fatGrams = fatFor(average);
    final fixedKcal = proteinKcal + fatGrams * 9;
    if (!isLosing && average - fixedKcal < carbFloorKcal) {
      // Maintenance and gain are never lifted to fix this, but it is said.
      warnings.add('carbFloorConflictsWithProteinTarget');
    }
    final minimumDay = NutritionPolicyV2.ceilToTen(
      [rmr, fixedKcal + carbFloorKcal].reduce((a, b) => a > b ? a : b),
    );

    // 11. Training-day / rest-day split: zero-sum around the weekly mean.
    final meanSession = weekSessionKcal / 7;
    final deviations = [for (final k in dayKcal) k - meanSession];
    double shift =
        trainingDayShift ? NutritionPolicyV2.trainingDayShiftFraction : 0.0;
    for (final d in deviations) {
      if (d >= 0) continue;
      final room = average - minimumDay;
      final allowed = room <= 0 ? 0.0 : room / -d;
      if (allowed < shift) shift = allowed;
    }
    var calories = _splitWeek(
      average: average,
      deviations: deviations,
      shift: shift,
      minimumDay: minimumDay,
    );
    if (calories == null) {
      shift = 0;
      calories = List<int>.filled(7, average);
    }
    final shiftApplied = shift > 0 && deviations.any((d) => d.abs() >= 5);

    // 12. Per-day macros: protein and fat fixed, carbohydrate the remainder.
    var clamped = false;
    final days = <DailyFuelTarget>[];
    for (var i = 0; i < 7; i++) {
      var carbs = ((calories[i] - fixedKcal) / 4).round();
      if (carbs < 0) {
        carbs = 0;
        clamped = true;
      }
      final hard = dayHasHard[i] ||
          dayKcal[i] >= NutritionPolicyV2.hardDaySessionKcalPerKg * weightKg;
      days.add(DailyFuelTarget(
        dayIndex: i,
        kind: !dayHasSession[i]
            ? FuelDayKind.rest
            : (hard ? FuelDayKind.hard : FuelDayKind.light),
        calories: calories[i],
        proteinGrams: proteinGrams,
        fatGrams: fatGrams,
        carbGrams: carbs,
        sessionKcal: dayKcal[i].round(),
      ));
    }
    if (clamped) warnings.add('carbGramsClampedToZero');

    var carbAverage = ((average - fixedKcal) / 4).round();
    if (carbAverage < 0) carbAverage = 0;

    final signedChange = (average - maintenance) *
        7 /
        WeightRatePolicy.kcalPerKg /
        weightKg *
        100;

    return NutritionTargetV2(
      status: NutritionTargetStatus.success,
      calculatedAt: now,
      warnings: warnings,
      estimatedRmrKcal: rmr.round(),
      nonTrainingFactorUsed: factor,
      maintenanceKcal: maintenance.round(),
      maintenanceRangeLowKcal: (maintenance * (1 - rangeFraction)).round(),
      maintenanceRangeHighKcal: (maintenance * (1 + rangeFraction)).round(),
      sessionEnergyKcalPerWeek: weekSessionKcal.round(),
      weeklyAverageCalories: average,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbGrams: carbAverage,
      fiberGramsLow:
          (average / 1000 * NutritionPolicy.fiberGPer1000KcalLow).round(),
      fiberGramsHigh:
          (average / 1000 * NutritionPolicy.fiberGPer1000KcalHigh).round(),
      minimumDailyKcal: minimumDay,
      appliedWeeklyChangePercent: signedChange,
      proteinReferenceWeightKg: referenceWeightKg,
      equationProfileUsed: profile.equationProfile,
      confidence: isNeutral
          ? ConfidenceLabel.low
          : (warnings.isNotEmpty
              ? ConfidenceLabel.medium
              : ConfidenceLabel.high),
      trainingDayShiftApplied: shiftApplied,
      days: days,
    );
  }

  /// Seven daily calorie values, each a multiple of ten and at least
  /// [minimumDay], that sum to exactly seven times [average]. Null when the
  /// rounding residue cannot be placed without breaching [minimumDay]; the
  /// caller then uses a flat week.
  static List<int>? _splitWeek({
    required int average,
    required List<double> deviations,
    required double shift,
    required int minimumDay,
  }) {
    final raw = [for (final d in deviations) average + shift * d];
    final rounded = [for (final r in raw) NutritionPolicyV2.roundToTen(r)];
    for (final r in rounded) {
      if (r < minimumDay && shift > 0) return null;
    }
    var residue = average * 7 - rounded.fold<int>(0, (a, b) => a + b);
    if (residue == 0) return rounded;
    // Days rounded furthest down take the extra ten first; days rounded
    // furthest up give one back first.
    final order = List<int>.generate(7, (i) => i)
      ..sort((a, b) {
        final byError = (raw[b] - rounded[b]).compareTo(raw[a] - rounded[a]);
        return residue > 0 ? byError : -byError;
      });
    final step = residue > 0 ? 10 : -10;
    var guard = 0;
    while (residue != 0 && guard++ < 70) {
      var placed = false;
      for (final i in order) {
        if (residue == 0) break;
        if (rounded[i] + step < minimumDay) continue;
        rounded[i] += step;
        residue -= step;
        placed = true;
      }
      if (!placed) return null;
    }
    return residue == 0 ? rounded : null;
  }
}
