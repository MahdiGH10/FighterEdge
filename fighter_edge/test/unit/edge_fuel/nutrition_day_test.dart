import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';

void main() {
  group('NutritionDay', () {
    test('totals include only consumed entries', () {
      final day = NutritionDay.empty(
        localDate: '2026-07-27',
        timeZone: 'local',
        now: DateTime(2026, 7, 27),
      ).copyWith(entries: [
        FoodLogEntry(
          id: 'a',
          name: 'Breakfast',
          notes: 'Oats',
          calories: 500,
          proteinGrams: 30,
          carbGrams: 60,
          fatGrams: 10,
          loggedAt: DateTime(2026, 7, 27, 8),
        ),
        FoodLogEntry(
          id: 'b',
          name: 'Planned snack',
          notes: 'Later',
          calories: 250,
          proteinGrams: 20,
          carbGrams: 20,
          fatGrams: 8,
          consumed: false,
          loggedAt: DateTime(2026, 7, 27, 14),
        ),
      ]);

      expect(day.totals.calories, 500);
      expect(day.totals.proteinGrams, 30);
      expect(day.loggingCoverage, 'partial');
    });

    test('round trips through json', () {
      final original = NutritionDay.empty(
        localDate: '2026-07-27',
        timeZone: 'Africa/Tunis',
        now: DateTime(2026, 7, 27),
      ).copyWith(entries: [
        FoodLogEntry(
          id: 'meal-1',
          name: 'Chicken rice',
          notes: 'Post training',
          calories: 720,
          proteinGrams: 55,
          carbGrams: 82,
          fatGrams: 16,
          saved: true,
          loggedAt: DateTime(2026, 7, 27, 19),
        ),
      ]);

      final restored = NutritionDay.fromJson(original.toJson());

      expect(restored.localDate, '2026-07-27');
      expect(restored.entries.single.name, 'Chicken rice');
      expect(restored.entries.single.saved, isTrue);
      expect(restored.totals.calories, 720);
    });
  });
}
