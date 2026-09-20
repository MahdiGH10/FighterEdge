import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
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
    test('replaces a pending brief with a structured successful brief',
        () async {
      const result = EdgeFuelAiResult.success(
        EdgeFuelAiResponse(
          summary: 'Today, protect your protein target.',
          brief: FighterBriefSections(
            nextAction: 'Log lunch.',
            mealSuggestion: 'Chicken and rice.',
            trainingTiming: 'Eat 90 minutes before training.',
            weeklyAdjustment: 'Hold this target for a week.',
          ),
        ),
      );
      final gateway = _RecordingGateway(briefResult: result);
      final telemetry = MemoryTelemetry();
      final controller = EdgeFuelCoachController(
        gateway: gateway,
        telemetry: telemetry,
      );

      await controller.requestBrief(target: _successTarget());

      expect(gateway.briefCalls, 1);
      expect(controller.isSending, isFalse);
      expect(controller.entries, hasLength(1));
      final brief = controller.entries.single as CoachBrief;
      expect(brief.result.status, EdgeFuelAiStatus.success);
      expect(brief.result.response!.brief!.nextAction, 'Log lunch.');
      expect(
        telemetry.records.single.parameters,
        {'task': 'fighter_brief', 'status': 'success'},
      );
    });

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
      expect(
          controller.entries.whereType<CoachPending>().single.isBrief, isFalse);

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

    test('marks only a successful brief stale after the food log changes',
        () async {
      final controller = EdgeFuelCoachController(gateway: _RecordingGateway());
      final now = DateTime(2026, 9, 19, 12);
      final empty = NutritionDay.empty(
        localDate: '2026-09-19',
        timeZone: 'UTC',
        now: now,
      );

      await controller.requestBrief(target: _successTarget(), day: empty);
      final brief = controller.entries.single as CoachBrief;
      expect(brief.isStaleFor(empty), isFalse);

      final logged = empty.copyWith(entries: [
        FoodLogEntry(
          id: 'meal-1',
          name: 'Fixture meal',
          notes: 'test fixture',
          calories: 500,
          proteinGrams: 30,
          carbGrams: 50,
          fatGrams: 10,
          loggedAt: now,
        ),
      ]);
      expect(brief.isStaleFor(logged), isTrue);
    });

    test('can be disposed while a request is pending', () async {
      final waiting = Completer<EdgeFuelAiResult>();
      final controller = EdgeFuelCoachController(
        gateway: _RecordingGateway(briefFuture: () => waiting.future),
      );

      final request = controller.requestBrief(target: _successTarget());
      controller.dispose();
      waiting.complete(_briefSuccess());

      await request;
      expect(controller.entries, hasLength(1));
    });
  });
}

EdgeFuelAiResult _chatSuccess() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(summary: 'Coach answer.'),
    );

EdgeFuelAiResult _briefSuccess() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(
        summary: 'Brief answer.',
        brief: FighterBriefSections(
          nextAction: 'Log your next meal.',
          mealSuggestion: 'Prioritize protein.',
          trainingTiming: 'Fuel consistently.',
          weeklyAdjustment: 'Keep your target steady.',
        ),
      ),
    );

class _RecordingGateway implements EdgeFuelAiGateway {
  _RecordingGateway({
    EdgeFuelAiResult? briefResult,
    EdgeFuelAiResult? chatResult,
    Future<EdgeFuelAiResult> Function()? briefFuture,
    Future<EdgeFuelAiResult> Function()? chatFuture,
  })  : _briefResult = briefResult ?? _briefSuccess(),
        _chatResult = chatResult ?? _chatSuccess(),
        _briefFuture = briefFuture,
        _chatFuture = chatFuture;

  final EdgeFuelAiResult _briefResult;
  final EdgeFuelAiResult _chatResult;
  final Future<EdgeFuelAiResult> Function()? _briefFuture;
  final Future<EdgeFuelAiResult> Function()? _chatFuture;

  int briefCalls = 0;
  int chatCalls = 0;
  String? lastMessage;
  List<ChatTurn> lastHistory = const [];

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) {
    briefCalls++;
    return _briefFuture?.call() ?? Future.value(_briefResult);
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
  }) {
    chatCalls++;
    lastMessage = userMessage;
    lastHistory = List.unmodifiable(history);
    return _chatFuture?.call() ?? Future.value(_chatResult);
  }
}

class _ThrowingGateway implements EdgeFuelAiGateway {
  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
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
  }) async {
    throw StateError('timeout');
  }
}
