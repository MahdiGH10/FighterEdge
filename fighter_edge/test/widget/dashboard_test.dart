import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/models/training_log_entry.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/theme/app_theme.dart';

import '../helpers/test_harness.dart';

void main() {
  final wednesday = DateTime(2026, 9, 23, 20);
  testWidgets('shows the fighter, sections and live weight', (tester) async {
    final repo = await makeRepo(signedIn: true);
    final state = AppState(clock: () => wednesday);
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    expect(find.text('Ayoub'), findsOneWidget);
    expect(find.text('Ayoub'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('This week'), 300);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('77.2'), findsWidgets); // weight stat from AppState
  });

  testWidgets('weight card reacts to AppState changes', (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    final state = AppState(clock: () => wednesday);
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pump();

    state.addWeight(state.weights.last.date.add(const Duration(days: 1)), 75.0);
    await tester.pumpAndSettle(MotionTokens.standard);
    expect(find.text('75.0'), findsWidgets);
  });

  testWidgets('one hero starts the exact session planned for today',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    final data = InMemoryDataRepository();
    final userId = repo.currentUser!.id;
    final state = AppState(dataRepository: data, clock: () => wednesday)
      ..setUser(userId);
    // Three days a week is Mon, Wed, Fri: Wednesday has a session.
    final plan = PlanController(log: state, repository: data)
      ..configure(userId: userId)
      ..startFresh(
          weeklyTrainingDays: 3,
          goal: 'Build fight-camp structure',
          level: 'Beginner');
    await tester.pumpWidget(wrapApp(DashboardScreen(onNavigate: (_) {}),
        repo: repo, state: state, planController: plan));
    await tester.pumpAndSettle();
    expect(find.byType(PrimaryButton), findsOneWidget);
    expect(find.text('Skill session'), findsOneWidget);
    expect(find.text('45 min'), findsOneWidget);
    expect(find.text('Streak'), findsOneWidget);
    expect(find.text('Why this target matters'), findsNothing);
    await tester.tap(find.byTooltip('Why this target matters'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Calories support'), findsOneWidget);
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start session'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<RoundTimerScreen>(find.byType(RoundTimerScreen))
            .session
            ?.id,
        plan.todaySession!.session.id);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('dashboard labels fit at 320px and text scale $scale',
        (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(DashboardScreen(onNavigate: (_) {}),
          repo: repo,
          state: AppState(
              dataRepository: InMemoryDataRepository(),
              clock: () => wednesday)));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Add weigh-in'), 150);
      final label = tester.widget<Text>(find.text('Add weigh-in'));
      expect(label.maxLines, isNull);
      expect(label.overflow, isNot(TextOverflow.ellipsis));
      expect(tester.takeException(), isNull);
    });
  }

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
      state: AppState(clock: () => wednesday),
    ));
    await tester.pump();

    await tester.scrollUntilVisible(find.text('Verify your email'), 300);
    await tester.ensureVisible(find.text('Verify your email'));
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

    expect(find.text('Resend email'), findsOneWidget);
    await tester.tap(find.text('Resend email'));
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
      final now = wednesday;
      Future<void> seed(String day, int daysAgo) => repo.saveLegacySession(
            userId,
            LegacySessionSlot(
              id: day,
              day: day,
              title: day,
              completed: true,
              completedAt: now.subtract(Duration(days: daysAgo)),
            ),
          );
      await seed('a', 2);
      await seed('b', 3);
      return AppState(dataRepository: repo, clock: () => wednesday)
        ..setUser(userId);
    }

    testWidgets('is not shown when nothing is at risk', (tester) async {
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (_) {}),
        repo: repo,
        state: AppState(clock: () => wednesday),
      ));
      await tester.pump();

      expect(find.text('Streak at risk'), findsNothing);
    });

    testWidgets('demo streak is at risk on Saturday', (tester) async {
      tester.view.physicalSize = const Size(430, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      // Monday to Thursday trained, nothing on Friday, and it is Saturday.
      final saturday = DateTime(2026, 9, 26, 20);
      final state = AppState(clock: () => saturday);
      for (var day = 21; day <= 24; day++) {
        state.addTrainingLogEntry(TrainingLogEntry(
          id: 'log-$day',
          completedAt: DateTime(2026, 9, day, 18),
          source: TrainingSource.planned,
          title: 'Session',
        ));
      }
      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (_) {}),
        repo: repo,
        state: state,
      ));
      await tester.pumpAndSettle();
      expect(find.text('Streak at risk'), findsOneWidget);
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

      await tester.scrollUntilVisible(find.text('Streak at risk'), 300);
      expect(find.text('Streak at risk'), findsOneWidget);
      expect(find.textContaining('(1 left)'), findsOneWidget);

      await tester.ensureVisible(find.text('Freeze'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Freeze'));
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

      await tester.scrollUntilVisible(find.text('Streak at risk'), 300);
      expect(find.text('Streak at risk'), findsOneWidget);
      expect(find.text('Freeze'), findsNothing);

      await tester.ensureVisible(find.text('Log now'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log now'));
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
