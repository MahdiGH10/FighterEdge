import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  _paywallComplianceTests();

  testWidgets('configured paywall renders store products and keeps server sync',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final billing = FakeBillingGateway();
    final telemetry = MemoryTelemetry();

    await tester.pumpWidget(wrapApp(
      const PaywallScreen(
        highlight: Feature.edgeFuelAiCoach,
        trigger: PaywallTrigger.fighterBrief,
      ),
      repo: repo,
      billingGateway: billing,
      telemetry: telemetry,
    ));
    await tester.pumpAndSettle();
    expect(telemetry.records.single.event, TelemetryEvent.paywallViewed);
    expect(telemetry.records.single.parameters, {
      'feature': 'edgeFuelAiCoach',
      'trigger': 'fighter_brief',
    });
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final monthly = find.textContaining('MONTHLY');
    for (var i = 0; i < 8 && monthly.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(monthly, findsOneWidget);
    expect(find.text('Annual plan'), findsOneWidget);
    expect(find.text(r'About $5.00 / month'), findsOneWidget);
    expect(find.textContaining('ANNUAL'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Restore purchases'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Restore purchases'), findsOneWidget);

    await tester.tap(monthly);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The SDK result is positive, but the local auth repository remains Free;
    // only the server webhook is allowed to change the entitlement.
    expect(repo.currentUser!.isPro, isFalse);
    final syncNotice = find.textContaining('secure account sync');
    await tester.scrollUntilVisible(syncNotice, -200,
        scrollable: find.byType(Scrollable).first);
    expect(syncNotice, findsOneWidget);
  });
}

void _paywallComplianceTests() {
  testWidgets('store plans carry the auto-renewal disclosure (M-1)',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const PaywallScreen(),
      repo: repo,
      billingGateway: FakeBillingGateway(),
    ));
    await tester.pumpAndSettle();

    final disclosure = find.byKey(const ValueKey('paywall-renewal-disclosure'));
    await tester.scrollUntilVisible(disclosure, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.textContaining('renew automatically'), findsOneWidget);
    expect(find.textContaining('24 hours before the end'), findsOneWidget);
  });

  testWidgets('without store plans there is no renewal disclosure',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(const PaywallScreen(), repo: repo));
    await tester.pumpAndSettle();
    expect(
        find.byKey(const ValueKey('paywall-renewal-disclosure')), findsNothing);
  });

  testWidgets('Terms and Privacy are reachable from the paywall',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(
      const PaywallScreen(),
      repo: repo,
      billingGateway: FakeBillingGateway(),
    ));
    await tester.pumpAndSettle();

    final terms = find.text('Terms of Use');
    await tester.scrollUntilVisible(terms, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Privacy Policy'), findsOneWidget);

    // No TERMS_URL in tests: the in-app document opens instead.
    await tester.tap(terms);
    await tester.pumpAndSettle();
    expect(find.text('TERMS OF SERVICE'), findsOneWidget);
  });
}
