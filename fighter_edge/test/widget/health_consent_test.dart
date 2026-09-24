import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/ai/edge_fuel_ai_models.dart';
import 'package:fighter_edge/features/edge_fuel/ai/fake_edge_fuel_ai_gateway.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_coach_screen.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/privacy/health_consent_screen.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/onboarding/onboarding_screen.dart';
import 'package:fighter_edge/screens/settings_screen.dart';

import '../helpers/test_harness.dart';

/// Explicit consent (Art. 9 GDPR) before health data is collected or sent to
/// the AI provider, and withdrawing it from Settings.
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

      await tester.tap(find.text('I AGREE'));
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
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONTINUE'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('BUILD MY PLAN'));
      await tester.pumpAndSettle();

      expect(find.byType(HealthConsentScreen), findsOneWidget);
      expect(find.text('What should Fighter Edge build first?'), findsNothing);
      expect(find.text('Delete my account instead'), findsNothing,
          reason: 'a new account holds no data to delete yet');

      await tester.tap(find.text('I AGREE'));
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

      await tester.tap(find.text('NOT NOW, SIGN OUT'));
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

  group('AI coach', () {
    NutritionTarget target() => NutritionTarget(
          status: NutritionTargetStatus.success,
          policyVersion: 1,
          calculatedAt: DateTime(2026, 1, 1),
          targetCalories: 2500,
          proteinGrams: 150,
          carbGrams: 260,
          fatGrams: 80,
        );

    testWidgets('says what is sent before the first request', (tester) async {
      tallView(tester);
      final repo = await makeRepo(
        signedIn: true,
        plan: Plan.pro,
        aiCoachConsent: false,
      );
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, target());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
      ));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai-coach-consent')), findsOneWidget);
      expect(find.textContaining('OpenRouter (USA)'), findsOneWidget);
      expect(find.text('Talk to your coach'), findsNothing);

      await tester.tap(find.text('I AGREE'));
      await tester.pumpAndSettle();

      expect(repo.currentUser!.hasAiCoachConsent, isTrue);
      expect(find.byKey(const ValueKey('ai-coach-consent')), findsNothing);
      expect(find.text('Talk to your coach'), findsOneWidget);
    });

    testWidgets('explains a server-side consent refusal', (tester) async {
      tallView(tester);
      final repo = await makeRepo(signedIn: true, plan: Plan.pro);
      final edgeFuelRepo = InMemoryEdgeFuelRepository();
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, target());

      await tester.pumpWidget(wrapApp(
        const EdgeFuelCoachScreen(),
        repo: repo,
        edgeFuelRepo: edgeFuelRepo,
        edgeFuelAiGateway: FakeEdgeFuelAiGateway(
          nextResult: () => const EdgeFuelAiResult.consentRequired(),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GET TODAY\'S FIGHTER BRIEF').first);
      await tester.pumpAndSettle();

      expect(
        find.text('Allow AI coach data sharing to get an answer.'),
        findsOneWidget,
      );
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

    Finder aiSwitch() => find.descendant(
          of: find.ancestor(
            of: find.text('AI coach data sharing'),
            matching: find.byType(Row),
          ),
          matching: find.byType(Switch),
        );

    testWidgets('AI coach sharing can be withdrawn and given again',
        (tester) async {
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await openSettings(tester, repo);
      expect(tester.widget<Switch>(aiSwitch()).value, isTrue);

      await tester.tap(aiSwitch());
      await tester.pumpAndSettle();
      expect(repo.currentUser!.hasAiCoachConsent, isFalse);
      expect(repo.currentUser!.hasHealthDataConsent, isTrue);

      // Turning it back on shows the full disclosure first.
      await tester.tap(aiSwitch());
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('ai-coach-consent')), findsOneWidget);
      expect(repo.currentUser!.hasAiCoachConsent, isFalse);
      await tester.tap(find.text('I AGREE'));
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('ai-coach-consent')), findsNothing);
      expect(repo.currentUser!.hasAiCoachConsent, isTrue);
      expect(tester.widget<Switch>(aiSwitch()).value, isTrue);
    });

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
