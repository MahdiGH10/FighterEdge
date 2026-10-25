import '../../edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../../edge_fuel/domain/models/nutrition_enums.dart';
import '../domain/camp_screening.dart';

/// Old confirmed drafts without explicit screening evidence remain pending.
CampScreening campScreeningFromDraft(NutritionSetupDraft? draft) {
  if (draft == null ||
      draft.screeningStatus == NutritionScreeningStatus.unanswered) {
    return CampScreening.pending;
  }
  if (draft.screeningStatus == NutritionScreeningStatus.needsReview ||
      draft.safetyFlags.any) {
    return CampScreening.needsProfessionalReview;
  }
  return draft.confirmed ? CampScreening.cleared : CampScreening.pending;
}
