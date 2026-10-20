import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';
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
    await tester.scrollUntilVisible(find.text('THIS WEEK'), 300);
    expect(find.text('THIS WEEK'), findsOneWidget);
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

  group('weekly target card', () {
    Future<(PlanController, AppState)> pumpHome(
      WidgetTester tester,
      DateTime now, {
      int days = 3,
      ValueChanged<int>? onNavigate,
    }) async {
      tester.view.physicalSize = const Size(430, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      final data = InMemoryDataRepository();
      final userId = repo.currentUser!.id;
      final state = AppState(dataRepository: data, clock: () => now)
        ..setUser(userId);
      // Three days a week is Mon, Wed, Fri.
      final plan = PlanController(log: state, repository: data)
        ..configure(userId: userId)
        ..startFresh(
            weeklyTrainingDays: days,
            goal: 'Build fight-camp structure',
            level: 'Beginner');
      await tester.pumpWidget(wrapApp(
          DashboardScreen(onNavigate: onNavigate ?? (_) {}),
          repo: repo,
          state: state,
          planController: plan));
      await tester.pumpAndSettle();
      return (plan, state);
    }

    final monday = DateTime(2026, 10, 19, 9);

    testWidgets('says how many sessions are done and what is next',
        (tester) async {
      await pumpHome(tester, monday);
      await tester.scrollUntilVisible(find.text('THIS WEEK'), 300);
      expect(find.text('0 of 3 done'), findsOneWidget);
      expect(find.text('Next: Wed Conditioning session'), findsOneWidget);
    });

    testWidgets('moves when a session is done', (tester) async {
      final (plan, _) = await pumpHome(tester, monday);
      plan.complete(plan.todaySession!.session, title: 'Skill session');
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('THIS WEEK'), 300);
      expect(find.text('1 of 3 done'), findsOneWidget);
    });

    testWidgets('tapping it opens the week to act on', (tester) async {
      var navigatedTo = -1;
      await pumpHome(tester, monday, onNavigate: (i) => navigatedTo = i);
      await tester.scrollUntilVisible(find.text('THIS WEEK'), 300);
      await tester.tap(find.text('0 of 3 done'));
      await tester.pump();
      expect(navigatedTo, 1);
    });

    testWidgets('a week with no sessions is a rest week, never a miss',
        (tester) async {
      // The plan starts on a Sunday, so the week it is in has nothing planned.
      await pumpHome(tester, DateTime(2026, 10, 25, 9));
      await tester.scrollUntilVisible(find.text('THIS WEEK'), 300);
      expect(find.text('Rest week'), findsOneWidget);
      expect(find.textContaining('missed'), findsNothing);
      expect(find.textContaining('Not done'), findsNothing);
    });

    testWidgets('no freeze banner and no daily streak any more',
        (tester) async {
      await pumpHome(tester, DateTime(2026, 10, 23, 20));
      expect(find.text('Streak at risk'), findsNothing);
      expect(find.text('Freeze'), findsNothing);
    });

    testWidgets('offers the weekly review on Sunday until it is answered',
        (tester) async {
      final (plan, _) =
          await pumpHome(tester, DateTime(2026, 10, 25, 20), days: 6);
      await tester.scrollUntilVisible(find.text('Weekly review'), 300);
      expect(find.text('Weekly review'), findsOneWidget);

      plan.recordReview(DateTime(2026, 10, 19), ReviewDecision.kept);
      await tester.pumpAndSettle();
      expect(find.text('Weekly review'), findsNothing);
    });

    testWidgets('offers no review in the middle of the week', (tester) async {
      await pumpHome(tester, DateTime(2026, 10, 22, 20));
      expect(find.text('Weekly review'), findsNothing);
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
