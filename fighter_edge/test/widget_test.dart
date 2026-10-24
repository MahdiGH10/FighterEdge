import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

import 'helpers/test_harness.dart';

/// Smoke tests for the top-level app routing (AuthGate).
void main() {
  testWidgets('boots to the login screen when signed out', (tester) async {
    final repo = await makeRepo();
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Create account'), findsOneWidget);
  });

  testWidgets('boots straight to the dashboard when a session exists',
      (tester) async {
    final repo =
        await makeRepo(signedIn: true, plan: Plan.pro, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();

    expect(find.text('Ayoub'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('primary navigation exposes the core product areas',
      (tester) async {
    final repo =
        await makeRepo(signedIn: true, plan: Plan.free, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();

    // Home also has a Fuel action, so look inside the bottom nav only.
    Finder navLabel(String label) => find.descendant(
        of: find.byType(AppBottomNav), matching: find.text(label));

    expect(navLabel('Train'), findsOneWidget);
    expect(navLabel('Fuel'), findsOneWidget);
    expect(navLabel('Profile'), findsOneWidget);

    await tester.tap(navLabel('Train'));
    await tester.pumpAndSettle();
    expect(find.text('TRAIN'), findsOneWidget);

    await tester.tap(find.text('Drills'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a discipline'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('choose-path-striking')));
    await tester.pumpAndSettle();
    expect(find.text('Learn: The Jab'), findsOneWidget);

    await tester.tap(navLabel('Fuel'));
    await tester.pumpAndSettle();

    expect(find.text('FUEL'), findsOneWidget);
  });
}
