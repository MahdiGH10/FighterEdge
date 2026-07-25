import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';

void main() {
  group('NutritionSetupDraft.hasRequiredCalculatorInputs', () {
    test('false when empty', () {
      expect(const NutritionSetupDraft.empty().hasRequiredCalculatorInputs,
          isFalse);
    });

    test('maintain goal does not require target weight or pace', () {
      const draft = NutritionSetupDraft(
        goal: NutritionGoal.maintain,
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
        normalActivityLevel: ActivityLevel.moderate,
      );
      expect(draft.hasRequiredCalculatorInputs, isTrue);
      expect(draft.toProfile(), isNotNull);
    });

    test('loseFat goal requires target weight and pace', () {
      const base = NutritionSetupDraft(
        goal: NutritionGoal.loseFat,
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
        normalActivityLevel: ActivityLevel.moderate,
      );
      expect(base.hasRequiredCalculatorInputs, isFalse);
      expect(base.toProfile(), isNull);

      final complete = base.copyWith(
        targetWeightKg: 74,
        goalPace: GoalPace.standard,
      );
      expect(complete.hasRequiredCalculatorInputs, isTrue);
      expect(complete.toProfile(), isNotNull);
    });
  });

  group('NutritionSetupDraft JSON round trip', () {
    test('preserves every field including food preferences', () {
      const draft = NutritionSetupDraft(
        currentStep: 4,
        confirmed: false,
        goal: NutritionGoal.gainMuscle,
        ageYears: 24,
        heightCm: 175.5,
        currentWeightKg: 68.2,
        targetWeightKg: 74,
        equationProfile: EquationProfile.neutral,
        normalActivityLevel: ActivityLevel.high,
        weeklyTrainingDays: 5,
        goalPace: GoalPace.gainStandard,
        dietType: 'omnivore',
        allergens: ['peanuts', 'shellfish'],
        dislikedFoods: ['okra'],
        mealsPerDay: 4,
        budgetBand: 'medium',
        cookingTimeBand: 'quick',
        bodyFatPercent: 14.5,
        safetyFlags: NutritionSafetyFlags(kidneyDisease: true),
      );

      final restored = NutritionSetupDraft.fromJson(draft.toJson());

      expect(restored.currentStep, draft.currentStep);
      expect(restored.confirmed, draft.confirmed);
      expect(restored.goal, draft.goal);
      expect(restored.ageYears, draft.ageYears);
      expect(restored.heightCm, draft.heightCm);
      expect(restored.currentWeightKg, draft.currentWeightKg);
      expect(restored.targetWeightKg, draft.targetWeightKg);
      expect(restored.equationProfile, draft.equationProfile);
      expect(restored.normalActivityLevel, draft.normalActivityLevel);
      expect(restored.weeklyTrainingDays, draft.weeklyTrainingDays);
      expect(restored.goalPace, draft.goalPace);
      expect(restored.dietType, draft.dietType);
      expect(restored.allergens, draft.allergens);
      expect(restored.dislikedFoods, draft.dislikedFoods);
      expect(restored.mealsPerDay, draft.mealsPerDay);
      expect(restored.budgetBand, draft.budgetBand);
      expect(restored.cookingTimeBand, draft.cookingTimeBand);
      expect(restored.bodyFatPercent, draft.bodyFatPercent);
      expect(restored.safetyFlags.kidneyDisease, isTrue);
    });

    test('fromJson tolerates an empty map', () {
      final restored = NutritionSetupDraft.fromJson(const {});
      expect(restored.goal, isNull);
      expect(restored.currentStep, 0);
      expect(restored.confirmed, isFalse);
      expect(restored.allergens, isEmpty);
    });
  });
}
