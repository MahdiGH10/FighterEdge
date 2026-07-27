import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';

void main() {
  group('EdgeFuelController daily logging', () {
    test('adds, toggles, edits, and deletes entries', () async {
      final repo = InMemoryEdgeFuelRepository();
      final controller = EdgeFuelController(repository: repo)..setUser('u1');
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

      await controller.toggleEntry(entry);
      expect(controller.entries.single.consumed, isFalse);
      expect(controller.consumedCalories, 0);

      await controller.updateEntry(entry.copyWith(name: 'Big rice bowl'));
      expect(controller.entries.single.name, 'Big rice bowl');

      await controller.deleteEntry(controller.entries.single);
      expect(controller.entries, isEmpty);

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
