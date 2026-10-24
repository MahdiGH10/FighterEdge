import 'package:clock/clock.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/observability/telemetry.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The whole paid-app lifecycle with a fake store and a fake "webhook"
/// (`debugSetPlan`, which stands in for the server writing `users/{uid}`).
///
/// The point under test: the store result never grants access. Only the
/// server-fed profile moves the athlete out of read-only.
void main() {
  late LocalAuthRepository repo;
  late FakeBillingGateway store;
  late MemoryTelemetry telemetry;
  late AuthController auth;
  late AppState app;
  late DateTime t0;

  Future<void> webhook(
    Plan plan, {
    DateTime? expiresAt,
    ProPeriod? period,
  }) async {
    await repo.debugSetPlan(plan, expiresAt: expiresAt, period: period);
    await Future<void>.delayed(Duration.zero);
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    t0 = DateTime.now();
    repo = LocalAuthRepository();
    await repo.init();
    store = FakeBillingGateway(
      restoreState: const BillingCustomerState.free(),
    );
    telemetry = MemoryTelemetry();
    auth = AuthController(repo, billingGateway: store, telemetry: telemetry);
    addTearDown(auth.dispose);
    await auth.signUp('fighter@test.com', 'secret1', 'Fighter');
    await Future<void>.delayed(Duration.zero);
    app = AppState()..accessSource = (() => auth.accessState);
    addTearDown(app.dispose);
  });

  test('a new account starts read-only and cannot log until the trial', () {
    expect(auth.accessState.isReadOnly, isTrue);
    expect(auth.canWrite, isFalse);
    expect(app.requireWrite(), isFalse);
    expect(auth.allows(Feature.cornerCoach), isFalse);
  });

  test(
      'purchase trial -> trial state -> expiry -> readOnly -> restore -> '
      'Pro only after the webhook-fed entitlement', () async {
    final trialEnd = t0.add(const Duration(days: 7));
    store.purchaseState = BillingCustomerState(
      isPro: true,
      inTrial: true,
      willRenew: true,
      expiresAt: trialEnd,
    );

    // 1. The athlete starts the store trial.
    await auth.startProCheckout(store.products.first);
    expect(store.purchaseCount, 1);
    expect(auth.billingState.isPro, isTrue,
        reason: 'the store result is shown as activating');
    expect(auth.accessState.isReadOnly, isTrue,
        reason: 'but a store result never grants access by itself');
    expect(app.requireWrite(), isFalse);
    expect(auth.allows(Feature.cornerCoach), isFalse);
    expect(telemetry.records.map((r) => r.event),
        contains(TelemetryEvent.trialStarted));

    // 2. The RevenueCat webhook writes the trial to the profile.
    await webhook(Plan.pro, expiresAt: trialEnd, period: ProPeriod.trial);
    expect(auth.accessState.isTrial, isTrue);
    expect(auth.accessState.trialEndsAt, trialEnd);
    expect(auth.accessState.trialDaysLeft(t0), 7);
    expect(auth.canWrite, isTrue);
    expect(app.requireWrite(), isTrue);
    expect(auth.allows(Feature.cornerCoach), isTrue);

    // 3. The trial runs out (here the clock passes the server expiry and
    //    leeway before any EXPIRATION webhook has landed).
    final afterExpiry = trialEnd.add(const Duration(days: 1));
    withClock(Clock.fixed(afterExpiry), () {
      expect(auth.accessState.isReadOnly, isTrue);
      expect(app.requireWrite(), isFalse);
      expect(auth.allows(Feature.cornerCoach), isFalse);
    });

    // 4. The webhook's EXPIRATION arrives.
    await webhook(Plan.free, expiresAt: trialEnd, period: ProPeriod.trial);
    expect(auth.accessState.isReadOnly, isTrue);
    expect(app.requireWrite(), isFalse);

    // 5. Restore finds a live subscription in the store. The store says Pro,
    //    the profile does not yet: still read-only.
    store.restoreState = BillingCustomerState(
      isPro: true,
      willRenew: true,
      expiresAt: afterExpiry.add(const Duration(days: 30)),
    );
    await auth.restorePurchases();
    expect(store.restoreCount, 1);
    expect(auth.billingState.isPro, isTrue);
    expect(auth.accessState.isReadOnly, isTrue);
    expect(app.requireWrite(), isFalse);

    // 6. Only the webhook-fed entitlement makes the account active.
    await webhook(
      Plan.pro,
      expiresAt: afterExpiry.add(const Duration(days: 30)),
      period: ProPeriod.normal,
    );
    expect(auth.accessState.isActive, isTrue);
    expect(app.requireWrite(), isTrue);
    expect(auth.allows(Feature.cornerCoach), isTrue);
  });

  test('cancelling during the trial keeps access until the trial ends',
      () async {
    final trialEnd = t0.add(const Duration(days: 7));
    await webhook(Plan.pro, expiresAt: trialEnd, period: ProPeriod.trial);
    // CANCELLATION leaves plan, expiry and period untouched; only willRenew
    // flips, which does not affect access.
    expect(auth.accessState.isTrial, isTrue);
    withClock(Clock.fixed(t0.add(const Duration(days: 6))), () {
      expect(auth.canWrite, isTrue);
    });
    withClock(Clock.fixed(trialEnd.add(const Duration(hours: 2))), () {
      expect(auth.canWrite, isFalse);
    });
  });

  test('trial conversion emits trial_converted once', () async {
    final trialEnd = t0.add(const Duration(days: 7));
    await webhook(Plan.pro, expiresAt: trialEnd, period: ProPeriod.trial);
    expect(
        telemetry.records
            .where((r) => r.event == TelemetryEvent.trialConverted),
        isEmpty);

    await webhook(Plan.pro,
        expiresAt: trialEnd.add(const Duration(days: 30)),
        period: ProPeriod.normal);
    // A further renewal does not count again.
    await webhook(Plan.pro,
        expiresAt: trialEnd.add(const Duration(days: 60)),
        period: ProPeriod.normal);

    expect(auth.accessState.isActive, isTrue);
    expect(
        telemetry.records
            .where((r) => r.event == TelemetryEvent.trialConverted)
            .length,
        1);
  });

  test('a read-only account that never had a trial emits no trial events',
      () async {
    await webhook(Plan.free);
    expect(
        telemetry.records.where((r) =>
            r.event == TelemetryEvent.trialStarted ||
            r.event == TelemetryEvent.trialConverted),
        isEmpty);
  });

  test('trial telemetry carries no identifiers', () async {
    store.purchaseState = const BillingCustomerState(
      isPro: true,
      inTrial: true,
    );
    await auth.startProCheckout(store.products.first);
    final started = telemetry.records
        .firstWhere((r) => r.event == TelemetryEvent.trialStarted);
    expect(started.parameters, {'billing_period': 'monthly'});
  });

  test('a store trial purchase reported as paid is not a trial event',
      () async {
    store.purchaseState =
        const BillingCustomerState(isPro: true, willRenew: true);
    await auth.startProCheckout(store.products.first);
    expect(
        telemetry.records.where((r) => r.event == TelemetryEvent.trialStarted),
        isEmpty);
  });

  test('switching account forgets the cached access state', () async {
    await webhook(Plan.pro, period: ProPeriod.normal);
    expect(auth.accessState.isActive, isTrue);
    await auth.signOut();
    expect(auth.accessState.effective, isNull);
    await auth.signUp('other@test.com', 'secret1', 'Other');
    expect(auth.accessState.isReadOnly, isTrue);
  });
}
