import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/observability/telemetry.dart';

void main() {
  group('EdgeFuelController daily logging', () {
    test('adds, toggles, edits, and deletes entries', () async {
      final repo = InMemoryEdgeFuelRepository();
      final telemetry = MemoryTelemetry();
      final controller =
          EdgeFuelController(repository: repo, telemetry: telemetry)
            ..setUser('u1');
      await Future<void>.delayed(Duration.zero);

      final entry = FoodLogEntry(
        id: 'food-1',
        name: 'Rice bowl',
        notes: 'Lunch',
        calories: 700,
        proteinGrams: 45,
        carbGrams: 90,
        fatGrams: 12,
        loggedAt: DateTime(2026, 7, 27, 12),
      );

      await controller.addEntry(entry);
      expect(controller.entries.single.name, 'Rice bowl');
      expect(controller.consumedCalories, 700);
      expect(telemetry.records.single.event, TelemetryEvent.mealLogged);
      expect(telemetry.records.single.parameters, {'first_today': 1});

      await controller.toggleEntry(entry);
      expect(controller.entries.single.consumed, isFalse);
      expect(controller.consumedCalories, 0);

      await controller.updateEntry(entry.copyWith(name: 'Big rice bowl'));
      expect(controller.entries.single.name, 'Big rice bowl');

      await controller.deleteEntry(controller.entries.single);
      expect(controller.entries, isEmpty);

      controller.dispose();
    });

    test('meal event has a daily-first flag and only follows a saved add',
        () async {
      final repo = InMemoryEdgeFuelRepository();
      final telemetry = MemoryTelemetry();
      final controller =
          EdgeFuelController(repository: repo, telemetry: telemetry)
            ..setUser('u1');
      await Future<void>.delayed(Duration.zero);

      FoodLogEntry meal(String id) => FoodLogEntry(
            id: id,
            name: 'Private meal name',
            notes: 'Private note',
            calories: 400,
            proteinGrams: 20,
            carbGrams: 40,
            fatGrams: 12,
            loggedAt: DateTime.now(),
          );

      await controller.addEntry(meal('one'));
      await controller.addEntry(meal('two'));
      expect(telemetry.records.map((r) => r.event),
          everyElement(TelemetryEvent.mealLogged));
      expect(telemetry.records.map((r) => r.parameters).toList(), [
        {'first_today': 1},
        {'first_today': 0},
      ]);
      controller.dispose();
    });

    test('switches historical dates without mixing entries', () async {
      final repo = InMemoryEdgeFuelRepository();
      final controller = EdgeFuelController(repository: repo)..setUser('u1');
      await Future<void>.delayed(Duration.zero);

      await controller.addEntry(FoodLogEntry(
        id: 'today-food',
        name: 'Today meal',
        notes: '',
        calories: 400,
        proteinGrams: 20,
        carbGrams: 40,
        fatGrams: 12,
        loggedAt: DateTime.now(),
      ));
      expect(controller.entries.single.name, 'Today meal');

      controller.shiftDate(-1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.entries, isEmpty);

      await controller.addEntry(FoodLogEntry(
        id: 'yesterday-food',
        name: 'Yesterday meal',
        notes: '',
        calories: 500,
        proteinGrams: 30,
        carbGrams: 50,
        fatGrams: 14,
        loggedAt: DateTime.now().subtract(const Duration(days: 1)),
      ));
      expect(controller.entries.single.name, 'Yesterday meal');

      controller.shiftDate(1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.entries.single.name, 'Today meal');

      controller.dispose();
    });
  });
}
