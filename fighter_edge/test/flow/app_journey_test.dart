import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

/// Headless end-to-end journey (runs under `flutter test`). The same flow lives
/// in integration_test/app_flow_test.dart for on-device / CI driver runs.
void main() {
  testWidgets(
      'signup -> hit Pro gate -> checkout intent stays locked -> sign out',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await makeRepo();
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();

    // Login -> signup.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // Create the account.
    await tester.enterText(find.byType(TextField).at(0), 'Ayoub');
    await tester.enterText(find.byType(TextField).at(1), 'journey@test.com');
    await tester.enterText(find.byType(TextField).at(2), 'secret1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // First-run setup creates a clean personal starting point.
    expect(find.text('What are you training for?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Where are you starting from?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('How many days can you train?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Add a starting weight?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '77.2');
    await tester.tap(find.text('START FRESH'));
    await tester.pumpAndSettle();

    // Dashboard.
    expect(find.text('DASHBOARD'), findsOneWidget);

    // More -> Settings -> paid upgrade entry point.
    final navRect = tester.getRect(find.byType(AppBottomNav));
    await tester.tapAt(Offset(
      navRect.left + navRect.width * .875,
      navRect.center.dy,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upgrade to Pro'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock your full edge'), findsOneWidget);

    // Billing is not wired yet, so checkout intent must not grant Pro from
    // the client.
    await tester.tap(find.byType(PrimaryButton)); // Join Pro Waitlist.
    await tester.pumpAndSettle();
    expect(find.textContaining('Payments are not active yet'), findsOneWidget);

    // Pro remains locked until a trusted billing backend grants it.
    expect(repo.currentUser!.isPro, isFalse);

    // Sign out from Profile -> back to login.
    await tester.tap(find.byIcon(Icons.chevron_left)); // Paywall -> Settings.
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.chevron_left)); // Settings -> More.
    await tester.pumpAndSettle();
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    final signOut = find.byType(GhostButton);
    await tester.scrollUntilVisible(signOut, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
