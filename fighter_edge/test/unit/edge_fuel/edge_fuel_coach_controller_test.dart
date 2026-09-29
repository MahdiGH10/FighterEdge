import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_coach_controller.dart';
import 'package:fighter_edge/observability/telemetry.dart';

NutritionTarget _successTarget() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2500,
      proteinGrams: 150,
      carbGrams: 260,
      fatGrams: 80,
    );

void main() {
  group('EdgeFuelCoachController', () {
    test('sends the current message once and only prior turns as history',
        () async {
      final gateway = _RecordingGateway();
      final controller = EdgeFuelCoachController(gateway: gateway);

      await controller.sendMessage('Why this target?',
          target: _successTarget());
      await controller.sendMessage('What should I eat next?',
          target: _successTarget());

      expect(gateway.chatCalls, 2);
      expect(gateway.lastMessage, 'What should I eat next?');
      expect(gateway.lastHistory, hasLength(2));
      expect(gateway.lastHistory.first.role, ChatRole.user);
      expect(gateway.lastHistory.first.content, 'Why this target?');
      expect(gateway.lastHistory.last.role, ChatRole.assistant);
      expect(gateway.lastHistory.last.content, 'Coach answer.');
      expect(controller.entries.whereType<CoachUserMessage>(), hasLength(2));
      expect(controller.entries.whereType<CoachReply>(), hasLength(2));
    });

    test('forwards today to the gateway on a chat message', () async {
      final gateway = _RecordingGateway();
      final controller = EdgeFuelCoachController(gateway: gateway);
      final today = DailySnapshot.build(
        today: DateTime(2026, 10, 1),
        training: const [],
        plannedSessionsPerWeek: 4,
        goal: null,
        nutritionDays: const [],
        weights: const [],
      );

      await controller.sendMessage('Hi',
          target: _successTarget(), today: today);
      expect(gateway.lastToday, same(today));

      await controller.sendMessage('Hi again', target: _successTarget());
      expect(gateway.lastToday, isNull,
          reason: 'a call without today must not reuse the last one');
    });

    test('allows only one request while a response is in flight', () async {
      final waiting = Completer<EdgeFuelAiResult>();
      final gateway = _RecordingGateway(chatFuture: () => waiting.future);
      final controller = EdgeFuelCoachController(gateway: gateway);

      final first =
          controller.sendMessage('First question', target: _successTarget());
      final second =
          controller.sendMessage('Second question', target: _successTarget());

      expect(controller.isSending, isTrue);
      expect(gateway.chatCalls, 1);
      expect(controller.entries.whereType<CoachPending>(), hasLength(1));

      waiting.complete(_chatSuccess());
      await Future.wait([first, second]);

      expect(controller.entries.whereType<CoachUserMessage>(), hasLength(1));
      expect(controller.entries.whereType<CoachReply>(), hasLength(1));
    });

    test('turns a gateway failure into a visible recoverable reply', () async {
      final controller = EdgeFuelCoachController(gateway: _ThrowingGateway());

      await controller.sendMessage('Help', target: _successTarget());

      final reply = controller.entries.last as CoachReply;
      expect(reply.result.status, EdgeFuelAiStatus.unavailable);
      expect(controller.isSending, isFalse);
    });

    test('can be disposed while a request is pending', () async {
      final waiting = Completer<EdgeFuelAiResult>();
      final controller = EdgeFuelCoachController(
        gateway: _RecordingGateway(chatFuture: () => waiting.future),
      );

      final request = controller.sendMessage('Help', target: _successTarget());
      controller.dispose();
      waiting.complete(_chatSuccess());

      await request;
      expect(controller.entries, hasLength(2));
    });

    test('tracks the chat task and status', () async {
      final telemetry = MemoryTelemetry();
      final controller = EdgeFuelCoachController(
        gateway: _RecordingGateway(),
        telemetry: telemetry,
      );

      await controller.sendMessage('Hi', target: _successTarget());

      expect(
        telemetry.records.single.parameters,
        {'task': 'chat', 'status': 'success'},
      );
    });
  });
}

EdgeFuelAiResult _chatSuccess() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(summary: 'Coach answer.'),
    );

class _RecordingGateway implements EdgeFuelAiGateway {
  _RecordingGateway({
    EdgeFuelAiResult? chatResult,
    Future<EdgeFuelAiResult> Function()? chatFuture,
  })  : _chatResult = chatResult ?? _chatSuccess(),
        _chatFuture = chatFuture;

  final EdgeFuelAiResult _chatResult;
  final Future<EdgeFuelAiResult> Function()? _chatFuture;

  int chatCalls = 0;
  String? lastMessage;
  List<ChatTurn> lastHistory = const [];
  DailySnapshot? lastToday;

  @override
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) {
    return Future.value(const EdgeFuelAiResult.unavailable());
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
    DailySnapshot? today,
  }) {
    chatCalls++;
    lastMessage = userMessage;
    lastHistory = List.unmodifiable(history);
    lastToday = today;
    return _chatFuture?.call() ?? Future.value(_chatResult);
  }
}

class _ThrowingGateway implements EdgeFuelAiGateway {
  @override
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) async {
    throw StateError('timeout');
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
    DailySnapshot? today,
  }) async {
    throw StateError('timeout');
  }
}
