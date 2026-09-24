import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/change_password_sheet.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/settings_screen.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

/// Account actions in Settings, driven through the real app and router — the
/// bugs these guard against only exist when Settings is pushed above the
/// auth gate.
void main() {
  Future<void> openSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.settings);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
  }

  testWidgets('signing out from Settings lands on login, not a stale Settings',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();
    await openSettings(tester);

    await tester.tap(find.byType(GhostButton));
    await tester.pumpAndSettle();

    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets(
      'deleting a subscribed account warns that the store keeps billing',
      (tester) async {
    final repo =
        await makeRepo(signedIn: true, onboarded: true, plan: Plan.pro);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();
    await openSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('delete-subscription-warning')),
      findsOneWidget,
    );
    expect(find.textContaining("doesn't cancel your subscription"),
        findsOneWidget);
  });

  testWidgets('a free account sees no subscription warning', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();
    await openSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('delete-subscription-warning')),
      findsNothing,
    );
  });

  testWidgets('deleting the account from Settings lands on login',
      (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pump();
    await openSettings(tester);

    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Delete forever'));
    await tester.pumpAndSettle();

    expect(repo.currentUser, isNull);
    expect(find.byType(SettingsScreen), findsNothing);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  group('change password', () {
    Finder sheetButton() => find.descendant(
          of: find.byType(ChangePasswordSheet),
          matching: find.byType(PrimaryButton),
        );

    testWidgets('keeps the sheet open and marks a wrong current password',
        (tester) async {
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pump();
      await openSettings(tester);

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), 'not-it');
      await tester.enterText(find.byType(TextField).at(1), 'new-secret-22');
      await tester.enterText(find.byType(TextField).at(2), 'new-secret-22');
      await tester.tap(sheetButton());
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordSheet), findsOneWidget);
      expect(find.text('Your current password is incorrect.'), findsOneWidget);
    });

    testWidgets('updates the password and confirms it', (tester) async {
      final repo = await makeRepo(signedIn: true, onboarded: true);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pump();
      await openSettings(tester);

      await tester.tap(find.text('Change password'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).at(0), testPassword);
      await tester.enterText(find.byType(TextField).at(1), 'new-secret-22');
      await tester.enterText(find.byType(TextField).at(2), 'new-secret-22');
      await tester.tap(sheetButton());
      await tester.pumpAndSettle();

      expect(find.byType(ChangePasswordSheet), findsNothing);
      expect(find.text('Password updated.'), findsOneWidget);

      await repo.signOut();
      final user = await repo.signInWithEmail(
          email: testEmail, password: 'new-secret-22');
      expect(user.email, testEmail);
    });
  });
}
