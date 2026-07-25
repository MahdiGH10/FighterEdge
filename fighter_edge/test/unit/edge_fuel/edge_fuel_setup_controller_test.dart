import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_setup_controller.dart';

void main() {
  group('EdgeFuelSetupController', () {
    test('autosaves each step and resumes from a saved draft', () async {
      final repo = InMemoryEdgeFuelRepository();
      final first = EdgeFuelSetupController(repository: repo, userId: 'u1');
      await Future<void>.delayed(Duration.zero); // let _load complete

      await first.setGoal(NutritionGoal.maintain);
      await first.setBodyInputs(
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
      );
      await first.setActivityLevel(ActivityLevel.moderate);
      await first.goToStep(2);

      final resumed = EdgeFuelSetupController(repository: repo, userId: 'u1');
      await Future<void>.delayed(Duration.zero);

      expect(resumed.draft.goal, NutritionGoal.maintain);
      expect(resumed.draft.ageYears, 30);
      expect(resumed.draft.currentStep, 2);
      expect(resumed.canReview, isTrue);
    });

    test('confirm() calculates and persists a target, then marks confirmed',
        () async {
      final repo = InMemoryEdgeFuelRepository();
      final controller =
          EdgeFuelSetupController(repository: repo, userId: 'u1');
      await Future<void>.delayed(Duration.zero);

      await controller.setGoal(NutritionGoal.maintain);
      await controller.setBodyInputs(
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
      );
      await controller.setActivityLevel(ActivityLevel.moderate);

      final ok = await controller.confirm();

      expect(ok, isTrue);
      expect(controller.draft.confirmed, isTrue);
      expect(controller.previewTarget?.status, NutritionTargetStatus.success);

      final storedTarget = await repo.watchTarget('u1').first;
      final storedDraft = await repo.watchProfileDraft('u1').first;
      expect(storedTarget?.status, NutritionTargetStatus.success);
      expect(storedDraft?.confirmed, isTrue);
    });

    test('confirm() returns false and persists nothing when incomplete',
        () async {
      final repo = InMemoryEdgeFuelRepository();
      final controller =
          EdgeFuelSetupController(repository: repo, userId: 'u1');
      await Future<void>.delayed(Duration.zero);

      final ok = await controller.confirm();

      expect(ok, isFalse);
      expect(controller.draft.confirmed, isFalse);
      expect(await repo.watchTarget('u1').first, isNull);
    });

    test('refreshPreview surfaces needsProfessionalReview without persisting',
        () async {
      final repo = InMemoryEdgeFuelRepository();
      final controller =
          EdgeFuelSetupController(repository: repo, userId: 'u1');
      await Future<void>.delayed(Duration.zero);

      await controller.setGoal(NutritionGoal.maintain);
      await controller.setBodyInputs(
        ageYears: 30,
        heightCm: 180,
        currentWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
      );
      await controller.setActivityLevel(ActivityLevel.moderate);
      await controller.setSafetyFlags(
        const NutritionSafetyFlags(kidneyDisease: true),
      );

      controller.refreshPreview();

      expect(controller.previewTarget?.status,
          NutritionTargetStatus.needsProfessionalReview);
      expect(await repo.watchTarget('u1').first, isNull);
    });
  });
}
