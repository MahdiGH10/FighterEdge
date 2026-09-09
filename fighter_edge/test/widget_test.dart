import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/billing/subscription.dart';

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

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
  });

  testWidgets('primary navigation exposes only working MVP areas',
      (tester) async {
    final repo =
        await makeRepo(signedIn: true, plan: Plan.free, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();

    expect(find.text('Technique'), findsNothing);
    expect(find.text('Fuel'), findsOneWidget);

    await tester.tap(find.text('Fuel'));
    await tester.pumpAndSettle();

    expect(find.text('NUTRITION'), findsOneWidget);
  });
}
