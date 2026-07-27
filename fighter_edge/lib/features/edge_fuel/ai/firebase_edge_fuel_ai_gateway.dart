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

  @override
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    try {
      final callable = _functions.httpsCallable('edgeFuelAiExplain');
      final result = await callable.call<Map<String, dynamic>>({
        'task': 'explainPlan',
        'target': target.toJson(),
        'day': day?.toJson(),
        if (preferences != null)
          'foodPreferences': {
            'dietType': preferences.dietType,
            'allergens': preferences.allergens,
            'dislikedFoods': preferences.dislikedFoods,
          },
      });

      final data = Map<String, dynamic>.from(result.data as Map);
      switch (data['status']) {
        case 'success':
          return EdgeFuelAiResult.success(EdgeFuelAiResponse.fromJson(
            Map<String, dynamic>.from(data['response'] as Map),
          ));
        case 'quotaReached':
          return const EdgeFuelAiResult.quotaReached();
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
