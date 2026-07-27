import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/models/meal.dart';

void main() {
  group('InMemoryEdgeFuelRepository', () {
    test('watchProfileDraft emits null before any save', () async {
      final repo = InMemoryEdgeFuelRepository();
      expect(await repo.watchProfileDraft('u1').first, isNull);
    });

    test('saveProfileDraft round-trips and is observable on the stream',
        () async {
      final repo = InMemoryEdgeFuelRepository();
      const draft = NutritionSetupDraft(
        goal: NutritionGoal.maintain,
        ageYears: 28,
        heightCm: 170,
        currentWeightKg: 65,
        equationProfile: EquationProfile.lowerOffset,
        normalActivityLevel: ActivityLevel.light,
      );

      final emissions = <NutritionSetupDraft?>[];
      final sub = repo.watchProfileDraft('u1').listen(emissions.add);
      await repo.saveProfileDraft('u1', draft);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions.last, isNotNull);
      expect(emissions.last!.goal, NutritionGoal.maintain);
      expect(emissions.last!.currentWeightKg, 65);
    });

    test('saveTarget round-trips through watchTarget', () async {
      final repo = InMemoryEdgeFuelRepository();
      final target = NutritionTarget(
        status: NutritionTargetStatus.success,
        policyVersion: 1,
        calculatedAt: DateTime(2026, 1, 1),
        targetCalories: 2200,
      );

      await repo.saveTarget('u1', target);
      final stored = await repo.watchTarget('u1').first;

      expect(stored, isNotNull);
      expect(stored!.targetCalories, 2200);
      expect(stored.status, NutritionTargetStatus.success);
    });

    test('one user never observes another user\'s draft or target', () async {
      final repo = InMemoryEdgeFuelRepository();
      const draftA = NutritionSetupDraft(
        goal: NutritionGoal.loseFat,
        ageYears: 40,
        heightCm: 160,
        currentWeightKg: 90,
        targetWeightKg: 80,
        equationProfile: EquationProfile.higherOffset,
        normalActivityLevel: ActivityLevel.veryLow,
        goalPace: GoalPace.gentle,
      );
      const draftB = NutritionSetupDraft(
        goal: NutritionGoal.gainMuscle,
        ageYears: 22,
        heightCm: 190,
        currentWeightKg: 70,
        targetWeightKg: 78,
        equationProfile: EquationProfile.lowerOffset,
        normalActivityLevel: ActivityLevel.veryHigh,
        goalPace: GoalPace.gainStandard,
      );

      await repo.saveProfileDraft('userA', draftA);
      await repo.saveProfileDraft('userB', draftB);

      final storedA = await repo.watchProfileDraft('userA').first;
      final storedB = await repo.watchProfileDraft('userB').first;

      expect(storedA!.goal, NutritionGoal.loseFat);
      expect(storedB!.goal, NutritionGoal.gainMuscle);
      expect(storedA.currentWeightKg, isNot(storedB.currentWeightKg));
    });

    test('watchNutritionDay emits an empty day before logging', () async {
      final repo = InMemoryEdgeFuelRepository();
      final day =
          await repo.watchNutritionDay('u1', DateTime(2026, 7, 27)).first;

      expect(day.localDate, '2026-07-27');
      expect(day.entries, isEmpty);
      expect(day.totals.calories, 0);
    });

    test('saveNutritionDay persists totals and notifies watchers', () async {
      final repo = InMemoryEdgeFuelRepository();
      final emissions = <NutritionDay>[];
      final sub = repo
          .watchNutritionDay('u1', DateTime(2026, 7, 27))
          .listen(emissions.add);

      final day = NutritionDay.empty(
        localDate: '2026-07-27',
        timeZone: 'local',
        now: DateTime(2026, 7, 27),
      ).copyWith(entries: [
        FoodLogEntry(
          id: 'food-1',
          name: 'Eggs',
          notes: 'Breakfast',
          calories: 300,
          proteinGrams: 24,
          carbGrams: 2,
          fatGrams: 20,
          loggedAt: DateTime(2026, 7, 27, 8),
        ),
      ]);

      await repo.saveNutritionDay('u1', day);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(emissions.last.entries.single.name, 'Eggs');
      expect(emissions.last.totals.calories, 300);
    });

    test('legacy meals migrate once into nutrition day format', () async {
      final repo = InMemoryEdgeFuelRepository();
      await repo.seedLegacyMeals('u1', DateTime(2026, 7, 27), [
        Meal(
          id: 'breakfast',
          name: 'Breakfast',
          items: 'Eggs and toast',
          calories: 620,
          protein: 45,
          carbs: 55,
          fats: 20,
          eaten: true,
        ),
      ]);

      final first =
          await repo.watchNutritionDay('u1', DateTime(2026, 7, 27)).first;
      final second =
          await repo.watchNutritionDay('u1', DateTime(2026, 7, 27)).first;

      expect(first.migratedFromLegacyMeals, isTrue);
      expect(first.entries.single.id, 'legacy-breakfast');
      expect(first.totals.calories, 620);
      expect(second.entries.length, 1);
    });
  });
}
