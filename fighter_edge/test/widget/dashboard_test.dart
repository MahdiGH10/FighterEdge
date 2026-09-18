import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/models/training_session.dart';
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

  group('streak freeze', () {
    // AppState.completeSession always stamps `now`, so there is no public
    // way to put a *past* completion on the board through it. Seeding the
    // repository directly (as the real Firestore-backed app accumulates
    // history over actual days) is the honest way to get an "at risk" board
    // — alive through two days ago, nothing logged yesterday or today.
    Future<AppState> atRiskState(String userId) async {
      final repo = InMemoryDataRepository();
      final now = DateTime.now();
      Future<void> seed(String day, int daysAgo) => repo.saveSession(
            userId,
            TrainingSession(
              day: day,
              title: day,
              subtitle: '',
              icon: Icons.sports_mma,
              completed: true,
              completedAt: now.subtract(Duration(days: daysAgo)),
            ),
          );
      await seed('a', 2);
      await seed('b', 3);
      return AppState(dataRepository: repo)..setUser(userId);
    }

    testWidgets('is not shown when nothing is at risk', (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (_) {}),
        repo: repo,
        state: AppState(),
      ));
      await tester.pump();

      expect(find.text('Streak at risk'), findsNothing);
    });

    testWidgets('offers to spend a banked freeze, and using it clears it',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = await makeRepo(signedIn: true);
      final userId = repo.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('fe_streak.$userId.freezes', 1);

      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (_) {}),
        repo: repo,
        state: await atRiskState(userId),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Streak at risk'), findsOneWidget);
      expect(find.textContaining('(1 left)'), findsOneWidget);

      await tester.tap(find.text('FREEZE'));
      await tester.pumpAndSettle();

      expect(find.text('Streak at risk'), findsNothing);
      expect(
        find.text('Freeze used — yesterday is protected.'),
        findsOneWidget,
      );
    });

    testWidgets('offers to log instead when no freeze is banked',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final repo = await makeRepo(signedIn: true);
      var navigatedTo = -1;

      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (i) => navigatedTo = i),
        repo: repo,
        state: await atRiskState(repo.currentUser!.id),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Streak at risk'), findsOneWidget);
      expect(find.text('FREEZE'), findsNothing);

      await tester.tap(find.text('LOG NOW'));
      await tester.pump();
      expect(navigatedTo, 1); // Train tab, where sessions are completed
    });
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
