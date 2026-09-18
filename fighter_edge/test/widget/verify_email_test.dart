import 'package:flutter/material.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/auth/auth_repository.dart';
import 'package:fighter_edge/auth/verification_gate.dart';
import 'package:fighter_edge/controllers/auth_controller.dart';
import 'package:fighter_edge/screens/auth/verify_email_screen.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

/// Builds a repository that behaves like a backend with email verification,
/// signed in as a freshly created (therefore unverified) account.
Future<LocalAuthRepository> _unverifiedRepo() async {
  SharedPreferences.setMockInitialValues({});
  final repo = LocalAuthRepository(simulateEmailVerification: true);
  await repo.init();
  await repo.signUpWithEmail(
    email: 'unverified@test.com',
    password: testPassword,
    displayName: 'Unverified Fighter',
  );
  return repo;
}

void main() {
  group('VerifyEmailScreen', () {
    testWidgets('names the address the link was sent to', (tester) async {
      final repo = await _unverifiedRepo();

      await tester.pumpWidget(
        wrapApp(const VerifyEmailScreen(), repo: repo),
      );
      await tester.pump();

      expect(find.textContaining('unverified@test.com'), findsOneWidget);
      expect(find.textContaining('Waiting for confirmation'), findsOneWidget);

      // The periodic poll keeps the tree dirty; cancel it before the test ends.
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('advances by itself once the address is confirmed',
        (tester) async {
      final repo = await _unverifiedRepo();

      await tester.pumpWidget(
        wrapApp(const VerifyEmailScreen(), repo: repo),
      );
      await tester.pump();
      expect(find.text('Email confirmed'), findsNothing);

      // Stands in for the user opening the link in their mail app — which
      // never returns to this screen, so polling is the only signal.
      await repo.debugMarkEmailVerified();

      // Let one poll interval elapse.
      await tester.pump(const Duration(seconds: 4));
      await tester.pump();

      expect(find.text('Email confirmed'), findsOneWidget);
      expect(find.textContaining('Waiting for confirmation'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('always offers a way out for a mistyped address',
        (tester) async {
      final repo = await _unverifiedRepo();

      await tester.pumpWidget(
        wrapApp(const VerifyEmailScreen(blocking: true), repo: repo),
      );
      await tester.pump();

      // Even in the blocking state — otherwise someone who typo'd their email
      // is locked out with no recourse but reinstalling.
      expect(
        find.text('Sign out and use a different email'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('blocking mode hides the dismiss affordance', (tester) async {
      final repo = await _unverifiedRepo();

      await tester.pumpWidget(
        wrapApp(const VerifyEmailScreen(blocking: true), repo: repo),
      );
      await tester.pump();
      expect(find.text('Not now'), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('non-blocking mode lets the user leave', (tester) async {
      final repo = await _unverifiedRepo();

      await tester.pumpWidget(
        wrapApp(const VerifyEmailScreen(), repo: repo),
      );
      await tester.pump();
      expect(find.text('Not now'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('purchase is refused for an unverified account', () {
    testWidgets('startProCheckout throws before touching the store',
        (tester) async {
      final repo = await _unverifiedRepo();
      final controller = AuthController(repo);
      addTearDown(controller.dispose);

      expect(
        controller.allowsVerified(VerifiedAction.purchasePro),
        isFalse,
      );

      await expectLater(
        controller.startProCheckout(),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          'email-not-verified',
        )),
      );
    });

    testWidgets('a verified account gets past the verification gate',
        (tester) async {
      final repo = await _unverifiedRepo();
      await repo.debugMarkEmailVerified();
      final controller = AuthController(repo);
      addTearDown(controller.dispose);

      expect(controller.allowsVerified(VerifiedAction.purchasePro), isTrue);

      // Still fails, but on billing configuration rather than verification —
      // proving the gate is what changed, not the store.
      await expectLater(
        controller.startProCheckout(),
        throwsA(isA<AuthException>().having(
          (e) => e.code,
          'code',
          isNot('email-not-verified'),
        )),
      );
    });
  });

  group('resend cooldown', () {
    testWidgets('starts available, then blocks immediately after sending',
        (tester) async {
      final repo = await _unverifiedRepo();
      final controller = AuthController(repo);
      addTearDown(controller.dispose);

      expect(controller.canResendVerification, isTrue);
      expect(controller.resendCooldownSeconds, 0);

      await controller.sendEmailVerification();

      expect(controller.canResendVerification, isFalse);
      expect(controller.resendCooldownSeconds, greaterThan(0));
      expect(controller.resendCooldownSeconds, lessThanOrEqualTo(60));
    });
  });
}
