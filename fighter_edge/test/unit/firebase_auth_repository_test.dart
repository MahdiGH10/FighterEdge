import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/auth/auth_repository.dart';
import 'package:fighter_edge/auth/firebase_auth_repository.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/models/app_user.dart';

/// Exercises the production Firebase adapter against in-memory doubles. The
/// controllers above it are tested with fakes of [AuthRepository]; these
/// tests cover the adapter itself.
void main() {
  late FakeFirebaseFirestore firestore;

  MockUser athlete() => MockUser(
        uid: 'athlete-1',
        email: 'athlete@example.test',
        displayName: 'Test Athlete',
      );

  FirebaseAuthRepository repo({
    required MockFirebaseAuth auth,
    TargetPlatform platform = TargetPlatform.android,
    bool apple = false,
    bool web = false,
  }) =>
      FirebaseAuthRepository(
        auth: auth,
        firestore: firestore,
        appleSignInEnabled: apple,
        platform: platform,
        isWeb: web,
      );

  setUp(() => firestore = FakeFirebaseFirestore());

  group('Google sign-in', () {
    for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
      test('succeeds on ${platform.name} (provider is not cast)', () async {
        // Regression for audit S-2: `GoogleAuthProvider` was cast to
        // `OAuthProvider`, which it is not, so every mobile attempt threw.
        final auth = MockFirebaseAuth(mockUser: athlete());
        final user = await repo(auth: auth, platform: platform, apple: true)
            .signInWithGoogle();

        expect(user.id, 'athlete-1');
        expect(user.email, 'athlete@example.test');
        expect(user.plan, Plan.free);
      });
    }

    test('uses the popup flow on web', () async {
      final auth = MockFirebaseAuth(mockUser: athlete());
      final user = await repo(auth: auth, web: true).signInWithGoogle();
      expect(user.id, 'athlete-1');
    });

    test('seeds a free profile for a first sign-in', () async {
      final auth = MockFirebaseAuth(mockUser: athlete());
      await repo(auth: auth).signInWithGoogle();

      final profile =
          await firestore.collection('users').doc('athlete-1').get();
      expect(profile.exists, isTrue);
      expect(profile.data()?['plan'], 'free');
    });
  });

  group('provider availability', () {
    test('Android offers Google without Apple', () {
      final r = repo(auth: MockFirebaseAuth());
      expect(r.supportsGoogle, isTrue);
      expect(r.supportsApple, isFalse);
    });

    test('iOS hides Google until Sign in with Apple is enabled (4.8)', () {
      final withoutApple =
          repo(auth: MockFirebaseAuth(), platform: TargetPlatform.iOS);
      expect(withoutApple.supportsGoogle, isFalse);
      expect(withoutApple.supportsApple, isFalse);

      final withApple = repo(
          auth: MockFirebaseAuth(), platform: TargetPlatform.iOS, apple: true);
      expect(withApple.supportsGoogle, isTrue);
      expect(withApple.supportsApple, isTrue);
    });

    test('web offers Google regardless of the host platform', () {
      final r = repo(
          auth: MockFirebaseAuth(), platform: TargetPlatform.iOS, web: true);
      expect(r.supportsGoogle, isTrue);
    });
  });

  group('profile hydration', () {
    test('reads a server-granted Pro plan and billing expiry', () async {
      await firestore.collection('users').doc('athlete-1').set({
        'plan': 'pro',
        'billing': {'expiresAtMs': 1893456000000, 'willRenew': true},
        'onboardingComplete': true,
      });
      final auth = MockFirebaseAuth(mockUser: athlete());

      final user = await repo(auth: auth).signInWithGoogle();

      expect(user.isPro, isTrue);
      expect(user.planWillRenew, isTrue);
      expect(user.planExpiresAt,
          DateTime.fromMillisecondsSinceEpoch(1893456000000, isUtc: true));
      expect(user.onboardingComplete, isTrue);
    });

    test('email sign-in hydrates the same profile', () async {
      final auth = MockFirebaseAuth(mockUser: athlete());
      final user = await repo(auth: auth).signInWithEmail(
        email: ' athlete@example.test ',
        password: 'correct horse',
      );
      expect(user.id, 'athlete-1');
      expect(repo(auth: auth).currentUser, isNull,
          reason: 'a fresh adapter has not hydrated anyone yet');
    });
  });

  test('signing out clears the session', () async {
    final auth = MockFirebaseAuth(mockUser: athlete());
    final r = repo(auth: auth);
    await r.signInWithGoogle();
    await r.signOut();
    expect(auth.currentUser, isNull);
  });

  test('a signed-out change-password attempt fails clearly', () async {
    final r = repo(auth: MockFirebaseAuth());
    await expectLater(
      r.changePassword(currentPassword: 'a', newPassword: 'b'),
      throwsA(isA<AuthException>().having((e) => e.code, 'code', 'signed-out')),
    );
  });

  group('live profile (audit M-3)', () {
    test('re-emits the account when the server changes its plan', () async {
      final auth = MockFirebaseAuth(mockUser: athlete());
      final r = repo(auth: auth);
      final emissions = <AppUser?>[];
      final sub = r.authStateChanges().listen(emissions.add);

      await auth.signInWithEmailAndPassword(
          email: 'athlete@example.test', password: 'x');
      await pumpEventQueue();
      expect(emissions.last?.id, 'athlete-1');
      expect(emissions.last?.isPro, isFalse);
      expect(
          (await firestore.collection('users').doc('athlete-1').get()).exists,
          isTrue,
          reason: 'a first sign-in seeds the free profile');

      // The RevenueCat webhook grants Pro on the server.
      await firestore.collection('users').doc('athlete-1').set({
        'plan': 'pro',
        'billing': {
          'expiresAtMs': DateTime.now()
              .add(const Duration(days: 30))
              .millisecondsSinceEpoch,
        },
      }, SetOptions(merge: true));
      await pumpEventQueue();
      expect(emissions.last?.isPro, isTrue);
      expect(r.currentUser?.isPro, isTrue);

      // It lapses on the server.
      await firestore
          .collection('users')
          .doc('athlete-1')
          .set({'plan': 'free'}, SetOptions(merge: true));
      await pumpEventQueue();
      expect(emissions.last?.isPro, isFalse);

      await auth.signOut();
      await pumpEventQueue();
      expect(emissions.last, isNull);
      expect(r.currentUser, isNull);
      await sub.cancel();
    });

    test('a Pro plan past its expiry is not Pro', () async {
      await firestore.collection('users').doc('athlete-1').set({
        'plan': 'pro',
        'billing': {
          'expiresAtMs': DateTime.now()
              .subtract(const Duration(days: 3))
              .millisecondsSinceEpoch,
        },
      });
      final auth = MockFirebaseAuth(mockUser: athlete());
      final user = await repo(auth: auth).signInWithGoogle();
      expect(user.plan, Plan.pro);
      expect(user.isPro, isFalse);
    });

    test('syncEntitlement never throws, signed in or out', () async {
      var calls = 0;
      FirebaseFunctions failingFunctions() {
        calls++;
        throw StateError('functions unavailable');
      }

      final signedOut = FirebaseAuthRepository(
        auth: MockFirebaseAuth(),
        firestore: firestore,
        functions: failingFunctions,
      );
      await signedOut.syncEntitlement();
      expect(calls, 0, reason: 'nothing to sync without an account');

      final auth = MockFirebaseAuth(mockUser: athlete());
      final signedIn = FirebaseAuthRepository(
        auth: auth,
        firestore: firestore,
        functions: failingFunctions,
      );
      await signedIn.signInWithGoogle();
      await signedIn.syncEntitlement();
      expect(calls, 1);
    });
  });
}
