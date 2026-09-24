import 'package:cloud_functions/cloud_functions.dart';

import '../domain/models/nutrition_day.dart';
import '../domain/models/nutrition_setup_draft.dart';
import '../domain/models/nutrition_target.dart';
import 'edge_fuel_ai_gateway.dart';
import 'edge_fuel_ai_models.dart';

/// Calls the `edgeFuelAiExplain` Cloud Function — the only place this app
/// is allowed to reach an AI provider from (master prompt §13). Firebase
/// attaches the caller's ID token automatically; the backend does the
/// auth/quota/schema/safety pipeline and this class only has to interpret
/// its typed result.
class FirebaseEdgeFuelAiGateway implements EdgeFuelAiGateway {
  FirebaseEdgeFuelAiGateway({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  final FirebaseFunctions _functions;
  // Covers the server's worst case: one model call (25s) plus one retry of a
  // rejected answer, which the function only starts inside its first 18s.
  static const _requestTimeout = Duration(seconds: 45);

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) {
    return _call(
      task: 'fighterBrief',
      target: target,
      day: day,
      preferences: preferences,
    );
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
  }) {
    return _call(
      task: 'chat',
      target: target,
      day: day,
      preferences: preferences,
      userMessage: userMessage,
      history: history,
    );
  }

  Future<EdgeFuelAiResult> _call({
    required String task,
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    String? userMessage,
    List<ChatTurn> history = const [],
  }) async {
    try {
      final callable = _functions.httpsCallable('edgeFuelAiExplain');
      final result = await callable.call<Map<String, dynamic>>({
        'task': task,
        'target': target.toJson(),
        'day': day?.toJson(),
        if (preferences != null)
          'foodPreferences': {
            'dietType': preferences.dietType,
            'allergens': preferences.allergens,
            'dislikedFoods': preferences.dislikedFoods,
          },
        if (userMessage != null) 'userMessage': userMessage,
        if (history.isNotEmpty)
          'history': [for (final turn in history) turn.toJson()],
      }).timeout(_requestTimeout);

      final data = Map<String, dynamic>.from(result.data as Map);
      switch (data['status']) {
        case 'success':
          return EdgeFuelAiResult.success(EdgeFuelAiResponse.fromJson(
            Map<String, dynamic>.from(data['response'] as Map),
          ));
        case 'quotaReached':
          return const EdgeFuelAiResult.quotaReached();
        case 'entitlementRequired':
          return const EdgeFuelAiResult.entitlementRequired();
        case 'consentRequired':
          return const EdgeFuelAiResult.consentRequired();
        default:
          return const EdgeFuelAiResult.unavailable();
      }
    } on FirebaseFunctionsException {
      return const EdgeFuelAiResult.unavailable();
    } catch (_) {
      return const EdgeFuelAiResult.unavailable();
    }
  }
}
