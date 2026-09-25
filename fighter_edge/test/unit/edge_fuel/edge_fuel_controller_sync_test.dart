import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/observability/error_reporter.dart';
import 'package:fighter_edge/observability/telemetry.dart';

/// A repository whose target stream is controlled directly, so a test can
/// inject an error without going through Firestore.
class _FlakyEdgeFuelRepository extends InMemoryEdgeFuelRepository {
  final targetController = StreamController<NutritionTarget?>.broadcast();

  @override
  Stream<NutritionTarget?> watchTarget(String userId) =>
      targetController.stream;
}

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2400,
      proteinGrams: 180,
      carbGrams: 260,
      fatGrams: 75,
    );

/// Firestore's write future completes only when the server acknowledges it,
/// which never happens offline. This repository never acknowledges.
class _OfflineRepository extends InMemoryEdgeFuelRepository {
  final pending = <Completer<void>>[];

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) {
    final ack = Completer<void>();
    pending.add(ack);
    return ack.future;
  }
}

class _RejectingRepository extends InMemoryEdgeFuelRepository {
  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) async {
    throw StateError('permission-denied');
  }
}

class _RecordingReporter implements ErrorReporter {
  final reasons = <String?>[];

  @override
  void report(Object error, StackTrace stack,
          {String? reason, bool fatal = false}) =>
      reasons.add(reason);
}

FoodLogEntry _meal(String id) => FoodLogEntry(
      id: id,
      name: 'Oats',
      notes: '',
      calories: 350,
      proteinGrams: 12,
      carbGrams: 60,
      fatGrams: 6,
      loggedAt: DateTime.now(),
    );

void main() {
  test('offline: the entry shows at once while storage has not confirmed',
      () async {
    final repo = _OfflineRepository();
    final controller = EdgeFuelController(repository: repo)..setUser('u1');
    await Future<void>.delayed(Duration.zero);

    var confirmed = false;
    unawaited(controller.addEntry(_meal('a')).then((_) => confirmed = true));
    await Future<void>.delayed(Duration.zero);

    expect(controller.entries.map((e) => e.id), ['a']);
    expect(controller.consumedCalories, 350);
    expect(confirmed, isFalse, reason: 'no server acknowledgement yet');

    repo.pending.single.complete();
    await Future<void>.delayed(Duration.zero);
    expect(confirmed, isTrue);
    controller.dispose();
  });

  test('a rejected write is reported, flagged, and never thrown', () async {
    final reporter = _RecordingReporter();
    final telemetry = MemoryTelemetry();
    final controller = EdgeFuelController(
      repository: _RejectingRepository(),
      telemetry: telemetry,
      errorReporter: reporter,
    )..setUser('u1');
    await Future<void>.delayed(Duration.zero);

    await controller.addEntry(_meal('a'));
    await controller.deleteEntry(controller.entries.single);

    expect(controller.lastSaveFailed, isTrue);
    expect(reporter.reasons, everyElement('nutrition_day_save_failed'));
    expect(reporter.reasons, hasLength(2));
    expect(telemetry.records, isEmpty,
        reason: 'a meal is only counted once storage confirms it');
    controller.dispose();
  });

  test('a later successful save clears the failure flag', () async {
    var reject = true;
    final repo = _TogglingRepository(() => reject);
    final controller = EdgeFuelController(repository: repo)..setUser('u1');
    await Future<void>.delayed(Duration.zero);

    await controller.addEntry(_meal('a'));
    expect(controller.lastSaveFailed, isTrue);

    reject = false;
    await controller.addEntry(_meal('b'));
    expect(controller.lastSaveFailed, isFalse);
    controller.dispose();
  });

  test(
      'a target stream error keeps the last known target instead of '
      'crashing or hanging (A-5)', () async {
    final repo = _FlakyEdgeFuelRepository();
    final controller = EdgeFuelController(repository: repo)..setUser('u1');
    await Future<void>.delayed(Duration.zero);

    final target = _target();
    repo.targetController.add(target);
    await Future<void>.delayed(Duration.zero);
    expect(controller.target, target);

    repo.targetController.addError(Exception('offline'));
    await Future<void>.delayed(Duration.zero);

    // The subscription survives the error; the last known target remains.
    expect(controller.target, target);
    controller.dispose();
    await repo.targetController.close();
  });
}

class _TogglingRepository extends InMemoryEdgeFuelRepository {
  _TogglingRepository(this._reject);
  final bool Function() _reject;

  @override
  Future<void> saveNutritionDay(String userId, NutritionDay day) async {
    if (_reject()) throw StateError('unavailable');
    return super.saveNutritionDay(userId, day);
  }
}
