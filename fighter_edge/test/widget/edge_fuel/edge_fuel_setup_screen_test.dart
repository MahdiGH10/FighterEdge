import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_plan_screen.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';

import '../../helpers/test_harness.dart';

void main() {
  group('EdgeFuelSetupScreen', () {
    testWidgets('complete setup for a maintenance goal reaches the Plan screen',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await tester.pumpWidget(wrapApp(
        const EdgeFuelSetupScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      // Step 1 — Goal.
      expect(find.text('Step 1 of 6 · Goal'), findsOneWidget);
      await tester.tap(find.text('Maintain'));
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step 2 — Body.
      expect(find.text('Step 2 of 6 · Body'), findsOneWidget);
      final textFields = find.byType(TextField);
      await tester.enterText(textFields.at(0), '30'); // age
      await tester.enterText(textFields.at(1), '180'); // height
      await tester.enterText(textFields.at(2), '80'); // current weight
      await tester.pump();
      await tester.tap(find.text('Equation A'));
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step 3 — Activity.
      expect(find.text('Step 3 of 6 · Activity'), findsOneWidget);
      await tester.tap(find.text('Moderate'));
      await tester.pump();
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step 4 — Training (default 4 days/week is auto-committed).
      expect(find.text('Step 4 of 6 · Training'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step 5 — Food preferences (optional, skip).
      expect(find.text('Step 5 of 6 · Food'), findsOneWidget);
      await tester.tap(find.text('NEXT'));
      await tester.pumpAndSettle();

      // Step 6 — Review.
      expect(find.text('Step 6 of 6 · Review'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('CONFIRM MY PLAN'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('CONFIRM MY PLAN'));
      await tester.pumpAndSettle();

      expect(find.byType(EdgeFuelPlanScreen), findsOneWidget);
      expect(find.text('DAILY TARGET'), findsOneWidget);

      final saved = await edgeFuelRepo.watchTarget(repo.currentUser!.id).first;
      expect(saved, isNotNull);
      expect(saved!.isSuccess, isTrue);
    });

    testWidgets('resumes on the saved step with previously entered values',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveProfileDraft(
        userId,
        const NutritionSetupDraft(
          currentStep: 2,
          goal: NutritionGoal.maintain,
          ageYears: 30,
          heightCm: 180,
          currentWeightKg: 80,
          equationProfile: EquationProfile.higherOffset,
        ),
      );

      await tester.pumpWidget(wrapApp(
        const EdgeFuelSetupScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.text('Step 3 of 6 · Activity'), findsOneWidget);
    });

    testWidgets('a clinical safety flag blocks the automated plan on review',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      final userId = repo.currentUser!.id;
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveProfileDraft(
        userId,
        const NutritionSetupDraft(
          currentStep: 5,
          goal: NutritionGoal.maintain,
          ageYears: 30,
          heightCm: 180,
          currentWeightKg: 80,
          equationProfile: EquationProfile.higherOffset,
          normalActivityLevel: ActivityLevel.moderate,
          weeklyTrainingDays: 4,
          safetyFlags: NutritionSafetyFlags(kidneyDisease: true),
        ),
      );

      await tester.pumpWidget(wrapApp(
        const EdgeFuelSetupScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(
          find.text('Please check with a professional first'), findsOneWidget);
      expect(find.text('CONFIRM MY PLAN'), findsNothing);
    });
  });
}
