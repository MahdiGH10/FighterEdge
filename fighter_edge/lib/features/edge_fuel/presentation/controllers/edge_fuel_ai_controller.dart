import 'package:flutter/foundation.dart';

import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';
import '../../../../observability/telemetry.dart';

enum EdgeFuelAiRequestState { idle, loading, done }

/// Drives the two AI surfaces on the Plan screen — the Fighter Brief and
/// "Ask EdgeFuel Coach". Holds no stream subscriptions: each is a one-shot
/// request/response per tap, scoped to whichever screen creates it.
///
/// The two tasks load independently. Sharing one flag made generating a brief
/// put the Coach card into its loading state too, and vice versa.
class EdgeFuelAiController extends ChangeNotifier {
  EdgeFuelAiController({
    required EdgeFuelAiGateway gateway,
    Telemetry? telemetry,
  })  : _gateway = gateway,
        _telemetry = telemetry ?? const NoopTelemetry();

  final EdgeFuelAiGateway _gateway;
  final Telemetry _telemetry;

  bool _explaining = false;
  bool _briefing = false;
  bool _anyDone = false;
  EdgeFuelAiResult? _lastResult;
  EdgeFuelAiResult? _lastBriefResult;
  _LogBasis? _briefBasis;

  EdgeFuelAiRequestState get state => isLoading
      ? EdgeFuelAiRequestState.loading
      : _anyDone
          ? EdgeFuelAiRequestState.done
          : EdgeFuelAiRequestState.idle;
  EdgeFuelAiResult? get lastResult => _lastResult;
  EdgeFuelAiResult? get lastBriefResult => _lastBriefResult;
  bool get isLoading => _explaining || _briefing;
  bool get isExplaining => _explaining;
  bool get isBriefLoading => _briefing;

  /// True when a successful brief exists but the food log has changed since
  /// it was written — it may now point at a meal the athlete already ate.
  bool isBriefStale(NutritionDay? day) {
    final basis = _briefBasis;
    if (basis == null) return false;
    if (_lastBriefResult?.status != EdgeFuelAiStatus.success) return false;
    return basis != _LogBasis.of(day);
  }

  Future<void> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (_explaining) return;
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
    if (_briefing) return;
    // Captured as sent: anything logged while the request is in flight is
    // not in this brief, so it should read as stale when it lands.
    _briefBasis = _LogBasis.of(day);
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
    _setLoading(saveBrief, true);

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
      _telemetry.track(
        TelemetryEvent.aiRequestResult,
        parameters: {
          'task': 'fighter_brief',
          'status': _statusName(result.status),
        },
      );
    } else {
      _lastResult = result;
      _telemetry.track(
        TelemetryEvent.aiRequestResult,
        parameters: {
          'task': 'explain_plan',
          'status': _statusName(result.status),
        },
      );
    }
    _anyDone = true;
    _setLoading(saveBrief, false);
  }

  void _setLoading(bool brief, bool value) {
    if (brief) {
      _briefing = value;
    } else {
      _explaining = value;
    }
    notifyListeners();
  }
}

/// What the food log looked like when a brief was requested — enough to tell
/// that something was logged or removed since, without holding the log itself.
class _LogBasis {
  final int entryCount;
  final int calories;

  const _LogBasis(this.entryCount, this.calories);

  factory _LogBasis.of(NutritionDay? day) =>
      _LogBasis(day?.entries.length ?? 0, day?.totals.calories ?? 0);

  @override
  bool operator ==(Object other) =>
      other is _LogBasis &&
      other.entryCount == entryCount &&
      other.calories == calories;

  @override
  int get hashCode => Object.hash(entryCount, calories);
}

String _statusName(EdgeFuelAiStatus status) => switch (status) {
      EdgeFuelAiStatus.success => 'success',
      EdgeFuelAiStatus.quotaReached => 'quota_reached',
      EdgeFuelAiStatus.entitlementRequired => 'entitlement_required',
      EdgeFuelAiStatus.unavailable => 'unavailable',
    };
