import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';
import 'package:fighter_edge/widgets/access_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../helpers/test_harness.dart';

const _home = Scaffold(body: AccessStatus());

void main() {
  testWidgets('a trial shows the days left, and tapping opens the paywall',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await repo.debugSetPlan(
      Plan.pro,
      expiresAt: DateTime.now().add(const Duration(days: 4, hours: 3)),
      period: ProPeriod.trial,
    );
    await tester.pumpWidget(wrapApp(_home, repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Trial · 5 days left'), findsOneWidget);
    expect(find.text('Your data is saved. Subscribe to keep training.'),
        findsNothing);

    await tester.tap(find.text('Trial · 5 days left'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('the last day reads as ending today or 1 day left',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await repo.debugSetPlan(
      Plan.pro,
      expiresAt: DateTime.now().add(const Duration(hours: 5)),
      period: ProPeriod.trial,
    );
    await tester.pumpWidget(wrapApp(_home, repo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Trial · 1 day left'), findsOneWidget);
  });

  testWidgets('a read-only account sees the banner and a way to the paywall',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(wrapApp(_home, repo: repo));
    await tester.pumpAndSettle();

    expect(find.text('Your data is saved. Subscribe to keep training.'),
        findsOneWidget);
    await tester.tap(find.text('See plans'));
    await tester.pumpAndSettle();
    expect(find.byType(PaywallScreen), findsOneWidget);
  });

  testWidgets('paid accounts see neither', (tester) async {
    final repo = await makeRepo(signedIn: true, plan: Plan.pro);
    await tester.pumpWidget(wrapApp(_home, repo: repo));
    await tester.pumpAndSettle();
    expect(find.textContaining('Trial'), findsNothing);
    expect(find.text('See plans'), findsNothing);
  });

  testWidgets('a purchase the store accepted is not shown as ended',
      (tester) async {
    final repo = await makeRepo(signedIn: true);
    final billing = FakeBillingGateway(
      purchaseState: const BillingCustomerState(isPro: true, inTrial: true),
    );
    late AuthController auth;
    await tester.pumpWidget(wrapApp(
      Builder(builder: (context) {
        auth = context.read<AuthController>();
        return _home;
      }),
      repo: repo,
      billingGateway: billing,
    ));
    await tester.pumpAndSettle();
    expect(find.text('See plans'), findsOneWidget);

    await auth.startProCheckout(billing.products.first);
    await tester.pumpAndSettle();

    // The server has not confirmed yet: neither a trial chip (that would be
    // the client granting it) nor the "ended" banner.
    expect(auth.accessState.isReadOnly, isTrue);
    expect(find.text('See plans'), findsNothing);
    expect(find.textContaining('Trial'), findsNothing);
  });
}
