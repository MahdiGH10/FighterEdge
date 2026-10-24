import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('primary tabs survive 200 percent text with contrast settings',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1100);
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

    expect(find.text('Ayoub'), findsOneWidget);
    expectNoFlutterException(tester);

    Finder navLabel(String label) => find.descendant(
        of: find.byType(AppBottomNav), matching: find.text(label));

    await tester.tap(navLabel('Train'));
    await tester.pumpAndSettle();
    expect(find.text('TRAIN'), findsOneWidget);
    expectNoFlutterException(tester);

    await tester.tap(navLabel('Fuel'));
    await tester.pumpAndSettle();
    expect(find.text('FUEL'), findsOneWidget);
    final logFood = tester.getRect(find.byKey(const ValueKey('fuel-log-food')));
    final nav = tester.getRect(find.byType(AppBottomNav));
    expect(logFood.bottom, lessThanOrEqualTo(nav.top));
    expect(logFood.height, greaterThanOrEqualTo(48));
    expectNoFlutterException(tester);

    await tester.tap(navLabel('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('PROFILE'), findsOneWidget);
    expectNoFlutterException(tester);
  });
}

void expectNoFlutterException(WidgetTester tester) {
  final exception = tester.takeException();
  if (exception == null) return;
  if (exception is FlutterError) {
    fail(exception.toStringDeep());
  }
  fail(exception.toString());
}
