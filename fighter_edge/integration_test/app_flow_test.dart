import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

/// Full end-to-end journey against the local backend, on a real device or
/// emulator: signup → consent → onboarding → dashboard → a store purchase
/// that does *not* grant Pro by itself → the simulated webhook grants it →
/// sign out.
///
/// This mirrors `test/flow/app_journey_test.dart` (the same flow, run
/// headless under `flutter test`) through onboarding, then diverges: that
/// test leaves billing unconfigured to prove the honest-waitlist path (audit
/// M-6); this one configures a [FakeBillingGateway] to exercise the actual
/// purchase button and the server-owned entitlement boundary instead, so the
/// two together cover both paths without duplicating either.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
      'signup, onboarding, a store purchase, the server grants Pro, sign out',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = LocalAuthRepository();
    await repo.init();
    final billing = FakeBillingGateway();

    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, billingGateway: billing),
    );
    await tester.pumpAndSettle();

    // 1. Land on login, go to signup.
    expect(find.text('Welcome back'), findsOneWidget);
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();

    // 2. Create an account.
    await tester.enterText(find.byType(TextField).at(0), 'Ayoub');
    await tester.enterText(find.byType(TextField).at(1), 'journey@test.com');
    await tester.enterText(find.byType(TextField).at(2), 'journey-pass-1');
    await tester.enterText(find.byType(TextField).at(3), 'journey-pass-1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();

    // 3. The value pages come before any questions.
    expect(find.text('Your camp, organised.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Fuel that matches the work.'), findsOneWidget);
    await tester.tap(find.text('CONTINUE'));
    await tester.pumpAndSettle();
    expect(find.text('Watch the edge build.'), findsOneWidget);
    await tester.tap(find.text('BUILD MY PLAN'));
    await tester.pumpAndSettle();

    // 4. Explicit consent comes before the first question about the body
    // (Art. 9 GDPR — audit finding, fixed in Phase 2 slice 2).
    expect(find.text('Your body data, your call'), findsOneWidget);
    expect(repo.currentUser!.hasHealthDataConsent, isFalse);
    await tester.tap(find.text('I AGREE'));
    await tester.pumpAndSettle();
    expect(repo.currentUser!.hasHealthDataConsent, isTrue);

    // 5. Onboarding questions.
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
    expect(find.text('Which formula fits your body?'), findsOneWidget);
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

    // 6. Activation moment, then the dashboard.
    expect(find.text('Your first Fighter Edge plan is ready'), findsOneWidget);
    await tester.tap(find.text('OPEN DASHBOARD'));
    await tester.pumpAndSettle();
    expect(find.text('DASHBOARD'), findsOneWidget);

    // 7. Profile -> the paid upgrade entry point.
    final navRect = tester.getRect(find.byType(AppBottomNav));
    await tester.tapAt(Offset(
      navRect.left + navRect.width * .875,
      navRect.center.dy,
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('UPGRADE'));
    await tester.pumpAndSettle();
    expect(find.text('Unlock your full edge'), findsOneWidget);

    // 8. A real store purchase completes, but the client never grants Pro:
    // only the trusted webhook does (a non-negotiable rule, not just a UI
    // choice — this is the property most worth an on-device regression).
    await tester.tap(find.text('MONTHLY - \$7.99'));
    await tester.pump();
    expect(billing.purchaseCount, 1);
    expect(repo.currentUser!.isPro, isFalse);

    // 9. Stands in for RevenueCat's webhook updating the account server-side.
    await repo.debugSetPlan(Plan.pro);
    await tester.pumpAndSettle();
    expect(repo.currentUser!.isPro, isTrue);
    expect(find.text("You're on Pro"), findsOneWidget);

    // 10. Sign out from Profile -> back to login.
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
