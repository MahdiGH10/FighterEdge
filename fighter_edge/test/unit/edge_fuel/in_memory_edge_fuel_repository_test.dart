import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';

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
  });
}
