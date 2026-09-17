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
  EdgeFuelAiResult? _lastBriefResult;

  EdgeFuelAiRequestState get state => _state;
  EdgeFuelAiResult? get lastResult => _lastResult;
  EdgeFuelAiResult? get lastBriefResult => _lastBriefResult;
  bool get isLoading => _state == EdgeFuelAiRequestState.loading;

  Future<void> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (isLoading) return;
    await _run(
      () => _gateway.explainPlan(
        target: target,
        day: day,
        preferences: preferences,
      ),
      saveBrief: false,
    );
  }

  Future<void> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (isLoading) return;
    await _run(
      () => _gateway.generateFighterBrief(
        target: target,
        day: day,
        preferences: preferences,
      ),
      saveBrief: true,
    );
  }

  Future<void> _run(
    Future<EdgeFuelAiResult> Function() request, {
    required bool saveBrief,
  }) async {
    _state = EdgeFuelAiRequestState.loading;
    notifyListeners();

    EdgeFuelAiResult result;
    try {
      result = await request();
    } catch (_) {
      // A timeout/provider outage must release the button and render the
      // recoverable unavailable state instead of leaving the screen spinning.
      result = const EdgeFuelAiResult.unavailable();
    }

    if (saveBrief) {
      _lastBriefResult = result;
    } else {
      _lastResult = result;
    }
    _state = EdgeFuelAiRequestState.done;
    notifyListeners();
  }
}
