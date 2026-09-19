import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/data/data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_fuel_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2000,
      proteinGrams: 150,
      carbGrams: 200,
      fatGrams: 60,
    );

NutritionDay _day(String date, List<(int, int)> meals, {bool eaten = true}) {
  final base = NutritionDay.empty(
    localDate: date,
    timeZone: 'UTC',
    now: DateTime(2026, 9, 14),
  );
  return base.copyWith(entries: [
    for (final (i, (kcal, protein)) in meals.indexed)
      FoodLogEntry(
        id: '$date-$i',
        name: 'meal $i',
        notes: '',
        calories: kcal,
        proteinGrams: protein,
        carbGrams: 0,
        fatGrams: 0,
        consumed: eaten,
        loggedAt: DateTime(2026, 9, 14),
      ),
  ]);
}

void main() {
  group('WeeklyFuelCalculator', () {
    test('classifies each day against a ±10% band', () {
      final s = WeeklyFuelCalculator.summarise(target: _target(), days: [
        _day('2026-09-14', [(2000, 150)]), // on target
        _day('2026-09-15', [(1790, 120)]), // under (89.5%)
        _day('2026-09-16', [(2210, 140)]), // over (110.5%)
        _day('2026-09-17', []), // not logged
        _day('2026-09-18', [(1800, 135)]), // on target at exactly 90%
      ]);
      expect(s.days.map((d) => d.status), [
        FuelDayStatus.onTarget,
        FuelDayStatus.under,
        FuelDayStatus.over,
        FuelDayStatus.notLogged,
        FuelDayStatus.onTarget,
      ]);
      expect(s.loggedDays, 4);
      expect(s.onTargetDays, 2);
    });

    test('protein hit means 90% of target on a logged day', () {
      final s = WeeklyFuelCalculator.summarise(target: _target(), days: [
        _day('2026-09-14', [(2000, 135)]), // 90% -> hit
        _day('2026-09-15', [(2000, 134)]), // just under
      ]);
      expect(s.proteinHitDays, 1);
    });

    test('averages only logged days; unlogged is unknown, not zero', () {
      final s = WeeklyFuelCalculator.summarise(target: _target(), days: [
        _day('2026-09-14', [(1800, 100)]),
        _day('2026-09-15', []),
        _day('2026-09-16', [(2200, 100)]),
      ]);
      expect(s.averageCalories, 2000);

      final empty = WeeklyFuelCalculator.summarise(
          target: _target(), days: [_day('2026-09-14', [])]);
      expect(empty.averageCalories, isNull);
    });

    test('entries planned but not eaten do not count as logged', () {
      final s = WeeklyFuelCalculator.summarise(
        target: _target(),
        days: [
          _day('2026-09-14', [(2000, 150)], eaten: false)
        ],
      );
      expect(s.days.single.status, FuelDayStatus.notLogged);
    });
  });

  group('EdgeFuelController.loadThisWeek', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('returns Monday through today, including empty days', () async {
      final repo = InMemoryEdgeFuelRepository();
      final wednesday = DateTime(2026, 9, 16, 15);
      await repo.saveNutritionDay(
        'u1',
        _day(mealDateKey(DateTime(2026, 9, 14)), [(1900, 140)]),
      );
      final controller = EdgeFuelController(repository: repo)..setUser('u1');
      await Future<void>.delayed(Duration.zero);

      final week = await controller.loadThisWeek(now: wednesday);
      expect(week.map((d) => d.localDate),
          ['2026-09-14', '2026-09-15', '2026-09-16']);
      expect(week.first.totals.calories, 1900);
      expect(week[1].entries, isEmpty);
      controller.dispose();
    });
  });
}
