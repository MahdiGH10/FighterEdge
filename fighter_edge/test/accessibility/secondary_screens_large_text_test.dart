import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../helpers/test_harness.dart';
import 'large_text_test.dart' show expectNoFlutterException;

/// The screens the primary-tab test does not reach. Each is opened at 200%
/// text with bold text, high contrast and reduced motion on a small (320 x
/// 640) phone, the worst case the design contract names. A layout overflow
/// or any other framework error fails the test.
const _routes = <String, String>{
  'paywall': AppRoutes.paywall,
  'settings': AppRoutes.settings,
  'weight tracker': AppRoutes.weightTracker,
  'round timer': AppRoutes.roundTimer,
  'fuel plan': AppRoutes.fuelPlan,
  'fuel setup': AppRoutes.fuelSetup,
  'fuel coach': AppRoutes.fuelCoach,
  'fuel recipes': AppRoutes.fuelRecipes,
  'fight setup': AppRoutes.fightSetup,
};

void main() {
  for (final entry in _routes.entries) {
    testWidgets('${entry.key} survives 200 percent text and high contrast',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2.0;
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(
        boldText: true,
        highContrast: true,
        disableAnimations: true,
      );
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      });

      final repo =
          await makeRepo(signedIn: true, plan: Plan.free, onboarded: true);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();
      // The dashboard behind the route is covered by its own slice; only the
      // screen under test may fail here.
      tester.takeException();

      final context = tester.element(find.byType(Scaffold).first);
      GoRouter.of(context).push(entry.value);
      await tester.pumpAndSettle();

      final router = GoRouter.of(context);
      expect(
        router.routerDelegate.currentConfiguration.last.matchedLocation,
        entry.value,
        reason: 'the route must open, not redirect',
      );
      expectNoFlutterException(tester);
    });
  }
}
