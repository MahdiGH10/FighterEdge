import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

/// Switching tabs used to rebuild the page from scratch: Home's scroll
/// position, Train's sub-tab and every other selection reset each time
/// (audit 2026-10-04, Phase 0.6).
void main() {
  Future<void> openApp(WidgetTester tester) async {
    final repo =
        await makeRepo(signedIn: true, plan: Plan.free, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();
  }

  Future<void> goTo(WidgetTester tester, String tab) async {
    await tester.tap(find.text(tab));
    await tester.pumpAndSettle();
  }

  testWidgets('Train keeps its sub-tab across a tab switch', (tester) async {
    await openApp(tester);

    await goTo(tester, 'Train');
    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a discipline'), findsOneWidget);

    await goTo(tester, 'Fuel');
    await goTo(tester, 'Train');

    expect(find.text('Choose a discipline'), findsOneWidget);
  });

  testWidgets('Home keeps its scroll position across a tab switch',
      (tester) async {
    await openApp(tester);

    ScrollPosition homeScroll() =>
        tester.state<ScrollableState>(find.byType(Scrollable).first).position;

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    final scrolled = homeScroll().pixels;
    expect(scrolled, greaterThan(0));

    await goTo(tester, 'Profile');
    await goTo(tester, 'Home');

    expect(homeScroll().pixels, scrolled);
  });

  testWidgets('a tab that was never opened is not built', (tester) async {
    await openApp(tester);

    // Fuel's header is only in the tree once Fuel has been opened.
    expect(find.text('NUTRITION', skipOffstage: false), findsNothing);
    await goTo(tester, 'Fuel');
    expect(find.text('NUTRITION'), findsOneWidget);
  });
}
