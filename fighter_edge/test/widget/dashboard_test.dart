import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/theme/app_theme.dart';

import '../helpers/test_harness.dart';

void main() {
  testWidgets('shows the fighter, sections and live weight', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState();
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    expect(find.text('DASHBOARD'), findsOneWidget);
    expect(find.text('Ayoub'), findsOneWidget);
    expect(find.text('WEEKLY OVERVIEW'), findsOneWidget);
    expect(find.text('77.2'), findsWidgets); // weight stat from AppState
  });

  testWidgets('weight card reacts to AppState changes', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState();
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    state.addWeight(DateTime.now(), 75.0);
    await tester.pumpAndSettle(MotionTokens.standard);
    expect(find.text('75.0'), findsWidgets);
  });

  testWidgets('unverified users can request another verification email',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final repo = VerificationLocalAuthRepository();
    await repo.init();
    await repo.signUpWithEmail(
      email: testEmail,
      password: testPassword,
      displayName: testName,
    );

    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: AppState(),
    ));
    await tester.pump();

    expect(find.text('Verify your email'), findsOneWidget);

    // Resend moved off the banner and onto the screen that can actually
    // resolve this: a bare "Resend" told the user nothing about whether the
    // address was ever confirmed.
    await tester.tap(find.text('Verify your email'));
    // Not pumpAndSettle: the verify screen polls on a periodic timer and so
    // never reaches a settled state by design.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('RESEND EMAIL'), findsOneWidget);
    await tester.tap(find.text('RESEND EMAIL'));
    await tester.pump();

    expect(repo.verificationSent, isTrue);
    expect(find.text('Verification email sent.'), findsWidgets);

    // The verify screen polls on a timer; tear it down before the test ends.
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

class VerificationLocalAuthRepository extends LocalAuthRepository {
  bool verificationSent = false;

  @override
  bool get supportsEmailVerification => true;

  @override
  Future<void> sendEmailVerification() async {
    verificationSent = true;
  }
}
