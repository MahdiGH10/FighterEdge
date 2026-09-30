import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';
import 'package:fighter_edge/screens/onboarding/plan_ready_view.dart';
import 'package:fighter_edge/widgets/brand_logo.dart';
import '../helpers/test_harness.dart';

void main() {
  for (final scale in [1.0, 2.0]) {
    testWidgets('onboarding retains a choice after header back at scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
          MediaQuery(
              data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: true),
              child: const OnboardingScreen()),
          repo: repo));
      await tester.pumpAndSettle();
      expect(find.byType(BrandLogo), findsOneWidget);
      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(find.byType(BrandLogo), findsNothing);
      await Scrollable.ensureVisible(
          tester.element(find.text('Improve technique')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Improve technique'));
      await tester.scrollUntilVisible(find.text('Continue'), 250);
      await Scrollable.ensureVisible(tester.element(find.text('Continue')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.byTooltip('Back'), -250);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      final chip = tester.widget<ChoiceChip>(find.ancestor(
          of: find.text('Improve technique'),
          matching: find.byType(ChoiceChip)));
      expect(chip.selected, isTrue);
      expect(tester.takeException(), isNull);
    });
    testWidgets('plan ready puts dashboard before Pro and fits scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final repo = await makeRepo(signedIn: true);
      var opened = false;
      await tester.pumpWidget(wrapApp(
          MediaQuery(
              data: MediaQueryData(
                  size: const Size(320, 568),
                  textScaler: TextScaler.linear(scale)),
              child: PlanReadyView(
                  plan: CompletedOnboardingPlan(
                      target: NutritionTarget(
                          status: NutritionTargetStatus.success,
                          policyVersion: 1,
                          calculatedAt: DateTime(2026, 9, 23),
                          targetCalories: 2400,
                          proteinGrams: 150,
                          carbGrams: 270,
                          fatGrams: 80),
                      nutritionGoal: NutritionGoal.loseFat,
                      campGoal: 'Improve technique',
                      level: 'Beginner',
                      days: 4),
                  isBusy: false,
                  onOpenDashboard: () => opened = true,
                  onViewFuelPlan: () {},
                  onViewPro: () {})),
          repo: repo));
      await tester.pumpAndSettle();
      expect(find.byType(BrandLogo), findsNothing);
      await tester.scrollUntilVisible(find.text('Open dashboard'), 250);
      final actionY = tester.getTopLeft(find.text('Open dashboard')).dy;
      if (find.text('More training tools with Pro').evaluate().isNotEmpty) {
        expect(
            actionY,
            lessThan(tester
                .getTopLeft(find.text('More training tools with Pro'))
                .dy));
      }
      await Scrollable.ensureVisible(
          tester.element(find.text('Open dashboard')),
          alignment: .5);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open dashboard'));
      await tester.pump();
      expect(opened, isTrue);
      await tester.scrollUntilVisible(find.text('See Pro options'), 250);
      expect(tester.takeException(), isNull);
    });
  }
}
