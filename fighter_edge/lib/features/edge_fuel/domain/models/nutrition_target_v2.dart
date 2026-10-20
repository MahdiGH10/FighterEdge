import 'nutrition_enums.dart';
import 'nutrition_target.dart';
import 'planned_fuel_session.dart';

/// One day of a policy-v2 weekly plan.
class DailyFuelTarget {
  const DailyFuelTarget({
    required this.dayIndex,
    required this.kind,
    required this.calories,
    required this.proteinGrams,
    required this.fatGrams,
    required this.carbGrams,
    required this.sessionKcal,
  });

  /// 0 to 6, matching [PlannedFuelSession.dayIndex].
  final int dayIndex;
  final FuelDayKind kind;
  final int calories;
  final int proteinGrams;
  final int fatGrams;
  final int carbGrams;

  /// Planned session energy on this day. Informational: it explains the
  /// shift and is not added to [calories].
  final int sessionKcal;

  int get macroDerivedCalories =>
      proteinGrams * 4 + carbGrams * 4 + fatGrams * 9;
}

/// The result of `NutritionTargetCalculatorV2`: a weekly average target plus
/// a per-day split that sums back to it exactly.
///
/// Numeric fields are non-null only when [status] is
/// [NutritionTargetStatus.success].
class NutritionTargetV2 {
  const NutritionTargetV2({
    required this.status,
    required this.calculatedAt,
    this.reasons = const [],
    this.warnings = const [],
    this.estimatedRmrKcal,
    this.nonTrainingFactorUsed,
    this.maintenanceKcal,
    this.maintenanceRangeLowKcal,
    this.maintenanceRangeHighKcal,
    this.sessionEnergyKcalPerWeek,
    this.weeklyAverageCalories,
    this.proteinGrams,
    this.fatGrams,
    this.carbGrams,
    this.fiberGramsLow,
    this.fiberGramsHigh,
    this.minimumDailyKcal,
    this.appliedWeeklyChangePercent,
    this.proteinReferenceWeightKg,
    this.equationProfileUsed,
    this.confidence,
    this.trainingDayShiftApplied = false,
    this.days = const [],
  });

  final NutritionTargetStatus status;
  final DateTime calculatedAt;

  /// Why no target was produced. Non-empty only for the non-success statuses.
  final List<String> reasons;

  /// Advisory notes that can accompany a success.
  final List<String> warnings;

  final int? estimatedRmrKcal;
  final double? nonTrainingFactorUsed;

  /// Average daily maintenance including planned sessions.
  final int? maintenanceKcal;
  final int? maintenanceRangeLowKcal;
  final int? maintenanceRangeHighKcal;
  final int? sessionEnergyKcalPerWeek;

  /// The target a user is held to: the mean of [days].
  final int? weeklyAverageCalories;
  final int? proteinGrams;
  final int? fatGrams;

  /// Average carbohydrate over the week.
  final int? carbGrams;
  final int? fiberGramsLow;
  final int? fiberGramsHigh;

  /// The lowest daily kcal this plan, or a check-in, may ever set: never
  /// below RMR, and never below the carbohydrate floor while losing fat.
  final int? minimumDailyKcal;

  /// Signed effective weekly change as a percent of body weight, from the
  /// final target. Negative means losing.
  final double? appliedWeeklyChangePercent;
  final double? proteinReferenceWeightKg;
  final EquationProfile? equationProfileUsed;
  final ConfidenceLabel? confidence;

  /// False when the shift was off, limited to nothing by the floors, or the
  /// week has no training variation.
  final bool trainingDayShiftApplied;

  /// Seven entries on success, otherwise empty.
  final List<DailyFuelTarget> days;

  int get policyVersion => 2;

  bool get isSuccess => status == NutritionTargetStatus.success;

  /// The sum of [days]; always seven times [weeklyAverageCalories].
  int? get weeklyCalories =>
      days.isEmpty ? null : days.fold<int>(0, (sum, d) => sum + d.calories);

  /// The weekly average as a v1-shaped [NutritionTarget] stamped with policy
  /// version 2, for screens and stores that already hold that type.
  NutritionTarget toNutritionTarget() {
    if (!isSuccess) {
      return NutritionTarget(
        status: status,
        policyVersion: policyVersion,
        calculatedAt: calculatedAt,
        reasons: reasons,
        warnings: warnings,
      );
    }
    return NutritionTarget(
      status: status,
      policyVersion: policyVersion,
      calculatedAt: calculatedAt,
      warnings: warnings,
      estimatedRmrKcal: estimatedRmrKcal,
      maintenanceRangeLowKcal: maintenanceRangeLowKcal,
      maintenanceRangeHighKcal: maintenanceRangeHighKcal,
      targetCalories: weeklyAverageCalories,
      proteinGrams: proteinGrams,
      fatGrams: fatGrams,
      carbGrams: carbGrams,
      fiberGramsLow: fiberGramsLow,
      fiberGramsHigh: fiberGramsHigh,
      proteinReferenceWeightKg: proteinReferenceWeightKg,
      equationProfileUsed: equationProfileUsed,
      activityCoefficientUsed: nonTrainingFactorUsed,
      appliedGoalAdjustmentPercent: _adjustmentFraction(),
      confidence: confidence,
    );
  }

  double? _adjustmentFraction() {
    final maintenance = maintenanceKcal;
    final target = weeklyAverageCalories;
    if (maintenance == null || target == null || maintenance == 0) return null;
    return (maintenance - target).abs() / maintenance;
  }
}
