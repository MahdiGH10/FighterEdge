import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/screens/paywall_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

const _annual = BillingProduct(
  id: 'fighter_edge_pro_annual',
  period: BillingProductPeriod.annual,
  priceString: r'$59.99',
  currencyCode: 'USD',
  price: 59.99,
  freeTrial: BillingFreeTrial(days: 7),
);
const _monthly = BillingProduct(
  id: 'fighter_edge_pro_monthly',
  period: BillingProductPeriod.monthly,
  priceString: r'$7.99',
  currencyCode: 'USD',
  price: 7.99,
  freeTrial: BillingFreeTrial(days: 7),
);

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200,
      scrollable: find.byType(Scrollable).first);
}

void main() {
  group('trial line', () {
    testWidgets('shows the store trial with the price as prominent as "free"',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(),
        repo: repo,
        billingGateway: FakeBillingGateway(products: [_annual, _monthly]),
      ));
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('paywall-trial-line'));
      await _scrollTo(tester, line);
      final text = tester.widget<Text>(line);
      // One Text, one style: the price cannot be smaller than the trial.
      expect(text.data, r'7 days free, then $59.99 / year');
      expect(text.textSpan, isNull);

      await _scrollTo(tester, find.text('Start free trial'));
      expect(find.text('Start free trial'), findsOneWidget);
      expect(find.text('Continue with annual plan'), findsNothing);

      final disclosure =
          find.byKey(const ValueKey('paywall-renewal-disclosure'));
      await _scrollTo(tester, disclosure);
      final words = tester.widget<Text>(disclosure).data!;
      expect(words, contains('Free for 7 days'));
      expect(words, contains(r'$59.99 / year'));
      expect(words, contains('renewing automatically'));
      expect(words, contains('Cancel at least 24 hours before the trial ends'));
    });

    testWidgets('picking monthly changes the price after the trial',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(),
        repo: repo,
        billingGateway: FakeBillingGateway(products: [_annual, _monthly]),
      ));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Monthly plan'));
      await tester.ensureVisible(find.text('Monthly plan'));
      await tester.tap(find.text('Monthly plan'));
      await tester.pumpAndSettle();

      final line = find.byKey(const ValueKey('paywall-trial-line'));
      await _scrollTo(tester, line);
      expect(
          tester.widget<Text>(line).data, r'7 days free, then $7.99 / month');
    });

    testWidgets('never claims a trial the store does not offer',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(),
        repo: repo,
        // The default fake products carry no free trial.
        billingGateway: FakeBillingGateway(),
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('paywall-trial-line')), findsNothing);
      expect(
          find.textContaining('free trial', findRichText: true), findsNothing);
      expect(find.textContaining('days free'), findsNothing);
      await _scrollTo(tester, find.text('Continue with annual plan'));
      expect(find.text('Start free trial'), findsNothing);
      final disclosure =
          find.byKey(const ValueKey('paywall-renewal-disclosure'));
      await _scrollTo(tester, disclosure);
      expect(tester.widget<Text>(disclosure).data,
          contains('renew automatically'));
    });

    testWidgets('a trial on one plan only is shown only for that plan',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      const monthlyNoTrial = BillingProduct(
        id: 'fighter_edge_pro_monthly',
        period: BillingProductPeriod.monthly,
        priceString: r'$7.99',
        currencyCode: 'USD',
        price: 7.99,
      );
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(),
        repo: repo,
        billingGateway: FakeBillingGateway(products: [_annual, monthlyNoTrial]),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall-trial-line')), findsOneWidget);

      await _scrollTo(tester, find.text('Monthly plan'));
      await tester.ensureVisible(find.text('Monthly plan'));
      await tester.tap(find.text('Monthly plan'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('paywall-trial-line')), findsNothing);
      await _scrollTo(tester, find.text('Continue with monthly plan'));
    });
  });

  group('the paywall as a page', () {
    testWidgets('has no waitlist and offers Restore, Terms and Privacy',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(const PaywallScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.textContaining('Notify me'), findsNothing);
      expect(find.textContaining('waitlist'), findsNothing);
      expect(
          find.text("Subscriptions aren't available here yet"), findsOneWidget);
      await _scrollTo(tester, find.text('Terms of Use'));
      expect(find.text('Privacy Policy'), findsOneWidget);
    });

    testWidgets('lists outcomes, not only gated features', (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(const PaywallScreen(), repo: repo));
      await tester.pumpAndSettle();
      for (final title in [
        'Your camp week',
        'Fuel for training days',
        'Weekly review',
        'Safe weight path',
      ]) {
        await _scrollTo(tester, find.text(title));
        expect(find.text(title), findsOneWidget);
      }
    });

    testWidgets('a read-only account is told its data is saved',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(trigger: PaywallTrigger.readOnly),
        repo: repo,
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('paywall-read-only-note')), findsOneWidget);
      expect(find.text('Your data is saved. Subscribe to keep training.'),
          findsOneWidget);
    });

    testWidgets('the onboarding gate does not show the read-only note',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(trigger: PaywallTrigger.planReady),
        repo: repo,
      ));
      await tester.pumpAndSettle();
      expect(
          find.byKey(const ValueKey('paywall-read-only-note')), findsNothing);
    });

    testWidgets(
        'an account in its trial sees the trial status, not a buy button',
        (tester) async {
      final repo = await makeRepo(signedIn: true);
      await repo.debugSetPlan(
        Plan.pro,
        expiresAt: DateTime.now().add(const Duration(days: 5, hours: 1)),
        period: ProPeriod.trial,
      );
      await tester.pumpWidget(wrapApp(
        const PaywallScreen(),
        repo: repo,
        billingGateway: FakeBillingGateway(products: [_annual, _monthly]),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Your free trial is running'), findsOneWidget);
      expect(find.text('Trial · 6 days left'), findsOneWidget);
      expect(find.text('Start free trial'), findsNothing);
    });
  });

  group('the onboarding gate', () {
    testWidgets('pops true once the store accepts the trial', (tester) async {
      final repo = await makeRepo(signedIn: true);
      final billing = FakeBillingGateway(
        products: [_annual, _monthly],
        purchaseState: const BillingCustomerState(
            isPro: true, inTrial: true, willRenew: true),
      );
      bool? result;
      await tester.pumpWidget(wrapApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const PaywallScreen(trigger: PaywallTrigger.planReady),
                  ),
                );
              },
              child: const Text('open gate'),
            ),
          ),
        ),
        repo: repo,
        billingGateway: billing,
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text('Start free trial'));
      await tester.ensureVisible(find.text('Start free trial'));
      await tester.tap(find.text('Start free trial'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(billing.purchaseCount, 1);
      expect(result, isTrue);
      // The store result is not access: the server has not confirmed yet.
      expect(repo.currentUser!.isPro, isFalse);
    });

    testWidgets('backing out of the gate returns nothing', (tester) async {
      final repo = await makeRepo(signedIn: true);
      bool? result = true;
      await tester.pumpWidget(wrapApp(
        Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const PaywallScreen(trigger: PaywallTrigger.planReady),
                  ),
                );
              },
              child: const Text('open gate'),
            ),
          ),
        ),
        repo: repo,
        billingGateway: FakeBillingGateway(products: [_annual, _monthly]),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('open gate'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(result, isNull);
    });
  });
}
