import 'package:flutter/foundation.dart';

import '../../ai/edge_fuel_ai_gateway.dart';
import '../../ai/edge_fuel_ai_models.dart';
import '../../domain/models/nutrition_day.dart';
import '../../domain/models/nutrition_setup_draft.dart';
import '../../domain/models/nutrition_target.dart';
import '../../../daily_snapshot/domain/daily_snapshot.dart';
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

/// Shown in place of the eventual reply while a request is in flight.
class CoachPending extends EdgeFuelCoachEntry {
  const CoachPending();
}

/// Drives the EdgeFuel Coach conversation (master prompt §13): free-text
/// chat through the server's safety pipeline. The daily brief lives on Home
/// now (the Corner Brief); this is where the athlete asks about it.
///
/// One entry list, one loading flag, because a conversation is read top to
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

  Future<void> sendMessage(
    String text, {
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) async {
    final trimmed = text.trim();
    if (_sending || trimmed.isEmpty) return;
    // Capture context before adding this message: the message is sent in its
    // own field, so including it in history would duplicate it to the model.
    final history = _historyForRequest();
    _sending = true;
    _entries
      ..add(CoachUserMessage(trimmed))
      ..add(const CoachPending());
    notifyListeners();

    EdgeFuelAiResult result;
    try {
      result = await _gateway.sendChatMessage(
        target: target,
        day: day,
        preferences: preferences,
        userMessage: trimmed,
        history: history,
        today: today,
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
  /// question to make sense.
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

String _statusName(EdgeFuelAiStatus status) => switch (status) {
      EdgeFuelAiStatus.success => 'success',
      EdgeFuelAiStatus.quotaReached => 'quota_reached',
      EdgeFuelAiStatus.entitlementRequired => 'entitlement_required',
      EdgeFuelAiStatus.consentRequired => 'consent_required',
      EdgeFuelAiStatus.unavailable => 'unavailable',
    };
