import '../../edge_fuel/domain/models/nutrition_setup_draft.dart';
import '../domain/camp_screening.dart';

/// A partially completed Fuel wizard is not evidence of reviewed health
/// answers. The confirmed draft is the only app-side source for this gate.
CampScreening campScreeningFromDraft(NutritionSetupDraft? draft) {
  if (draft?.confirmed != true) return CampScreening.pending;
  return draft!.safetyFlags.any
      ? CampScreening.needsProfessionalReview
      : CampScreening.cleared;
}
