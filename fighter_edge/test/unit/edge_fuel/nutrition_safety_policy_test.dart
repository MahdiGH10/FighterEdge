import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_safety_policy.dart';

NutritionProfile _adultProfile({
  int ageYears = 25,
  double heightCm = 175,
  double currentWeightKg = 75,
  NutritionGoal goal = NutritionGoal.maintain,
  double? targetWeightKg,
  NutritionSafetyFlags safetyFlags = const NutritionSafetyFlags(),
}) {
  return NutritionProfile(
    goal: goal,
    ageYears: ageYears,
    heightCm: heightCm,
    currentWeightKg: currentWeightKg,
    targetWeightKg: targetWeightKg,
    goalPace: goal == NutritionGoal.maintain ? null : GoalPace.standard,
    equationProfile: EquationProfile.higherOffset,
    activityLevel: ActivityLevel.moderate,
    safetyFlags: safetyFlags,
  );
}

void main() {
  group('NutritionSafetyPolicy.evaluate', () {
    test('a clean adult maintenance profile is allowed', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile());
      expect(result.isAllowed, isTrue);
      expect(result.status, NutritionTargetStatus.success);
    });

    test('under 18 is unsupported regardless of anything else', () {
      final result =
          NutritionSafetyPolicy.evaluate(_adultProfile(ageYears: 17));
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('underAge'));
    });

    test('an underweight BMI blocks an automated fat-loss request', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile(
        goal: NutritionGoal.loseFat,
        currentWeightKg: 48,
        heightCm: 180,
        targetWeightKg: 44,
      ));
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('underweightForFatLoss'));
    });

    test('a normal-BMI fat-loss request with a valid target is allowed', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile(
        goal: NutritionGoal.loseFat,
        currentWeightKg: 80,
        targetWeightKg: 74,
      ));
      expect(result.isAllowed, isTrue);
    });

    test('a fat-loss target above current weight is unsupported', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile(
        goal: NutritionGoal.loseFat,
        currentWeightKg: 80,
        targetWeightKg: 85,
      ));
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('invalidFatLossTarget'));
    });

    test('a muscle-gain target below current weight is unsupported', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile(
        goal: NutritionGoal.gainMuscle,
        currentWeightKg: 80,
        targetWeightKg: 78,
      ));
      expect(result.status, NutritionTargetStatus.unsupported);
      expect(result.reasons, contains('invalidMuscleGainTarget'));
    });

    test('each individual clinical flag triggers needsProfessionalReview', () {
      final cases = <NutritionSafetyFlags>[
        const NutritionSafetyFlags(pregnantOrBreastfeeding: true),
        const NutritionSafetyFlags(eatingDisorderHistoryOrSymptoms: true),
        const NutritionSafetyFlags(diabetesRequiringMedication: true),
        const NutritionSafetyFlags(kidneyDisease: true),
        const NutritionSafetyFlags(seriousLiverDisease: true),
        const NutritionSafetyFlags(otherClinicianManagedDiet: true),
      ];
      for (final flags in cases) {
        final result =
            NutritionSafetyPolicy.evaluate(_adultProfile(safetyFlags: flags));
        expect(
          result.status,
          NutritionTargetStatus.needsProfessionalReview,
          reason: 'flags: ${flags.toJson()}',
        );
      }
    });

    test(
        'a safety flag does not block outright — it requires review, not '
        'unsupported', () {
      final result = NutritionSafetyPolicy.evaluate(_adultProfile(
        safetyFlags: const NutritionSafetyFlags(kidneyDisease: true),
      ));
      expect(result.status, isNot(NutritionTargetStatus.unsupported));
    });

    test('invalid vitals (zero/negative/NaN) are rejected', () {
      expect(
        NutritionSafetyPolicy.evaluate(_adultProfile(heightCm: 0)).status,
        NutritionTargetStatus.unsupported,
      );
      expect(
        NutritionSafetyPolicy.evaluate(_adultProfile(currentWeightKg: -5))
            .status,
        NutritionTargetStatus.unsupported,
      );
      expect(
        NutritionSafetyPolicy.evaluate(
                _adultProfile(currentWeightKg: double.nan))
            .status,
        NutritionTargetStatus.unsupported,
      );
    });
  });

  group('NutritionSafetyFlags', () {
    test('any is false when no flag is set', () {
      expect(const NutritionSafetyFlags().any, isFalse);
    });

    test('any is true when a single flag is set', () {
      expect(
        const NutritionSafetyFlags(kidneyDisease: true).any,
        isTrue,
      );
    });

    test('toJson/fromJson round-trips every flag', () {
      const flags = NutritionSafetyFlags(
        pregnantOrBreastfeeding: true,
        eatingDisorderHistoryOrSymptoms: true,
        diabetesRequiringMedication: true,
        kidneyDisease: true,
        seriousLiverDisease: true,
        otherClinicianManagedDiet: true,
      );
      final restored = NutritionSafetyFlags.fromJson(flags.toJson());
      expect(restored.pregnantOrBreastfeeding, isTrue);
      expect(restored.eatingDisorderHistoryOrSymptoms, isTrue);
      expect(restored.diabetesRequiringMedication, isTrue);
      expect(restored.kidneyDisease, isTrue);
      expect(restored.seriousLiverDisease, isTrue);
      expect(restored.otherClinicianManagedDiet, isTrue);
    });

    test('copyWith changes only the given flag', () {
      const flags = NutritionSafetyFlags(kidneyDisease: true);
      final updated = flags.copyWith(seriousLiverDisease: true);
      expect(updated.kidneyDisease, isTrue);
      expect(updated.seriousLiverDisease, isTrue);
      expect(updated.pregnantOrBreastfeeding, isFalse);
    });
  });
}
