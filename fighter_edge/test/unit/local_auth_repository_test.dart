import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/auth_repository.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/subscription.dart';

void main() {
  late LocalAuthRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    repo = LocalAuthRepository();
    await repo.init();
  });

  group('email/password', () {
    test('signup creates a signed-in free user', () async {
      final u = await repo.signUpWithEmail(
          email: 'a@b.com', password: 'secret1', displayName: 'Ayoub');
      expect(u.email, 'a@b.com');
      expect(u.displayName, 'Ayoub');
      expect(u.plan, Plan.free);
      expect(repo.currentUser?.id, u.id);
    });

    test('duplicate email is rejected', () async {
      await repo.signUpWithEmail(
          email: 'a@b.com', password: 'secret1', displayName: 'A');
      expect(
        () => repo.signUpWithEmail(
            email: 'A@b.com', password: 'secret1', displayName: 'B'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'email-already-in-use')),
      );
    });

    test('weak password and invalid email are rejected', () async {
      expect(
        () => repo.signUpWithEmail(
            email: 'a@b.com', password: '123', displayName: 'A'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'weak-password')),
      );
      expect(
        () => repo.signUpWithEmail(
            email: 'not-an-email', password: 'secret1', displayName: 'A'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'invalid-email')),
      );
    });

    test('sign-in validates the password', () async {
      await repo.signUpWithEmail(
          email: 'a@b.com', password: 'secret1', displayName: 'A');
      await repo.signOut();
      expect(
        () => repo.signInWithEmail(email: 'a@b.com', password: 'wrong'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'wrong-password')),
      );
      expect(
        () => repo.signInWithEmail(email: 'nobody@b.com', password: 'secret1'),
        throwsA(isA<AuthException>()
            .having((e) => e.code, 'code', 'user-not-found')),
      );
      final u = await repo.signInWithEmail(email: 'a@b.com', password: 'secret1');
      expect(u.email, 'a@b.com');
    });

    test('sign-out clears the current user', () async {
      await repo.signUpWithEmail(
          email: 'a@b.com', password: 'secret1', displayName: 'A');
      await repo.signOut();
      expect(repo.currentUser, isNull);
    });
  });

  group('passwordless (magic code)', () {
    test('a correct code signs in / auto-creates the account', () async {
      await repo.sendMagicLink('new@b.com');
      expect(repo.lastMagicCode, isNotNull);
      final u = await repo.verifyMagicCode(
          email: 'new@b.com', code: repo.lastMagicCode!);
      expect(u.email, 'new@b.com');
      expect(repo.currentUser?.id, u.id);
    });

    test('a wrong code is rejected', () async {
      await repo.sendMagicLink('new@b.com');
      expect(
        () => repo.verifyMagicCode(email: 'new@b.com', code: '000000'),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('social + persistence', () {
    test('google / apple create verified accounts', () async {
      final g = await repo.signInWithGoogle();
      expect(g.emailVerified, isTrue);
      await repo.signOut();
      final a = await repo.signInWithApple();
      expect(a.email, isNot(g.email));
    });

    test('session + plan persist across a fresh repo', () async {
      final u = await repo.signUpWithEmail(
          email: 'a@b.com', password: 'secret1', displayName: 'A');
      await repo.updatePlan(u.copyWith(plan: Plan.pro));

      final repo2 = LocalAuthRepository();
      await repo2.init();
      expect(repo2.currentUser?.email, 'a@b.com');
      expect(repo2.currentUser?.isPro, isTrue);
    });
  });

  test('authStateChanges emits on sign-in and sign-out', () async {
    final events = <bool>[]; // true = has user
    final sub = repo.authStateChanges().listen((u) => events.add(u != null));
    await repo.signUpWithEmail(
        email: 'a@b.com', password: 'secret1', displayName: 'A');
    await repo.signOut();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events.contains(true), isTrue);
    expect(events.last, isFalse);
  });
}
