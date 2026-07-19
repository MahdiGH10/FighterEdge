import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/data/data_repository.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/models/meal.dart';
import 'package:fighter_edge/models/weight_entry.dart';
import 'package:fighter_edge/state/app_state.dart';

void main() {
  test('mealDateKey uses a stable calendar day key', () {
    expect(mealDateKey(DateTime(2026, 7, 20, 23, 59)), '2026-07-20');
  });

  test('in-memory repository keeps user data isolated', () async {
    final repo = InMemoryDataRepository();
    addTearDown(repo.dispose);

    await repo.addWeight('fighter-a', WeightEntry(DateTime(2026, 7, 20), 76));
    await repo.addWeight('fighter-b', WeightEntry(DateTime(2026, 7, 20), 82));

    final aWeights = await repo.watchWeights('fighter-a').first;
    final bWeights = await repo.watchWeights('fighter-b').first;

    expect(aWeights.last.kg, 76);
    expect(bWeights.last.kg, 82);
  });

  test('AppState persists weigh-ins through the repository', () async {
    final repo = InMemoryDataRepository();
    addTearDown(repo.dispose);

    final firstState = AppState(dataRepository: repo)..setUser('fighter-a');
    addTearDown(firstState.dispose);
    await Future<void>.delayed(Duration.zero);

    firstState.addWeight(DateTime(2026, 7, 20), 75.5);

    final secondState = AppState(dataRepository: repo)..setUser('fighter-a');
    addTearDown(secondState.dispose);
    await Future<void>.delayed(Duration.zero);

    expect(secondState.latestWeight, 75.5);
  });

  test('AppState persists today meal toggles through the repository', () async {
    final repo = InMemoryDataRepository();
    addTearDown(repo.dispose);

    final firstState = AppState(dataRepository: repo)..setUser('fighter-a');
    addTearDown(firstState.dispose);
    await Future<void>.delayed(Duration.zero);
    final breakfast = firstState.meals.firstWhere((m) => m.name == 'Breakfast');
    firstState.toggleMeal(breakfast);

    final secondState = AppState(dataRepository: repo)..setUser('fighter-a');
    addTearDown(secondState.dispose);
    await Future<void>.delayed(Duration.zero);

    final persistedBreakfast =
        secondState.meals.firstWhere((m) => m.name == 'Breakfast');
    expect(persistedBreakfast.eaten, isFalse);
  });

  test('Meal serializes without losing macro fields', () {
    final meal = Meal(
      name: 'Post Training',
      items: 'Rice, steak, fruit',
      calories: 820,
      protein: 55,
      carbs: 95,
      fats: 20,
      eaten: true,
    );

    expect(Meal.fromJson(meal.toJson()).protein, 55);
    expect(Meal.fromJson(meal.toJson()).eaten, isTrue);
  });
}
