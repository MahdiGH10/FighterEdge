import 'package:fighter_edge/screens/profile_screen.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

/// Regression tests for the 2026-09-17 visual audit findings 1 and 2:
/// Profile rendered `MockData.fighter` (a different person's name, a removed
/// weight-class label, and fabricated lifetime stats), and the Train week
/// header was a hardcoded "WEEK 4 / PEAK / May 20 – May 26" string.
///
/// The shared harness's [testName] happens to be 'Ayoub', the same name the
/// old mock used — so these tests sign up with a deliberately distinct name.
/// Asserting against the harness default would pass even if the mock came
/// back.
const _realName = 'Distinct Realuser';
const _realGoal = 'Get competition ready';

Future<LocalAuthRepository> _repoWithRealUser(
    {int weeklyTrainingDays = 5}) async {
  SharedPreferences.setMockInitialValues({});
  final repo = LocalAuthRepository();
  await repo.init();
  await repo.signUpWithEmail(
    email: 'distinct@test.com',
    password: testPassword,
    displayName: _realName,
  );
  await repo.completeOnboarding(
    goal: _realGoal,
    experienceLevel: 'Advanced',
    weeklyTrainingDays: weeklyTrainingDays,
    startingWeightKg: 81.5,
  );
  return repo;
}

void main() {
  group('Profile identity comes from the real account', () {
    testWidgets('renders the signed-in name and camp goal, not mock data',
        (tester) async {
      final repo = await _repoWithRealUser();

      await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      expect(find.text(_realName), findsOneWidget);
      expect(find.text(_realGoal), findsOneWidget);
    });

    testWidgets('never shows the removed weight-class division label',
        (tester) async {
      final repo = await _repoWithRealUser();

      await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      // Weight class was deliberately removed from the product. The old mock
      // reintroduced it as an identity label.
      expect(find.text('Amateur Lightweight'), findsNothing);
    });

    testWidgets('shows no fabricated fight record or lifetime totals',
        (tester) async {
      final repo = await _repoWithRealUser();

      await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      // The app never collects a win/loss record, so it must not display one.
      expect(find.text('Win / Loss'), findsNothing);
      // Mock lifetime values that used to render here.
      expect(find.text('128'), findsNothing);
      expect(find.text('312'), findsNothing);
      expect(find.text('24 days'), findsNothing);
      // Goals were never user-settable; the fake progress rows are gone.
      expect(find.text('Improve striking'), findsNothing);
      expect(find.text('Get to 74 kg'), findsNothing);
    });

    testWidgets('stats reflect real state and the onboarding answer',
        (tester) async {
      final repo = await _repoWithRealUser(weeklyTrainingDays: 6);
      // A default AppState with no repository seeds sample sessions, so build
      // the expectation from the same state the screen reads.
      final state = AppState();

      await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: state),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sessions Completed'), findsOneWidget);
      expect(find.text('${state.completedSessionCount}'), findsWidgets);
      expect(find.text('${state.currentStreakDays} days'), findsOneWidget);
      // Straight from the onboarding answer, not a constant.
      expect(find.text('Training Days / Week'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });
  });

  group('Train week header is derived, not hardcoded', () {
    testWidgets('shows week 1 for a brand-new account and no fake phase badge',
        (tester) async {
      final repo = await _repoWithRealUser();

      await tester.pumpWidget(
        wrapApp(const TrainingCampScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      // The account was created moments ago, so it is in its first camp week.
      expect(find.text('WEEK 1'), findsOneWidget);
      expect(find.text('WEEK 4'), findsNothing);
      // 'PEAK' was a hardcoded phase badge with no backing data.
      expect(find.text('PEAK'), findsNothing);
      expect(find.text('May 20 – May 26'), findsNothing);
    });

    testWidgets('date range covers the current Monday-to-Sunday week',
        (tester) async {
      final repo = await _repoWithRealUser();

      await tester.pumpWidget(
        wrapApp(const TrainingCampScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      final now = DateTime.now();
      final weekStart = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: now.weekday - DateTime.monday));
      final weekEnd = weekStart.add(const Duration(days: 6));
      String format(DateTime d) {
        const months = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec',
        ];
        return '${months[d.month - 1]} ${d.day}';
      }

      expect(
        find.text('${format(weekStart)} – ${format(weekEnd)}'),
        findsOneWidget,
      );
    });
  });
}
