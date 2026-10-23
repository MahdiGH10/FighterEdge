import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/theme/app_icons.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
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

/// Onboarding -> "Start your free week" -> paywall -> store trial -> trial chip
/// -> trial lapses -> read-only banner -> Restore -> active.
///
/// The one rule under test: the store (the fake gateway) never grants access.
/// Every state change on screen follows the server-fed profile, which the
/// test moves with `debugSetPlan` the way the RevenueCat webhook would.
void main() {
  testWidgets('trial journey: access follows the server, not the store', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await makeRepo();
    final store = FakeBillingGateway(
      products: [_annual, _monthly],
      purchaseState: const BillingCustomerState(
        isPro: true,
        inTrial: true,
        willRenew: true,
      ),
    );
    final reminders = FakeReminderGateway();
    final telemetry = MemoryTelemetry();
    await tester.pumpWidget(
      FighterEdgeApp(
        authRepo: repo,
        billingGateway: store,
        reminderGateway: reminders,
        telemetry: telemetry,
      ),
    );
    await tester.pumpAndSettle();

    // Sign up and walk the onboarding questions.
    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'Ayoub');
    await tester.enterText(find.byType(TextField).at(1), 'trial@test.com');
    await tester.enterText(find.byType(TextField).at(2), 'journey-pass-1');
    await tester.enterText(find.byType(TextField).at(3), 'journey-pass-1');
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    await tester.tap(find.byType(PrimaryButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Build my plan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '28');
    await tester.enterText(find.byType(TextField).at(1), '178');
    await tester.enterText(find.byType(TextField).at(2), '77.2');
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your first plan is ready.'), findsOneWidget);
    await tester.tap(find.text('Start my plan'));
    await tester.pumpAndSettle();

    // The plan reveal is the entry gate, and the store offers a trial.
    expect(find.text('Your first Fighter Edge plan is ready'), findsOneWidget);
    expect(find.text('Continue read-only'), findsNothing);
    expect(find.text('Open dashboard'), findsNothing);
    expect(find.text('View fuel plan'), findsNothing);
    await tester.tap(find.text('Start your free week'));
    await tester.pumpAndSettle();
    expect(
      telemetry.records.map((r) => r.event),
      contains(TelemetryEvent.paywallViewed),
    );
    expect(
      telemetry.records
          .firstWhere((r) => r.event == TelemetryEvent.paywallViewed)
          .parameters['trigger'],
      'plan_ready',
    );

    // Start the store trial. The app carries on, but the profile is still
    // free: the store result alone grants nothing.
    await tester.ensureVisible(find.text('Start free trial'));
    await tester.tap(find.text('Start free trial'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(store.purchaseCount, 1);
    expect(find.text('Ayoub'), findsOneWidget);
    expect(repo.currentUser!.isPro, isFalse);
    expect(find.text('Trial · 5 days left'), findsNothing);

    // The webhook writes the trial: the chip appears, the reminder is set.
    final trialEnd = DateTime.now().add(const Duration(days: 5, hours: 1));
    await repo.debugSetPlan(
      Plan.pro,
      expiresAt: trialEnd,
      period: ProPeriod.trial,
    );
    await tester.pumpAndSettle();
    expect(find.text('Trial · 5 days left'), findsOneWidget);
    expect(
      find.text('Your data is saved. Subscribe to keep training.'),
      findsNothing,
    );
    expect(reminders.trialReminderAt, isNotNull);

    // The trial lapses (EXPIRATION webhook): read-only banner, reminder gone.
    store.emitCustomerInfo(const BillingCustomerState.free());
    await repo.debugSetPlan(
      Plan.free,
      expiresAt: trialEnd,
      period: ProPeriod.trial,
    );
    await tester.pumpAndSettle();
    expect(find.text('Trial · 5 days left'), findsNothing);
    expect(
      find.text('Your data is saved. Subscribe to keep training.'),
      findsOneWidget,
    );
    expect(reminders.trialReminderCancels, greaterThan(0));

    // Restore finds a live subscription in the store, yet the profile is
    // still free, so the banner stays.
    store.restoreState = BillingCustomerState(
      isPro: true,
      willRenew: true,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
    );
    await tester.tap(find.text('See plans'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Restore purchases'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Restore purchases'));
    await tester.pumpAndSettle();
    expect(store.restoreCount, 1);
    expect(repo.currentUser!.isPro, isFalse);

    // Only the webhook makes the account active again.
    await repo.debugSetPlan(
      Plan.pro,
      expiresAt: DateTime.now().add(const Duration(days: 30)),
      period: ProPeriod.normal,
    );
    await tester.pumpAndSettle();
    expect(repo.currentUser!.isPro, isTrue);
    await tester.tap(find.byIcon(AppIcons.caretLeft));
    await tester.pumpAndSettle();
    expect(
      find.text('Your data is saved. Subscribe to keep training.'),
      findsNothing,
    );
  });
}
