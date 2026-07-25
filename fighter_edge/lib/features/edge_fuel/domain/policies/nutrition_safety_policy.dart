import '../models/nutrition_enums.dart';
import '../models/nutrition_profile.dart';
import 'nutrition_policy.dart';

/// Result of a safety check. `status` mirrors the subset of
/// [NutritionTargetStatus] a safety check can produce — never `success`,
/// since a safety check alone doesn't calculate a target.
class SafetyCheckResult {
  final NutritionTargetStatus status;
  final List<String> reasons;

  const SafetyCheckResult.allowed()
      : status = NutritionTargetStatus.success,
        reasons = const [];

  const SafetyCheckResult.unsupported(this.reasons)
      : status = NutritionTargetStatus.unsupported;

  const SafetyCheckResult.needsProfessionalReview(this.reasons)
      : status = NutritionTargetStatus.needsProfessionalReview;

  bool get isAllowed => status == NutritionTargetStatus.success;
}

/// Evaluates a [NutritionProfile] against master prompt §4 and §6 before any
/// calculation runs. Pure Dart — no Flutter/Firebase/clock/network
/// dependency, so it's exhaustively unit-testable.
class NutritionSafetyPolicy {
  const NutritionSafetyPolicy._();

  static SafetyCheckResult evaluate(NutritionProfile profile) {
    final unsupportedReasons = <String>[];

    if (profile.ageYears < NutritionPolicy.minimumAgeYears) {
      unsupportedReasons.add('underAge');
    }

    if (!_hasValidVitals(profile)) {
      unsupportedReasons.add('invalidVitals');
    } else {
      if (profile.goal == NutritionGoal.loseFat) {
        if (_isUnderweight(profile)) {
          unsupportedReasons.add('underweightForFatLoss');
        }
        if (!_hasValidLossTarget(profile)) {
          unsupportedReasons.add('invalidFatLossTarget');
        }
      }
      if (profile.goal == NutritionGoal.gainMuscle &&
          !_hasValidGainTarget(profile)) {
        unsupportedReasons.add('invalidMuscleGainTarget');
      }
    }

    if (unsupportedReasons.isNotEmpty) {
      return SafetyCheckResult.unsupported(unsupportedReasons);
    }

    if (profile.safetyFlags.any) {
      return SafetyCheckResult.needsProfessionalReview(
        _flagReasons(profile.safetyFlags),
      );
    }

    return const SafetyCheckResult.allowed();
  }

  static bool _hasValidVitals(NutritionProfile p) {
    if (p.heightCm.isNaN || p.heightCm.isInfinite || p.heightCm <= 0) {
      return false;
    }
    if (p.currentWeightKg.isNaN ||
        p.currentWeightKg.isInfinite ||
        p.currentWeightKg <= 0) {
      return false;
    }
    if (p.ageYears <= 0 || p.ageYears > 120) return false;
    return true;
  }

  static double _bmi(NutritionProfile p) {
    final heightM = p.heightCm / 100;
    return p.currentWeightKg / (heightM * heightM);
  }

  static bool _isUnderweight(NutritionProfile p) =>
      _bmi(p) < NutritionPolicy.underweightBmiCutoff;

  static bool _hasValidLossTarget(NutritionProfile p) {
    final target = p.targetWeightKg;
    if (target == null || target.isNaN || target.isInfinite || target <= 0) {
      return false;
    }
    return target < p.currentWeightKg;
  }

  static bool _hasValidGainTarget(NutritionProfile p) {
    final target = p.targetWeightKg;
    if (target == null || target.isNaN || target.isInfinite || target <= 0) {
      return false;
    }
    return target > p.currentWeightKg;
  }

  static List<String> _flagReasons(NutritionSafetyFlags flags) {
    return [
      if (flags.pregnantOrBreastfeeding) 'pregnantOrBreastfeeding',
      if (flags.eatingDisorderHistoryOrSymptoms)
        'eatingDisorderHistoryOrSymptoms',
      if (flags.diabetesRequiringMedication) 'diabetesRequiringMedication',
      if (flags.kidneyDisease) 'kidneyDisease',
      if (flags.seriousLiverDisease) 'seriousLiverDisease',
      if (flags.otherClinicianManagedDiet) 'otherClinicianManagedDiet',
    ];
  }
}
