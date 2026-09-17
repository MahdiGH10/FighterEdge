import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_ai_controller.dart';

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
  });
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
