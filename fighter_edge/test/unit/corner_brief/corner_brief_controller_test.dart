import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/corner_brief/domain/corner_brief.dart';
import 'package:fighter_edge/features/corner_brief/presentation/corner_brief_controller.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/observability/telemetry.dart';

final _target = NutritionTarget(
  status: NutritionTargetStatus.success,
  policyVersion: 1,
  calculatedAt: DateTime(2026, 1, 1),
  targetCalories: 2400,
  proteinGrams: 180,
  carbGrams: 280,
  fatGrams: 70,
);

DailySnapshot _snapshot(DateTime date, {int plannedSessions = 4}) =>
    DailySnapshot.build(
      today: date,
      training: const [],
      plannedSessionsPerWeek: plannedSessions,
      goal: null,
      nutritionDays: const [],
      weights: const [],
    );

EdgeFuelAiResult _success() => const EdgeFuelAiResult.success(
      EdgeFuelAiResponse(
        lines: [
          CornerBriefLine(topic: CornerTopic.fuel, text: 'Eat protein next.'),
          CornerBriefLine(topic: CornerTopic.training, text: 'Keep it easy.'),
          CornerBriefLine(topic: CornerTopic.recovery, text: 'Sleep early.'),
        ],
        requiresProfessionalReview: true,
      ),
    );

class _Gateway implements EdgeFuelAiGateway {
  _Gateway(this.next);

  Future<EdgeFuelAiResult> Function() next;
  int calls = 0;

  @override
  Future<EdgeFuelAiResult> generateCornerBrief({
    required NutritionTarget target,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    DailySnapshot? today,
  }) {
    calls++;
    return next();
  }

  @override
  Future<EdgeFuelAiResult> sendChatMessage({
    required NutritionTarget target,
    required String userMessage,
    NutritionDay? day,
    NutritionSetupDraft? preferences,
    List<ChatTurn> history = const [],
    DailySnapshot? today,
  }) =>
      throw UnimplementedError();
}

void main() {
  final monday = DateTime(2026, 9, 28, 9);
  final tuesday = DateTime(2026, 9, 29, 9);

  CornerBriefController make(_Gateway gateway, [MemoryTelemetry? telemetry]) {
    return CornerBriefController(gateway: gateway, telemetry: telemetry)
      ..setUser('u1');
  }

  test('a successful request keeps the lines for that day', () async {
    final telemetry = MemoryTelemetry();
    final controller = make(_Gateway(() async => _success()), telemetry);

    await controller.request(target: _target, today: _snapshot(monday));

    final brief = controller.briefFor(monday)!;
    expect(brief.lines, hasLength(3));
    expect(brief.requiresProfessionalReview, isTrue);
    expect(controller.lastStatusFor(monday), EdgeFuelAiStatus.success);
    expect(controller.isLoading, isFalse);
    expect(telemetry.records.single.parameters, {
      'task': 'corner_brief',
      'status': 'success',
      'automatic': 0,
      'rewarded': 0,
    });
  });

  test('yesterday has no brief or status today', () async {
    final controller = make(_Gateway(() async => _success()));
    await controller.request(target: _target, today: _snapshot(monday));

    expect(controller.briefFor(tuesday), isNull);
    expect(controller.lastStatusFor(tuesday), isNull);
  });

  test('a success without lines counts as unavailable', () async {
    final controller = make(_Gateway(
        () async => const EdgeFuelAiResult.success(EdgeFuelAiResponse())));

    await controller.request(target: _target, today: _snapshot(monday));

    expect(controller.briefFor(monday), isNull);
    expect(controller.lastStatusFor(monday), EdgeFuelAiStatus.unavailable);
  });

  test('a throwing gateway is unavailable, never an exception', () async {
    final controller = make(_Gateway(() async => throw StateError('offline')));

    await controller.request(target: _target, today: _snapshot(monday));

    expect(controller.lastStatusFor(monday), EdgeFuelAiStatus.unavailable);
    expect(controller.isLoading, isFalse);
  });

  test('a failed request keeps the brief already written', () async {
    final gateway = _Gateway(() async => _success());
    final controller = make(gateway);
    await controller.request(target: _target, today: _snapshot(monday));

    gateway.next = () async => const EdgeFuelAiResult.quotaReached();
    await controller.request(
        target: _target, today: _snapshot(monday, plannedSessions: 5));

    expect(controller.briefFor(monday), isNotNull);
    expect(controller.lastStatusFor(monday), EdgeFuelAiStatus.quotaReached);
  });

  test('only one request runs at a time', () async {
    final waiting = Completer<EdgeFuelAiResult>();
    final gateway = _Gateway(() => waiting.future);
    final controller = make(gateway);

    final first = controller.request(target: _target, today: _snapshot(monday));
    final second =
        controller.request(target: _target, today: _snapshot(monday));
    expect(controller.isLoading, isTrue);
    expect(gateway.calls, 1);

    waiting.complete(_success());
    await Future.wait([first, second]);
    expect(gateway.calls, 1);
  });

  group('shouldRefresh', () {
    test('is false until a brief exists', () {
      final controller = make(_Gateway(() async => _success()));
      expect(controller.shouldRefresh(today: monday, basis: 'x'), isFalse);
    });

    test('is true once something changed after a successful brief', () async {
      final controller = make(_Gateway(() async => _success()));
      final snapshot = _snapshot(monday);
      await controller.request(target: _target, today: snapshot);

      expect(
        controller.shouldRefresh(
            today: monday, basis: cornerBriefBasis(snapshot, null)),
        isFalse,
      );
      expect(controller.shouldRefresh(today: monday, basis: 'changed'), isTrue);
    });

    test('waits for Try again after a failure, so it cannot loop', () async {
      final gateway = _Gateway(() async => _success());
      final controller = make(gateway);
      await controller.request(target: _target, today: _snapshot(monday));
      gateway.next = () async => const EdgeFuelAiResult.unavailable();
      await controller.request(
          target: _target, today: _snapshot(monday, plannedSessions: 5));

      expect(
          controller.shouldRefresh(today: monday, basis: 'changed'), isFalse);
    });
  });

  test('a new account clears the brief and drops a late answer', () async {
    final waiting = Completer<EdgeFuelAiResult>();
    final gateway = _Gateway(() => waiting.future);
    final controller = make(gateway);

    final request =
        controller.request(target: _target, today: _snapshot(monday));
    controller.setUser('u2');
    waiting.complete(_success());
    await request;

    expect(controller.briefFor(monday), isNull);
    expect(controller.lastStatusFor(monday), isNull);
    expect(controller.isLoading, isFalse);
  });

  test('signing out clears a written brief', () async {
    final controller = make(_Gateway(() async => _success()));
    await controller.request(target: _target, today: _snapshot(monday));
    controller.setUser(null);

    expect(controller.briefFor(monday), isNull);
  });

  test('an automatic rewrite is marked so in telemetry', () async {
    final telemetry = MemoryTelemetry();
    final controller = make(_Gateway(() async => _success()), telemetry);

    await controller.request(
        target: _target, today: _snapshot(monday), automatic: true);

    expect(telemetry.records.single.parameters['automatic'], 1);
  });
}
