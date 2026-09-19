import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/portion_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/food_memory.dart';

FoodItem _chicken() => const FoodItem(
      id: 'chicken',
      name: 'Chicken breast',
      category: FoodCategory.protein,
      kcalPer100g: 113,
      proteinPer100g: 22.5,
      carbsPer100g: 0,
      fatPer100g: 2.6,
      fibrePer100g: 0,
      source: 'test',
    );

FoodLogEntry _entry(String name, {int kcal = 400}) => FoodLogEntry(
      id: 'e-$name-$kcal',
      name: name,
      notes: '',
      calories: kcal,
      proteinGrams: 30,
      carbGrams: 40,
      fatGrams: 10,
      loggedAt: DateTime(2026, 9, 19, 12),
    );

void main() {
  group('PortionCalculator', () {
    test('scales per-100 g values to the portion and rounds like the log', () {
      final n = PortionCalculator.forGrams(_chicken(), 150);
      expect(n.calories, 170); // 169.5
      expect(n.proteinGrams, 34); // 33.75
      expect(n.carbGrams, 0);
      expect(n.fatGrams, 4); // 3.9
    });

    test('a typo cannot log more than the portion ceiling', () {
      final capped = PortionCalculator.forGrams(_chicken(), 150000);
      final max =
          PortionCalculator.forGrams(_chicken(), PortionCalculator.maxGrams);
      expect(capped.calories, max.calories);
    });

    test('zero or negative grams log nothing', () {
      expect(PortionCalculator.forGrams(_chicken(), 0).calories, 0);
      expect(PortionCalculator.forGrams(_chicken(), -50).calories, 0);
    });

    test('labels grams, or units with their weight', () {
      expect(PortionCalculator.label(150), '150 g');
      expect(
        PortionCalculator.label(70, unitLabel: '1 slice', units: 2),
        '1 slice ×2 (70 g)',
      );
      expect(
        PortionCalculator.label(35, unitLabel: '1 slice', units: 1),
        '1 slice (35 g)',
      );
    });
  });

  group('FoodMemory', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('keeps distinct recents, newest first, with the latest portion',
        () async {
      final memory = FoodMemory('u1')
        ..remember(_entry('Oats'))
        ..remember(_entry('Rice'))
        ..remember(_entry('oats', kcal: 300));
      expect(memory.recent.map((e) => e.calories), [300, 400]);
      expect(memory.recent.first.name, 'oats');
    });

    test('caps the recent list', () {
      final memory = FoodMemory('u1');
      for (var i = 0; i < FoodMemory.recentLimit + 5; i++) {
        memory.remember(_entry('Food $i'));
      }
      expect(memory.recent, hasLength(FoodMemory.recentLimit));
      expect(memory.recent.first.name, 'Food ${FoodMemory.recentLimit + 4}');
    });

    test('survives a restart, per account', () async {
      final memory = FoodMemory('u1')..remember(_entry('Oats'));
      memory.toggleSaved(_entry('Rice'));
      await Future<void>.delayed(Duration.zero);

      final reloaded = FoodMemory('u1');
      await reloaded.load();
      expect(reloaded.recent.single.name, 'Oats');
      expect(reloaded.isSaved(_entry('rice')), isTrue);

      final other = FoodMemory('u2');
      await other.load();
      expect(other.recent, isEmpty);
    });
  });

  group('EdgeFuelController food memory', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Future<EdgeFuelController> signedIn() async {
      final controller =
          EdgeFuelController(repository: InMemoryEdgeFuelRepository())
            ..setUser('u1');
      await Future<void>.delayed(Duration.zero);
      return controller;
    }

    test('recents carry over to the next day', () async {
      final controller = await signedIn();
      await controller.addEntry(_entry('Chicken rice bowl'));

      controller.shiftDate(1);
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, isEmpty);
      expect(controller.recentFoods.single.name, 'Chicken rice bowl');
    });

    test('log again creates a fresh entry on the selected day', () async {
      final controller = await signedIn();
      await controller.addEntry(_entry('Oats'));
      controller.shiftDate(1);
      await Future<void>.delayed(Duration.zero);

      final logged = await controller.logAgain(controller.recentFoods.single);
      expect(controller.entries.single.id, logged.id);
      expect(logged.source, FoodLogSource.recent);
      expect(controller.consumedCalories, 400);
    });

    test('starring a food marks it saved across days and on today', () async {
      final controller = await signedIn();
      final oats = _entry('Oats');
      await controller.addEntry(oats);

      await controller.toggleSavedFood(oats);
      expect(controller.isSavedFood(oats), isTrue);
      expect(controller.entries.single.saved, isTrue);

      await controller.toggleSavedFood(oats);
      expect(controller.savedFoods, isEmpty);
      expect(controller.entries.single.saved, isFalse);
    });
  });
}
