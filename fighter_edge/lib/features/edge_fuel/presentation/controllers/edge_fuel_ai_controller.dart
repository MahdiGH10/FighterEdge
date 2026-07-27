import 'package:flutter/foundation.dart';

import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';

enum EdgeFuelAiRequestState { idle, loading, done }

/// Drives the "Ask EdgeFuel Coach" action on the Plan screen. Holds no
/// stream subscriptions — it's a one-shot request/response per tap, scoped
/// to whichever screen creates it.
class EdgeFuelAiController extends ChangeNotifier {
  EdgeFuelAiController({required EdgeFuelAiGateway gateway})
      : _gateway = gateway;

  final EdgeFuelAiGateway _gateway;

  EdgeFuelAiRequestState _state = EdgeFuelAiRequestState.idle;
  EdgeFuelAiResult? _lastResult;

  EdgeFuelAiRequestState get state => _state;
  EdgeFuelAiResult? get lastResult => _lastResult;
  bool get isLoading => _state == EdgeFuelAiRequestState.loading;

  Future<void> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (isLoading) return;
    _state = EdgeFuelAiRequestState.loading;
    notifyListeners();

    final result = await _gateway.explainPlan(
      target: target,
      day: day,
      preferences: preferences,
    );

    _lastResult = result;
    _state = EdgeFuelAiRequestState.done;
    notifyListeners();
  }
}
