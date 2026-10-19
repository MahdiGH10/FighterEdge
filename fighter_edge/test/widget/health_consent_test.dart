import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/privacy/health_consent_screen.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';
import 'package:fighter_edge/screens/settings_screen.dart';

import '../helpers/test_harness.dart';

/// Explicit consent (Art. 9 GDPR) before health data is collected, and
/// withdrawing it from Settings.
void main() {
  void tallView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  group('health data', () {
    testWidgets('an account set up before the consent step is asked once',
        (tester) async {
      tallView(tester);
      final repo = await makeRepo(
        signedIn: true,
        onboarded: true,
        healthConsent: false,
      );
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(HealthConsentScreen), findsOneWidget);
      expect(find.byType(HomeShell), findsNothing);
      expect(find.text('Delete my account instead'), findsOneWidget);

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();

      expect(repo.currentUser!.hasHealthDataConsent, isTrue);
      expect(find.byType(HealthConsentScreen), findsNothing);
      expect(find.byType(HomeShell), findsOneWidget);
    });

    testWidgets('a new account is asked after the welcome pages, before setup',
        (tester) async {
      tallView(tester);
      final repo = await makeRepo(signedIn: true, healthConsent: false);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(OnboardingScreen), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Build my plan'));
      await tester.pumpAndSettle();

      expect(find.byType(HealthConsentScreen), findsOneWidget);
      expect(find.text('What should Fighter Edge build first?'), findsNothing);
      expect(find.text('Delete my account instead'), findsNothing,
          reason: 'a new account holds no data to delete yet');

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(
          find.text('What should Fighter Edge build first?'), findsOneWidget);
    });

    testWidgets('declining is one tap: sign out', (tester) async {
      tallView(tester);
      final repo = await makeRepo(
        signedIn: true,
        onboarded: true,
        healthConsent: false,
      );
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Not now, sign out'));
      await tester.pumpAndSettle();

      expect(repo.currentUser, isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });

    testWidgets('an existing account can delete its data instead',
        (tester) async {
      tallView(tester);
      final repo = await makeRepo(
        signedIn: true,
        onboarded: true,
        healthConsent: false,
      );
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete my account instead'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();

      expect(repo.currentUser, isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });

  group('Settings > Privacy', () {
    Future<void> openSettings(
        WidgetTester tester, LocalAuthRepository repo) async {
      tallView(tester);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pump();
      GoRouter.of(tester.element(find.byType(HomeShell)))
          .push(AppRoutes.settings);
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }

    testWidgets('withdrawing health consent leads to account deletion',
        (tester) async {
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await openSettings(tester, repo);
      expect(find.textContaining('You agreed on'), findsOneWidget);

      await tester.tap(find.text('Health data'));
      await tester.pumpAndSettle();
      expect(find.text('Withdraw consent?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.currentUser!.hasHealthDataConsent, isTrue);

      await tester.tap(find.text('Health data'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete my account'));
      await tester.pumpAndSettle();
      expect(find.text('Type DELETE to confirm.'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'DELETE');
      await tester.pump();
      await tester.tap(find.text('Delete forever'));
      await tester.pumpAndSettle();
      expect(repo.currentUser, isNull);
      expect(find.text('Welcome back'), findsOneWidget);
    });
  });
}
