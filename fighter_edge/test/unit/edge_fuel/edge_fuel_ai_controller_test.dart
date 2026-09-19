import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_ai_controller.dart';
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
  group('EdgeFuelAiController', () {
    test('goes idle -> loading -> done(success) around a gateway call',
        () async {
      final gateway = FakeEdgeFuelAiGateway(
        nextResult: () => const EdgeFuelAiResult.success(
          EdgeFuelAiResponse(summary: 'Looking good.'),
        ),
      );
      final controller = EdgeFuelAiController(gateway: gateway);

      expect(controller.state, EdgeFuelAiRequestState.idle);

      final future = controller.explainPlan(target: _successTarget());
      expect(controller.isLoading, isTrue);

      await future;

      expect(controller.state, EdgeFuelAiRequestState.done);
      expect(controller.lastResult?.status, EdgeFuelAiStatus.success);
      expect(controller.lastResult?.response?.summary, 'Looking good.');
    });

    test('surfaces quotaReached without throwing', () async {
      final gateway = FakeEdgeFuelAiGateway(
        nextResult: () => const EdgeFuelAiResult.quotaReached(),
      );
      final controller = EdgeFuelAiController(gateway: gateway);

      await controller.explainPlan(target: _successTarget());

      expect(controller.lastResult?.status, EdgeFuelAiStatus.quotaReached);
      expect(controller.lastResult?.response, isNull);
    });

    test('surfaces unavailable without throwing', () async {
      final gateway = FakeEdgeFuelAiGateway(
        nextResult: () => const EdgeFuelAiResult.unavailable(),
      );
      final controller = EdgeFuelAiController(gateway: gateway);

      await controller.explainPlan(target: _successTarget());

      expect(controller.lastResult?.status, EdgeFuelAiStatus.unavailable);
    });

    test('keeps the premium Fighter Brief result separate from the coach',
        () async {
      final controller = EdgeFuelAiController(
        gateway: const FakeEdgeFuelAiGateway(),
      );

      await controller.generateFighterBrief(target: _successTarget());

      expect(controller.lastResult, isNull);
      expect(controller.lastBriefResult?.status, EdgeFuelAiStatus.success);
      expect(controller.lastBriefResult?.response?.brief, isNotNull);
    });

    test('records only the typed task and result status', () async {
      final telemetry = MemoryTelemetry();
      final controller = EdgeFuelAiController(
        gateway: const FakeEdgeFuelAiGateway(),
        telemetry: telemetry,
      );

      await controller.generateFighterBrief(target: _successTarget());

      expect(telemetry.records, hasLength(1));
      expect(telemetry.records.single.event, TelemetryEvent.aiRequestResult);
      expect(
        telemetry.records.single.parameters,
        {'task': 'fighter_brief', 'status': 'success'},
      );
    });

    test('turns a thrown timeout into a recoverable unavailable state',
        () async {
      final controller = EdgeFuelAiController(gateway: _ThrowingGateway());

      await controller.explainPlan(target: _successTarget());

      expect(controller.state, EdgeFuelAiRequestState.done);
      expect(controller.lastResult?.status, EdgeFuelAiStatus.unavailable);
    });

    test('ignores a second call while one is already loading', () async {
      var callCount = 0;
      final gateway = FakeEdgeFuelAiGateway(
        nextResult: () {
          callCount++;
          return const EdgeFuelAiResult.success(
            EdgeFuelAiResponse(summary: 'ok'),
          );
        },
      );
      final controller = EdgeFuelAiController(gateway: gateway);

      final first = controller.explainPlan(target: _successTarget());
      final second = controller.explainPlan(target: _successTarget());
      await Future.wait([first, second]);

      expect(callCount, 1);
    });

    test('the brief and the coach load independently', () async {
      final brief = Completer<EdgeFuelAiResult>();
      final controller = EdgeFuelAiController(
        gateway: _ManualGateway(brief: brief),
      );

      final pending = controller.generateFighterBrief(target: _successTarget());
      expect(controller.isBriefLoading, isTrue);
      expect(controller.isExplaining, isFalse);

      // The coach is still usable while the brief is being written.
      await controller.explainPlan(target: _successTarget());
      expect(controller.lastResult?.status, EdgeFuelAiStatus.success);
      expect(controller.isBriefLoading, isTrue);

      brief.complete(const EdgeFuelAiResult.unavailable());
      await pending;
      expect(controller.isLoading, isFalse);
      expect(controller.state, EdgeFuelAiRequestState.done);
    });

    test('a brief goes stale once the log changes, and only then', () async {
      final controller = EdgeFuelAiController(
        gateway: const FakeEdgeFuelAiGateway(),
      );
      final now = DateTime(2026, 9, 19, 12);
      final empty = NutritionDay.empty(
        localDate: '2026-09-19',
        timeZone: 'UTC',
        now: now,
      );

      expect(controller.isBriefStale(empty), isFalse);
      await controller.generateFighterBrief(
        target: _successTarget(),
        day: empty,
      );
      expect(controller.isBriefStale(empty), isFalse);

      final logged = empty.copyWith(entries: [
        FoodLogEntry(
          id: 'meal-1',
          name: 'fixture',
          notes: 'test fixture',
          calories: 500,
          proteinGrams: 30,
          carbGrams: 50,
          fatGrams: 10,
          loggedAt: now,
        ),
      ]);
      expect(controller.isBriefStale(logged), isTrue);
    });

    test('a failed brief is never reported as stale', () async {
      final controller = EdgeFuelAiController(
        gateway: FakeEdgeFuelAiGateway(
          nextResult: () => const EdgeFuelAiResult.unavailable(),
        ),
      );
      await controller.generateFighterBrief(target: _successTarget());

      final day = NutritionDay.empty(
        localDate: '2026-09-19',
        timeZone: 'UTC',
        now: DateTime(2026, 9, 19),
      ).copyWith(entries: [
        FoodLogEntry(
          id: 'meal-1',
          name: 'fixture',
          notes: 'test fixture',
          calories: 500,
          proteinGrams: 30,
          carbGrams: 50,
          fatGrams: 10,
          loggedAt: DateTime(2026, 9, 19),
        ),
      ]);
      expect(controller.isBriefStale(day), isFalse);
    });
  });
}

class _ManualGateway implements EdgeFuelAiGateway {
  final Completer<EdgeFuelAiResult> brief;
  _ManualGateway({required this.brief});

  @override
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async =>
      const EdgeFuelAiResult.success(EdgeFuelAiResponse(summary: 'ok'));

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) =>
      brief.future;
}

class _ThrowingGateway implements EdgeFuelAiGateway {
  @override
  Future<EdgeFuelAiResult> explainPlan({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    throw StateError('timeout');
  }

  @override
  Future<EdgeFuelAiResult> generateFighterBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
  }) async {
    throw StateError('timeout');
  }
}
