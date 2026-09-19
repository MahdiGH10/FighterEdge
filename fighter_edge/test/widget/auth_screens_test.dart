import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/screens/auth/login_screen.dart';
import 'package:fighter_edge/screens/auth/signup_screen.dart';
import 'package:fighter_edge/screens/legal_screen.dart';
import 'package:fighter_edge/widgets/primary_button.dart';

import '../helpers/test_harness.dart';

/// Give tests a tall viewport so scrollable auth content is fully on-screen.
void useTallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('LoginScreen', () {
    testWidgets('renders and navigates to signup', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);

      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();
      expect(find.text('Start your camp'), findsOneWidget); // signup subtitle
    });

    testWidgets('password managers can fill and save the login',
        (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
      await tester.pumpAndSettle();

      expect(find.byType(AutofillGroup), findsOneWidget);
      final fields =
          tester.widgetList<TextField>(find.byType(TextField)).toList();
      final email = fields
          .firstWhere((f) => f.keyboardType == TextInputType.emailAddress);
      final password = fields.firstWhere((f) => f.obscureText);
      expect(email.autofillHints, contains(AutofillHints.email));
      expect(password.autofillHints, contains(AutofillHints.password));
      // A keyboard must never "correct" an email or suggest a password.
      expect(email.autocorrect, isFalse);
      expect(password.enableSuggestions, isFalse);
    });

    testWidgets('shows an error on bad credentials', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'nobody@test.com');
      await tester.enterText(find.byType(TextField).at(1), 'whatever');
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump(); // start async
      await tester.pump(const Duration(milliseconds: 50)); // finish + snackbar
      expect(find.text('No account found for this email.'), findsOneWidget);
    });

    testWidgets('hides auth methods the repository does not support',
        (tester) async {
      useTallScreen(tester);
      SharedPreferences.setMockInitialValues({});
      final repo = GoogleOnlyLocalAuthRepository();
      await repo.init();

      await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
      await tester.pump();

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Email me a sign-in code'), findsNothing);
    });
  });

  group('SignupScreen', () {
    Future<void> fillForm(
      WidgetTester tester, {
      String name = 'New Fighter',
      String email = 'new@fighter.com',
      String password = 'camp-ready-9',
      String? confirm,
    }) async {
      await tester.enterText(find.byType(TextField).at(0), name);
      await tester.enterText(find.byType(TextField).at(1), email);
      await tester.enterText(find.byType(TextField).at(2), password);
      await tester.enterText(find.byType(TextField).at(3), confirm ?? password);
      await tester.pump();
    }

    testWidgets('blocks submission until terms are accepted', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await fillForm(tester);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(find.text('Please accept the terms to create your account.'),
          findsOneWidget);
      expect(repo.currentUser, isNull);
    });

    testWidgets('shows inline errors instead of submitting a bad form',
        (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await fillForm(tester, email: 'not-an-email', password: 'short');
      await tester.tap(find.byType(Checkbox));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();

      expect(find.text('That email looks incomplete.'), findsOneWidget);
      expect(find.text('Use at least 8 characters.'), findsOneWidget);
      expect(repo.currentUser, isNull);
    });

    testWidgets('flags a confirmation that does not match', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      // Same length, different text: settled enough to be a real mismatch.
      await fillForm(tester, confirm: 'camp-ready-8');
      expect(find.text("Passwords don't match."), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(3), 'camp-ready-9');
      await tester.pump();
      expect(find.text("Passwords don't match."), findsNothing);
    });

    testWidgets('grades the password as it is typed', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(2), 'abc');
      await tester.pump();
      expect(find.text('At least 8 characters'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), 'password');
      await tester.pump();
      expect(find.text('Weak — try a longer phrase'), findsOneWidget);

      await tester.enterText(find.byType(TextField).at(2), 'Southpaw-Jab-42');
      await tester.pump();
      expect(find.text('Strong'), findsOneWidget);
    });

    testWidgets('opens the Terms from the agreement line', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await tester.tap(find.text('Terms'));
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(find.textContaining('full Terms of Service'), findsOneWidget);
    });

    testWidgets('creates an account when the form is valid', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await fillForm(tester);
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();

      expect(repo.currentUser?.email, 'new@fighter.com');
    });
  });
}

class GoogleOnlyLocalAuthRepository extends LocalAuthRepository {
  @override
  bool get supportsApple => false;

  @override
  bool get supportsMagicLink => false;
}
