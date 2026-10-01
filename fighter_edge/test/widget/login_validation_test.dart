import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/models/app_user.dart';
import 'package:fighter_edge/screens/auth/login_screen.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

class CountingAuthRepository extends LocalAuthRepository {
  int signInCalls = 0;

  @override
  Future<AppUser> signInWithEmail(
      {required String email, required String password}) {
    signInCalls++;
    return super.signInWithEmail(email: email, password: password);
  }
}

Future<CountingAuthRepository> repository() async {
  SharedPreferences.setMockInitialValues({});
  final repo = CountingAuthRepository();
  await repo.init();
  return repo;
}

void main() {
  for (final german in [false, true]) {
    testWidgets(
        'inline sign-in errors prevent submission and clear, DE=$german',
        (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await repository();
      await tester.pumpWidget(wrapApp(
          Builder(
              builder: (context) => Localizations.override(
                    context: context,
                    locale: german ? const Locale('de') : const Locale('en'),
                    child: const LoginScreen(),
                  )),
          repo: repo));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(LoginScreen));
      final l = L.of(context);
      expect(find.text(l.authEmailRequired), findsOneWidget);
      expect(find.text(l.authPasswordRequired), findsOneWidget);
      expect(repo.signInCalls, 0);
      expect(
          tester
              .widget<TextField>(find.byType(TextField).first)
              .focusNode!
              .hasFocus,
          isTrue);
      await tester.enterText(find.byType(TextField).first, 'incomplete');
      await tester.pump();
      expect(find.text(l.authEmailIncomplete), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, testEmail);
      await tester.pump();
      expect(find.text(l.authEmailIncomplete), findsNothing);
      await tester.ensureVisible(find.byType(PrimaryButton));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .focusNode!
              .hasFocus,
          isTrue);
      expect(repo.signInCalls, 0);
      await tester.enterText(find.byType(TextField).last, testPassword);
      await tester.pump();
      expect(find.text(l.authPasswordRequired), findsNothing);
    });
  }

  testWidgets('keyboard submit permits a legacy six-character password',
      (tester) async {
    final repo = await repository();
    final legacyPassword = testPassword.substring(0, 6);
    await repo.signUpWithEmail(
        email: testEmail, password: legacyPassword, displayName: testName);
    await repo.signOut();
    await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, testEmail);
    await tester.enterText(find.byType(TextField).last, legacyPassword);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(repo.signInCalls, 1);
    expect(repo.currentUser, isNotNull);
  });

  for (final german in [false, true]) {
    testWidgets(
        'invalid keyboard submit remains readable at 200% high contrast, DE=$german',
        (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await repository();
      await tester.pumpWidget(wrapApp(
          MediaQuery(
            data: const MediaQueryData(
                size: Size(320, 844),
                devicePixelRatio: 1,
                textScaler: TextScaler.linear(2),
                highContrast: true,
                disableAnimations: true),
            child: Builder(
                builder: (context) => Localizations.override(
                      context: context,
                      locale: german ? const Locale('de') : const Locale('en'),
                      child: const LoginScreen(),
                    )),
          ),
          repo: repo));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'incomplete');
      await tester.enterText(find.byType(TextField).last, '');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      final l = L.of(tester.element(find.byType(LoginScreen)));
      for (final message in [l.authEmailIncomplete, l.authPasswordRequired]) {
        await tester.ensureVisible(find.text(message));
        await tester.pumpAndSettle();
        expect(
            tester
                .renderObject<RenderParagraph>(find.text(message))
                .didExceedMaxLines,
            isFalse);
      }
      expect(repo.signInCalls, 0);
      expect(tester.takeException(), isNull);
    });
  }
}
