import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/fighter_brief_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fighter_brief_preview.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';

void main() {
  final target = NutritionTarget(
    status: NutritionTargetStatus.success,
    policyVersion: 1,
    calculatedAt: DateTime(2026, 1, 1),
    targetCalories: 2400,
    proteinGrams: 180,
    carbGrams: 280,
    fatGrams: 70,
  );

  NutritionDay dayWith({
    int calories = 0,
    int protein = 0,
    int carbs = 0,
    int fats = 0,
    bool consumed = true,
  }) {
    final entry = FoodLogEntry(
      id: 'test-entry',
      name: 'Test meal',
      notes: 'fixture',
      calories: calories,
      proteinGrams: protein,
      carbGrams: carbs,
      fatGrams: fats,
      consumed: consumed,
      loggedAt: DateTime(2026, 1, 1),
    );
    return NutritionDay(
      localDate: '2026-01-01',
      timeZone: 'UTC',
      entries: [entry],
      totals: FoodLogTotals.fromEntries([entry]),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
  }

  test('returns an honest needs-more-data state without a target', () {
    final preview = FighterBriefCalculator.calculate(target: null, day: null);

    expect(preview.status, FighterBriefStatus.needsMoreData);
    expect(preview.isReady, isFalse);
    expect(preview.nextAction, contains('Log a meal'));
  });

  test('requires a consumed meal before presenting a personalized preview', () {
    final preview = FighterBriefCalculator.calculate(
      target: target,
      day: dayWith(consumed: false),
    );

    expect(preview.status, FighterBriefStatus.needsMoreData);
    expect(preview.caloriesRemaining, isNull);
  });

  test('prioritizes protein when the protein gap is meaningful', () {
    final preview = FighterBriefCalculator.calculate(
      target: target,
      day: dayWith(calories: 700, protein: 80, carbs: 240, fats: 55),
    );

    expect(preview.status, FighterBriefStatus.ready);
    expect(preview.focus, FighterBriefFocus.protein);
    expect(preview.proteinRemaining, 100);
    expect(preview.nextAction, contains('protein'));
  });

  test('prioritizes carbohydrates after protein is mostly covered', () {
    final preview = FighterBriefCalculator.calculate(
      target: target,
      day: dayWith(calories: 900, protein: 170, carbs: 120, fats: 40),
    );

    expect(preview.focus, FighterBriefFocus.carbohydrates);
    expect(preview.carbohydratesRemaining, 160);
    expect(preview.nextAction, contains('carbohydrates'));
  });

  test('clamps consumed-over-target values and reports on-track status', () {
    final preview = FighterBriefCalculator.calculate(
      target: target,
      day: dayWith(calories: 2600, protein: 200, carbs: 310, fats: 80),
    );

    expect(preview.focus, FighterBriefFocus.onTrack);
    expect(preview.caloriesRemaining, 0);
    expect(preview.proteinRemaining, 0);
    expect(preview.carbohydratesRemaining, 0);
    expect(preview.fatsRemaining, 0);
  });

  test('rejects a success target with incomplete nutrient fields', () {
    final incomplete = NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2400,
      proteinGrams: null,
      carbGrams: 280,
      fatGrams: 70,
    );

    final preview = FighterBriefCalculator.calculate(
      target: incomplete,
      day: dayWith(calories: 500, protein: 20, carbs: 40, fats: 10),
    );

    expect(preview.status, FighterBriefStatus.needsMoreData);
  });
}
