import 'package:flutter/foundation.dart';

import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';
import '../../../../observability/telemetry.dart';

/// One entry in the EdgeFuel Coach conversation, in display order.
sealed class EdgeFuelCoachEntry {
  const EdgeFuelCoachEntry();
}

/// What the athlete typed.
class CoachUserMessage extends EdgeFuelCoachEntry {
  final String text;
  const CoachUserMessage(this.text);
}

/// A free-text reply from the coach.
class CoachReply extends EdgeFuelCoachEntry {
  final EdgeFuelAiResult result;
  const CoachReply(this.result);
}

/// The structured Fighter Brief, requested as its own turn. Keeps the log
/// snapshot it was written against so it can tell the athlete when a later
/// meal has made it stale, without holding the log itself.
class CoachBrief extends EdgeFuelCoachEntry {
  final EdgeFuelAiResult result;
  final _LogBasis _basis;

  CoachBrief(this.result, NutritionDay? dayWhenRequested)
      : _basis = _LogBasis.of(dayWhenRequested);

  bool isStaleFor(NutritionDay? currentDay) {
    if (result.status != EdgeFuelAiStatus.success) return false;
    return _basis != _LogBasis.of(currentDay);
  }
}

/// Shown in place of the eventual reply while a request is in flight.
class CoachPending extends EdgeFuelCoachEntry {
  final bool isBrief;
  const CoachPending({required this.isBrief});
}

/// Drives the single merged EdgeFuel Coach surface (master prompt §13): a
/// running conversation that can open with the structured Fighter Brief and
/// continue as free-text chat, both through the same server safety pipeline.
///
/// Replaces the old two-button split (`generateFighterBrief` /
/// `explainPlan` fired independently from two cards on the Plan screen) —
/// one entry list, one loading flag, because a conversation is read top to
/// bottom and only one request is ever in flight at a time.
class EdgeFuelCoachController extends ChangeNotifier {
  EdgeFuelCoachController({
    required EdgeFuelAiGateway gateway,
    Telemetry? telemetry,
  })  : _gateway = gateway,
        _telemetry = telemetry ?? const NoopTelemetry();

  final EdgeFuelAiGateway _gateway;
  final Telemetry _telemetry;

  /// The server enforces its own bound independently; this just keeps the
  /// request small on the way out. Cost and prompt-injection surface both
  /// grow with unbounded history.
  static const _maxHistoryTurns = 8;

  final List<EdgeFuelCoachEntry> _entries = [];
  bool _sending = false;
  bool _disposed = false;

  List<EdgeFuelCoachEntry> get entries => List.unmodifiable(_entries);
  bool get isSending => _sending;
  bool get hasBrief => _entries.any((e) => e is CoachBrief);

  Future<void> requestBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    if (_sending) return;
    _sending = true;
    _entries.add(const CoachPending(isBrief: true));
    notifyListeners();

    EdgeFuelAiResult result;
    try {
      result = await _gateway.generateFighterBrief(
        target: target,
        day: day,
        preferences: preferences,
      );
    } catch (_) {
      result = const EdgeFuelAiResult.unavailable();
    }

    if (_disposed) return;

    _entries
      ..removeLast()
      ..add(CoachBrief(result, day));
    _telemetry.track(TelemetryEvent.aiRequestResult, parameters: {
      'task': 'fighter_brief',
      'status': _statusName(result.status),
    });
    _sending = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    String text, {
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    final trimmed = text.trim();
    if (_sending || trimmed.isEmpty) return;
    // Capture context before adding this message: the message is sent in its
    // own field, so including it in history would duplicate it to the model.
    final history = _historyForRequest();
    _sending = true;
    _entries
      ..add(CoachUserMessage(trimmed))
      ..add(const CoachPending(isBrief: false));
    notifyListeners();

    EdgeFuelAiResult result;
    try {
      result = await _gateway.sendChatMessage(
        target: target,
        day: day,
        preferences: preferences,
        userMessage: trimmed,
        history: history,
      );
    } catch (_) {
      result = const EdgeFuelAiResult.unavailable();
    }

    if (_disposed) return;

    _entries
      ..removeLast()
      ..add(CoachReply(result));
    _telemetry.track(TelemetryEvent.aiRequestResult, parameters: {
      'task': 'chat',
      'status': _statusName(result.status),
    });
    _sending = false;
    notifyListeners();
  }

  /// The last few turns as plain text, oldest first — enough for a follow-up
  /// question to make sense. A brief collapses to one assistant line (its
  /// summary) so "why is that my next action" still has something to refer
  /// to, without repeating all four sections into every later request.
  List<ChatTurn> _historyForRequest() {
    final turns = <ChatTurn>[];
    for (final entry in _entries) {
      switch (entry) {
        case CoachUserMessage(:final text):
          turns.add(ChatTurn(role: ChatRole.user, content: text));
        case CoachReply(:final result):
          final summary = result.response?.summary;
          if (summary != null && summary.isNotEmpty) {
            turns.add(ChatTurn(role: ChatRole.assistant, content: summary));
          }
        case CoachBrief(:final result):
          final summary = result.response?.summary;
          if (summary != null && summary.isNotEmpty) {
            turns.add(ChatTurn(role: ChatRole.assistant, content: summary));
          }
        case CoachPending():
          break;
      }
    }
    if (turns.length <= _maxHistoryTurns) return turns;
    return turns.sublist(turns.length - _maxHistoryTurns);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
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
      EdgeFuelAiStatus.consentRequired => 'consent_required',
      EdgeFuelAiStatus.unavailable => 'unavailable',
    };
