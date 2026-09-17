import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('configured paywall renders store products and keeps server sync',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final billing = FakeBillingGateway();

    await tester.pumpWidget(wrapApp(
      const PaywallScreen(),
      repo: repo,
      billingGateway: billing,
    ));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    final monthly = find.textContaining('MONTHLY');
    for (var i = 0; i < 8 && monthly.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView), const Offset(0, -600));
      await tester.pumpAndSettle();
    }
    expect(monthly, findsOneWidget);
    expect(find.textContaining('ANNUAL'), findsOneWidget);
    expect(find.text('Restore purchases'), findsOneWidget);

    await tester.tap(monthly);
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // The SDK result is positive, but the local auth repository remains Free;
    // only the server webhook is allowed to change the entitlement.
    expect(repo.currentUser!.isPro, isFalse);
    expect(find.textContaining('secure account sync'), findsOneWidget);
  });
}
