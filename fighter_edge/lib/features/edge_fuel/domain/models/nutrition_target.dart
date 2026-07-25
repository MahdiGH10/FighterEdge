import 'nutrition_enums.dart';

/// The typed result of [NutritionTargetCalculator]. Every field that could
/// be shown to a user is present so the UI (a later sprint) can satisfy
/// master prompt §4.12: show that it's an estimate, the equation/version
/// used, its assumptions, when it was calculated, and how to edit inputs.
///
/// `status` is always present. The numeric fields are only guaranteed
/// non-null when `status == NutritionTargetStatus.success`.
class NutritionTarget {
  final NutritionTargetStatus status;
  final int policyVersion;
  final DateTime calculatedAt;

  /// Non-empty only for [NutritionTargetStatus.unsupported] or
  /// [NutritionTargetStatus.needsProfessionalReview].
  final List<String> reasons;

  /// Advisory, non-blocking notes (e.g. "pace reduced to stay above RMR",
  /// "carbohydrate is below the reviewed performance threshold"). Can be
  /// present alongside `success`.
  final List<String> warnings;

  // ---- populated only on success ----
  final int? estimatedRmrKcal;
  final int? maintenanceRangeLowKcal;
  final int? maintenanceRangeHighKcal;
  final int? targetCalories;
  final int? proteinGrams;
  final int? fatGrams;
  final int? carbGrams;
  final int? fiberGramsLow;
  final int? fiberGramsHigh;

  /// The weight (kg) protein grams were derived from — surfaced per master
  /// prompt §7.5 ("surface the reference weight in the explanation").
  final double? proteinReferenceWeightKg;
  final EquationProfile? equationProfileUsed;
  final double? activityCoefficientUsed;

  /// The goal-adjustment percentage actually applied (may differ from the
  /// requested pace if it was reduced to stay above RMR).
  final double? appliedGoalAdjustmentPercent;
  final ConfidenceLabel? confidence;

  const NutritionTarget({
    required this.status,
    required this.policyVersion,
    required this.calculatedAt,
    this.reasons = const [],
    this.warnings = const [],
    this.estimatedRmrKcal,
    this.maintenanceRangeLowKcal,
    this.maintenanceRangeHighKcal,
    this.targetCalories,
    this.proteinGrams,
    this.fatGrams,
    this.carbGrams,
    this.fiberGramsLow,
    this.fiberGramsHigh,
    this.proteinReferenceWeightKg,
    this.equationProfileUsed,
    this.activityCoefficientUsed,
    this.appliedGoalAdjustmentPercent,
    this.confidence,
  });

  bool get isSuccess => status == NutritionTargetStatus.success;

  /// Sum of macro-derived calories (4 kcal/g protein & carb, 9 kcal/g fat).
  /// Used by the calculator to enforce the ±20 kcal reconciliation
  /// invariant (master prompt §7.6) — exposed here too so tests and any
  /// future UI can display/verify it without recomputing.
  int? get macroDerivedCalories {
    if (proteinGrams == null || fatGrams == null || carbGrams == null) {
      return null;
    }
    return proteinGrams! * 4 + carbGrams! * 4 + fatGrams! * 9;
  }

  Map<String, dynamic> toJson() => {
        'status': status.name,
        'policyVersion': policyVersion,
        'calculatedAt': calculatedAt.toIso8601String(),
        'reasons': reasons,
        'warnings': warnings,
        'estimatedRmrKcal': estimatedRmrKcal,
        'maintenanceRangeLowKcal': maintenanceRangeLowKcal,
        'maintenanceRangeHighKcal': maintenanceRangeHighKcal,
        'targetCalories': targetCalories,
        'proteinGrams': proteinGrams,
        'fatGrams': fatGrams,
        'carbGrams': carbGrams,
        'fiberGramsLow': fiberGramsLow,
        'fiberGramsHigh': fiberGramsHigh,
        'proteinReferenceWeightKg': proteinReferenceWeightKg,
        'equationProfileUsed': equationProfileUsed?.name,
        'activityCoefficientUsed': activityCoefficientUsed,
        'appliedGoalAdjustmentPercent': appliedGoalAdjustmentPercent,
        'confidence': confidence?.name,
      };

  factory NutritionTarget.fromJson(Map<String, dynamic> json) {
    return NutritionTarget(
      status: enumFromName(NutritionTargetStatus.values, json['status']) ??
          NutritionTargetStatus.needsMoreData,
      policyVersion: (json['policyVersion'] as num?)?.toInt() ?? 0,
      calculatedAt: DateTime.tryParse(json['calculatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      reasons: List<String>.from(json['reasons'] as List? ?? const []),
      warnings: List<String>.from(json['warnings'] as List? ?? const []),
      estimatedRmrKcal: (json['estimatedRmrKcal'] as num?)?.toInt(),
      maintenanceRangeLowKcal: (json['maintenanceRangeLowKcal'] as num?)?.toInt(),
      maintenanceRangeHighKcal:
          (json['maintenanceRangeHighKcal'] as num?)?.toInt(),
      targetCalories: (json['targetCalories'] as num?)?.toInt(),
      proteinGrams: (json['proteinGrams'] as num?)?.toInt(),
      fatGrams: (json['fatGrams'] as num?)?.toInt(),
      carbGrams: (json['carbGrams'] as num?)?.toInt(),
      fiberGramsLow: (json['fiberGramsLow'] as num?)?.toInt(),
      fiberGramsHigh: (json['fiberGramsHigh'] as num?)?.toInt(),
      proteinReferenceWeightKg:
          (json['proteinReferenceWeightKg'] as num?)?.toDouble(),
      equationProfileUsed:
          enumFromName(EquationProfile.values, json['equationProfileUsed']),
      activityCoefficientUsed:
          (json['activityCoefficientUsed'] as num?)?.toDouble(),
      appliedGoalAdjustmentPercent:
          (json['appliedGoalAdjustmentPercent'] as num?)?.toDouble(),
      confidence: enumFromName(ConfidenceLabel.values, json['confidence']),
    );
  }
}
