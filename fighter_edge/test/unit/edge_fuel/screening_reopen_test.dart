import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/presentation/camp_screening_from_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('reopened pre-screening target stays hidden until answers are reviewed',
      () async {
    final repo = InMemoryEdgeFuelRepository();
    const oldDraft = NutritionSetupDraft(
      confirmed: true,
      ageYears: 30,
      safetyFlags: NutritionSafetyFlags(),
    );
    await repo.saveProfileDraft('u', oldDraft);
    await repo.saveTarget(
      'u',
      NutritionTarget(
        status: NutritionTargetStatus.success,
        policyVersion: 1,
        calculatedAt: DateTime(2026, 10, 25),
        targetCalories: 2400,
      ),
    );
    final controller = EdgeFuelController(repository: repo)..setUser('u');
    await Future<void>.delayed(Duration.zero);
    expect(
        controller.draft?.screeningStatus, NutritionScreeningStatus.unanswered);
    expect(controller.target, isNull);
    expect(controller.hasUsableTarget, isFalse);
    expect(campScreeningFromDraft(controller.draft), CampScreening.pending);

    await repo.saveProfileDraft(
      'u',
      oldDraft.copyWith(screeningStatus: NutritionScreeningStatus.completed),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.target?.targetCalories, 2400);
    expect(campScreeningFromDraft(controller.draft), CampScreening.cleared);

    await repo.saveProfileDraft(
      'u',
      oldDraft.copyWith(
        screeningStatus: NutritionScreeningStatus.needsReview,
        safetyFlags: const NutritionSafetyFlags(kidneyDisease: true),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(controller.target, isNull);
    expect(campScreeningFromDraft(controller.draft),
        CampScreening.needsProfessionalReview);
    controller.dispose();
  });

  test('an old serialized profile cannot clear the nutrition safety gate', () {
    final profile = NutritionProfile.fromJson(const {
      'goal': 'maintain',
      'ageYears': 30,
      'heightCm': 180,
      'currentWeightKg': 80,
      'equationProfile': 'higherOffset',
      'activityLevel': 'moderate',
      'safetyFlags': {'kidneyDisease': false},
    });
    expect(profile.screeningStatus, NutritionScreeningStatus.unanswered);
  });
}
