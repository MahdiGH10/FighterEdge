import 'dart:math' as math;

import '../models/accepted_fuel_week.dart';
import '../models/fuel_day_plan.dart';
import '../models/nutrition_target.dart';
import '../policies/fuel_day_policy.dart';
import '../policies/nutrition_policy.dart';
import '../policies/nutrition_policy_v2.dart';
import 'fuel_day_planner.dart';
import 'fuel_week_allocation.dart';

/// Allocates an already accepted weekly-average target over a dated week.
/// No maintenance/goal calculation, clock, persistence or new energy is added.
/// Protein and fat stay fixed; weekly kcal AND carbohydrate totals stay exact.
class AcceptedFuelWeekAllocator {
  const AcceptedFuelWeekAllocator._();

  /// [amountsEnabled] is a reviewed-build gate, never a subscription or user
  /// preference. DIETITIAN SIGN-OFF PENDING: it stays off by default. An
  /// accepted target is not evidence that the day-type policy is reviewed.
  ///
  /// A week intersecting fight week is withheld entirely: this allocator
  /// must not redistribute a fight-week budget or infer fight-week targets.
  static AcceptedFuelWeek allocate({
    required NutritionTarget? acceptedTarget,
    required List<FuelDayPlan> days,
    required int? ageYears,
    required double? weightKg,
    bool amountsEnabled = FuelDayPolicy.amountsEnabledByDefault,
  }) {
    AcceptedFuelWeek blocked(AcceptedFuelWeekStatus status) =>
        AcceptedFuelWeek(status: status);
    if (ageYears == null || ageYears < NutritionPolicy.minimumAgeYears) {
      return blocked(AcceptedFuelWeekStatus.adultRequired);
    }
    if (!amountsEnabled) {
      return blocked(AcceptedFuelWeekStatus.awaitingSignOff);
    }
    if (ageYears > 120 ||
        weightKg == null ||
        !weightKg.isFinite ||
        weightKg <= 0 ||
        days.length != FuelWeekAllocation.daysPerWeek ||
        acceptedTarget?.isSuccess != true) {
      return blocked(AcceptedFuelWeekStatus.needsMoreData);
    }
    for (var i = 0; i < days.length; i++) {
      if (FuelCalendar.dayNumber(days[i].date) !=
              FuelCalendar.dayNumber(days.first.date) + i ||
          !days[i].sessionKcalPerKg.isFinite ||
          days[i].sessionKcalPerKg < 0) {
        return blocked(AcceptedFuelWeekStatus.needsMoreData);
      }
    }
    if (days.any((d) => d.isFightWeek)) {
      return blocked(AcceptedFuelWeekStatus.fightWeek);
    }
    final target = acceptedTarget!;
    final average = target.targetCalories;
    final protein = target.proteinGrams;
    final fat = target.fatGrams;
    final carbs = target.carbGrams;
    final rmr = target.estimatedRmrKcal;
    if (average == null ||
        average <= 0 ||
        protein == null ||
        protein <= 0 ||
        fat == null ||
        fat <= 0 ||
        carbs == null ||
        carbs < 0 ||
        rmr == null ||
        rmr <= 0) {
      return blocked(AcceptedFuelWeekStatus.needsMoreData);
    }
    final fixedKcal = protein * 4 + fat * 9;
    if ((target.macroDerivedCalories! - average).abs() > 20 || average < rmr) {
      return blocked(AcceptedFuelWeekStatus.incompatibleTarget);
    }
    final guidance = [
      for (final day in days)
        FuelDayPlanner.guidance(day,
            weightKg: weightKg,
            adultConfirmed: true,
            amountsEnabled: amountsEnabled)!,
    ];
    if (guidance
        .any((g) => protein < g.proteinFloorGrams || fat < g.fatFloorGrams)) {
      return blocked(AcceptedFuelWeekStatus.incompatibleTarget);
    }
    final carbFloors = [for (final g in guidance) g.carbFloorGrams];
    final floors = [
      for (final floor in carbFloors)
        NutritionPolicyV2.ceilToTen(
            math.max(rmr.toDouble(), (fixedKcal + floor * 4).toDouble())),
    ];
    final energy = [for (final d in days) d.sessionKcalPerKg * weightKg];
    if (energy.any((e) => !e.isFinite)) {
      return blocked(AcceptedFuelWeekStatus.needsMoreData);
    }
    final mean = energy.reduce((a, b) => a + b) / days.length;
    if (!mean.isFinite) return blocked(AcceptedFuelWeekStatus.needsMoreData);
    final deviations = [for (final e in energy) e - mean];
    var shift = NutritionPolicyV2.trainingDayShiftFraction;
    for (var i = 0; i < days.length; i++) {
      if (deviations[i] >= 0) continue;
      shift =
          math.min(shift, math.max(0, average - floors[i]) / -deviations[i]);
    }
    var kcal = FuelWeekAllocation.split(
        average: average,
        deviations: deviations,
        shift: shift,
        minimums: floors);
    var carbohydrate = kcal == null
        ? null
        : FuelWeekAllocation.split(
            average: carbs,
            deviations: [for (final k in kcal) (k - average) / 4],
            shift: 1,
            minimums: carbFloors,
            quantum: 1,
          );
    bool reconciles(List<int> k, List<int> c) =>
        List.generate(days.length, (i) => i)
            .every((i) => (fixedKcal + c[i] * 4 - k[i]).abs() <= 20);
    if (kcal == null ||
        carbohydrate == null ||
        !reconciles(kcal, carbohydrate)) {
      // A flat accepted week is the only fallback. Never lift the average
      // or silently replace the accepted macro anchors to make a split fit.
      if (floors.any((f) => average < f) || carbFloors.any((f) => carbs < f)) {
        return blocked(AcceptedFuelWeekStatus.incompatibleTarget);
      }
      kcal = List.filled(days.length, average);
      carbohydrate = List.filled(days.length, carbs);
    }
    return AcceptedFuelWeek(
      status: AcceptedFuelWeekStatus.ready,
      shiftApplied: kcal.any((k) => k != average),
      days: [
        for (var i = 0; i < days.length; i++)
          AcceptedFuelDay(
            plan: days[i],
            calories: kcal[i],
            proteinGrams: protein,
            carbGrams: carbohydrate[i],
            fatGrams: fat,
          )
      ],
    );
  }
}
