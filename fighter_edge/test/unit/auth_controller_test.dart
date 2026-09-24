import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/billing_gateway.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/billing/fake_billing_gateway.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';

void main() {
  late LocalAuthRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    repo = LocalAuthRepository();
    await repo.init();
  });

  test('starts unauthenticated', () {
    final auth = AuthController(repo);
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
    expect(auth.isPro, isFalse);
    expect(auth.supportsGoogle, isTrue);
    expect(auth.supportsApple, isTrue);
    expect(auth.supportsMagicLink, isTrue);
    expect(auth.supportsEmailVerification, isFalse);
  });

  test('signup authenticates and notifies listeners', () async {
    final auth = AuthController(repo);
    var notified = 0;
    auth.addListener(() => notified++);

    await auth.signUp('a@b.com', 'secret1', 'Ayoub');

    expect(auth.status, AuthStatus.authenticated);
    expect(auth.user!.email, 'a@b.com');
    expect(notified, greaterThan(0));
  });

  test('failed signup rethrows and leaves state unauthenticated', () async {
    final auth = AuthController(repo);
    await expectLater(auth.signUp('bad', 'x', 'A'), throwsA(anything));
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.isBusy, isFalse);
  });

  test('checkout intent does not grant Pro entitlements from the client',
      () async {
    final auth = AuthController(repo);
    await auth.signUp('a@b.com', 'secret1', 'A');
    expect(auth.allows(Feature.cornerCoach), isFalse);

    await expectLater(auth.startProCheckout(), throwsA(anything));
    expect(auth.isPro, isFalse);
    expect(auth.allows(Feature.cornerCoach), isFalse);
    expect(auth.isBusy, isFalse);
  });

  test('store purchase waits for the trusted server entitlement', () async {
    final billing = FakeBillingGateway();
    final auth = AuthController(repo, billingGateway: billing);
    await auth.signUp('a@b.com', 'secret1', 'A');
    await Future<void>.delayed(Duration.zero);

    await auth.startProCheckout(billing.products.first);

    expect(billing.purchaseCount, 1);
    expect(auth.isPro, isFalse);
    expect(auth.billingState.isPro, isTrue);
  });

  test('sign-out returns to unauthenticated', () async {
    final auth = AuthController(repo);
    await auth.signUp('a@b.com', 'secret1', 'A');
    await auth.signOut();
    expect(auth.status, AuthStatus.unauthenticated);
    expect(auth.user, isNull);
  });

  test('devMagicHint is available under the local backend', () async {
    final auth = AuthController(repo);
    await auth.sendMagicLink('x@y.com');
    expect(auth.devMagicHint, isNotNull);
  });

  group('live entitlement (audit M-3)', () {
    test('a server-side plan change updates the same session in place',
        () async {
      final billing = FakeBillingGateway();
      final auth = AuthController(repo, billingGateway: billing);
      await auth.signUp('a@b.com', 'secret1', 'A');
      await Future<void>.delayed(Duration.zero);
      expect(auth.billingProducts, isNotEmpty);
      final userId = auth.user!.id;

      // The webhook grants Pro; the profile stream re-emits the same account.
      await repo.debugSetPlan(Plan.pro);
      await Future<void>.delayed(Duration.zero);

      expect(auth.isPro, isTrue);
      expect(auth.allows(Feature.cornerCoach), isTrue);
      expect(auth.user!.id, userId);
      expect(auth.billingProducts, isNotEmpty,
          reason: 'a plan change must not tear down the billing session');
      auth.dispose();
    });

    test('purchase and restore ask the server to sync from RevenueCat',
        () async {
      final billing = FakeBillingGateway();
      final auth = AuthController(repo, billingGateway: billing);
      await auth.signUp('a@b.com', 'secret1', 'A');
      await Future<void>.delayed(Duration.zero);

      await auth.startProCheckout(billing.products.first);
      expect(repo.syncEntitlementCalls, 1);

      await auth.restorePurchases();
      expect(repo.syncEntitlementCalls, 2);
      auth.dispose();
    });

    test('a store-side renewal nudges the server but grants nothing', () async {
      final billing = FakeBillingGateway();
      final auth = AuthController(repo, billingGateway: billing);
      await auth.signUp('a@b.com', 'secret1', 'A');
      await Future<void>.delayed(Duration.zero);

      billing.emitCustomerInfo(
          const BillingCustomerState(isPro: true, willRenew: true));
      await Future<void>.delayed(Duration.zero);

      expect(auth.billingState.isPro, isTrue);
      expect(repo.syncEntitlementCalls, 1);
      expect(auth.isPro, isFalse, reason: 'only the server grants Pro');
      auth.dispose();
    });

    test('store updates are ignored while signed out', () async {
      final billing = FakeBillingGateway();
      final auth = AuthController(repo, billingGateway: billing);
      billing.emitCustomerInfo(const BillingCustomerState(isPro: true));
      await Future<void>.delayed(Duration.zero);
      expect(repo.syncEntitlementCalls, 0);
      expect(auth.billingState.isPro, isFalse);
      auth.dispose();
    });
  });
}
