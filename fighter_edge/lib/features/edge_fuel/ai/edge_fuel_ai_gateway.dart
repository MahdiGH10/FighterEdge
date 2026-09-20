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
  /// Premium structured brief: next action, meal suggestion, training
  /// timing, and weekly adjustment in one call.
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  });

  /// A free-text turn in the EdgeFuel Coach conversation. [history] is prior
  /// turns, oldest first, already bounded by the caller — the server also
  /// enforces its own bound, so a caller that forgets to trim is safe, not
  /// silently ignored.
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
  });
}
