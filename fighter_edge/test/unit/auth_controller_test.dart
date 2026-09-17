import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
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
}
