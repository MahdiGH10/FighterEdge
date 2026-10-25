import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/presentation/camp_screening_from_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing or unfinished Fuel setup cannot clear camp screening', () {
    expect(campScreeningFromDraft(null), CampScreening.pending);
    expect(
      campScreeningFromDraft(const NutritionSetupDraft(ageYears: 30)),
      CampScreening.pending,
    );
  });

  test('an old confirmed draft with unanswered flags stays pending', () {
    expect(
      campScreeningFromDraft(
        const NutritionSetupDraft(ageYears: 30, confirmed: true),
      ),
      CampScreening.pending,
    );
  });

  test('explicitly completed screening clears a confirmed adult draft', () {
    expect(
      campScreeningFromDraft(const NutritionSetupDraft(
        ageYears: 30,
        confirmed: true,
        screeningStatus: NutritionScreeningStatus.completed,
      )),
      CampScreening.cleared,
    );
  });

  test('any confirmed clinical flag requires professional review', () {
    expect(
      campScreeningFromDraft(
        const NutritionSetupDraft(
          ageYears: 30,
          confirmed: true,
          screeningStatus: NutritionScreeningStatus.needsReview,
          safetyFlags: NutritionSafetyFlags(kidneyDisease: true),
        ),
      ),
      CampScreening.needsProfessionalReview,
    );
  });

  test('a reviewed flag needs professional review before final confirmation',
      () {
    expect(
      campScreeningFromDraft(const NutritionSetupDraft(
        screeningStatus: NutritionScreeningStatus.needsReview,
        safetyFlags: NutritionSafetyFlags(kidneyDisease: true),
      )),
      CampScreening.needsProfessionalReview,
    );
  });
}
