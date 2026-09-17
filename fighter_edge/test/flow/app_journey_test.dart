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
    expect(find.text('What should Fighter Edge build first?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('What should EdgeFuel optimize for?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Tell us your starting point.'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(0), '28');
    await tester.enterText(find.byType(TextField).at(1), '178');
    await tester.enterText(find.byType(TextField).at(2), '77.2');
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Outside the gym, how active are you?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('How many days can you train?'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Your first plan is ready.'), findsOneWidget);
    await tester.tap(find.text('START MY PLAN'));
    await tester.pumpAndSettle();

    // Activation moment: the saved target is explained before entering the app.
    expect(find.text('Your first Fighter Edge plan is ready'), findsOneWidget);
    expect(find.textContaining('kcal'), findsWidgets);
    await tester.tap(find.text('OPEN DASHBOARD'));
    await tester.pumpAndSettle();

    // Dashboard.
    expect(find.text('DASHBOARD'), findsOneWidget);

    // Profile -> paid upgrade entry point.
    final navRect = tester.getRect(find.byType(AppBottomNav));
    await tester.tapAt(Offset(
      navRect.left + navRect.width * .875,
      navRect.center.dy,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPGRADE'));
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
    await tester.tap(find.byIcon(Icons.chevron_left)); // Paywall -> Profile.
    await tester.pumpAndSettle();
    final signOut = find.byType(GhostButton);
    await tester.scrollUntilVisible(signOut, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(signOut);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });
}
