import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_target.dart';
import 'edge_fuel_ai_models.dart';

/// The single seam the Flutter app depends on for AI features (master
/// prompt §13: "The Flutter client must depend only on `EdgeFuelAiGateway`").
/// The app never calls an AI provider directly and never holds a provider
/// key — every implementation of this interface talks to our own backend
/// boundary (or nothing at all, for the fake).
abstract class EdgeFuelAiGateway {
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  });
}
