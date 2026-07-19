import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/screens/auth/login_screen.dart';
import 'package:fighter_edge/screens/auth/signup_screen.dart';
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
    testWidgets('blocks submission until terms are accepted', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const SignupScreen(), repo: repo));
      await tester.pump();

      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(find.text('Please accept the terms to create your account.'),
          findsOneWidget);
      expect(repo.currentUser, isNull);
    });

    testWidgets('creates an account when the form is valid', (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo();
      await tester.pumpWidget(wrapApp(const LoginScreen(), repo: repo));
      await tester.pump();

      // Go to signup via the real flow so pop() has somewhere to return to.
      await tester.tap(find.text('Create account'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(0), 'New Fighter');
      await tester.enterText(find.byType(TextField).at(1), 'new@fighter.com');
      await tester.enterText(find.byType(TextField).at(2), 'secret1');
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
