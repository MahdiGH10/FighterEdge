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
///
/// Every tap/entry goes through [_tapVisible]/[_enterTextVisible] rather than
/// `tester.tap`/`tester.enterText` directly. The CI emulator's default
/// profile is a tiny 320x640 screen: a target further down a screen's
/// scrollable content can be either mounted-but-off-screen (a hit-test miss)
/// or, inside a lazily built list, not mounted at all (a "0 widgets found"
/// failure) — both seen for real on that emulator, in two different screens.
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
    await _tapVisible(tester, find.text('Create account'));

    // 2. Create an account.
    await _enterTextVisible(tester, find.byType(TextField).at(0), 'Ayoub');
    await _enterTextVisible(
        tester, find.byType(TextField).at(1), 'journey@test.com');
    await _enterTextVisible(
        tester, find.byType(TextField).at(2), 'journey-pass-1');
    await _enterTextVisible(
        tester, find.byType(TextField).at(3), 'journey-pass-1');
    await _tapVisible(tester, find.byType(Checkbox));
    await _tapVisible(tester, find.byType(PrimaryButton));

    // 3. The value pages come before any questions.
    expect(find.text('Your camp, organised.'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Fuel that matches the work.'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Watch the edge build.'), findsOneWidget);
    await _tapVisible(tester, find.text('BUILD MY PLAN'));

    // 4. Explicit consent comes before the first question about the body
    // (Art. 9 GDPR — audit finding, fixed in Phase 2 slice 2).
    expect(find.text('Your body data, your call'), findsOneWidget);
    expect(repo.currentUser!.hasHealthDataConsent, isFalse);
    await _tapVisible(tester, find.text('I AGREE'));
    expect(repo.currentUser!.hasHealthDataConsent, isTrue);

    // 5. Onboarding questions.
    expect(find.text('What should Fighter Edge build first?'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('What should EdgeFuel optimize for?'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Tell us your starting point.'), findsOneWidget);
    await _enterTextVisible(tester, find.byType(TextField).at(0), '28');
    await _enterTextVisible(tester, find.byType(TextField).at(1), '178');
    await _enterTextVisible(tester, find.byType(TextField).at(2), '77.2');
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Which formula fits your body?'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Outside the gym, how active are you?'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('How many days can you train?'), findsOneWidget);
    await _tapVisible(tester, find.text('CONTINUE'));
    expect(find.text('Your first plan is ready.'), findsOneWidget);
    await _tapVisible(tester, find.text('START MY PLAN'));

    // 6. Activation moment, then the dashboard.
    expect(find.text('Your first Fighter Edge plan is ready'), findsOneWidget);
    await _tapVisible(tester, find.text('OPEN DASHBOARD'));
    expect(find.text('DASHBOARD'), findsOneWidget);

    // 7. Profile -> the paid upgrade entry point. Computed from the nav
    // bar's own rect, so it needs no scrolling regardless of screen size.
    final navRect = tester.getRect(find.byType(AppBottomNav));
    await tester.tapAt(Offset(
      navRect.left + navRect.width * .875,
      navRect.center.dy,
    ));
    await tester.pumpAndSettle();
    await _tapVisible(tester, find.text('UPGRADE'));
    expect(find.text('Unlock your full edge'), findsOneWidget);

    // 8. A real store purchase completes, but the client never grants Pro:
    // only the trusted webhook does (a non-negotiable rule, not just a UI
    // choice — this is the property most worth an on-device regression).
    // A single pump (not pumpAndSettle) checks the state right after the
    // tap, before anything else runs.
    final monthlyPlan = find.text('MONTHLY - \$7.99');
    await _ensureVisible(tester, monthlyPlan);
    await tester.tap(monthlyPlan);
    await tester.pump();
    expect(billing.purchaseCount, 1);
    expect(repo.currentUser!.isPro, isFalse);

    // 9. Stands in for RevenueCat's webhook updating the account server-side.
    await repo.debugSetPlan(Plan.pro);
    await tester.pumpAndSettle();
    expect(repo.currentUser!.isPro, isTrue);
    expect(find.text("You're on Pro"), findsOneWidget);

    // 10. Sign out from Profile -> back to login.
    await _tapVisible(
        tester, find.byIcon(Icons.chevron_left)); // Paywall -> Profile.
    await _tapVisible(tester, find.byType(GhostButton));

    expect(find.text('Welcome back'), findsOneWidget);
  });
}

/// Scrolls [finder] into view (if it isn't already) before interacting with
/// it — see the file doc comment for why this is needed on every step here.
Future<void> _ensureVisible(WidgetTester tester, Finder finder) => tester
    .scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await _ensureVisible(tester, finder);
  // A brief real-time pause before tapping. Twice on CI, a tap right after
  // scrolling missed its target — a hit-test warning at the exact offset
  // Flutter reported for the widget, alongside the emulator's software
  // (SwiftShader) renderer logging a "Failed to find ColorBuffer" error in
  // the same instant. That reads as the raster thread lagging behind the
  // UI thread's belief that the scroll had settled, under the resource
  // pressure of a real, GPU-less emulator — not something `pumpAndSettle`
  // (which only waits for scheduled frames, not raster completion) can
  // wait out on its own.
  await tester.pump(const Duration(milliseconds: 300));
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enterTextVisible(
    WidgetTester tester, Finder finder, String text) async {
  await _ensureVisible(tester, finder);
  await tester.enterText(finder, text);
}
