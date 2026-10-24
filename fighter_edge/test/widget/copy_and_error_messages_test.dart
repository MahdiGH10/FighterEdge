import 'package:fighter_edge/auth/auth_repository.dart';
import 'package:fighter_edge/auth/local_auth_repository.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/screens/delete_account_flow.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

/// A repository whose deletion fails the way a real network or plugin
/// failure would: with an error whose text was never meant for the athlete.
class _FailingDeleteRepository extends LocalAuthRepository {
  final Object error;
  _FailingDeleteRepository(this.error);

  @override
  Future<void> deleteAccount() async => throw error;
}

Future<void> _deleteThroughDialog(WidgetTester tester) async {
  await tester.tap(find.text('Delete'));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField), 'DELETE');
  await tester.pump();
  await tester.tap(find.text('Delete forever'));
  await tester.pumpAndSettle();
}

Future<_FailingDeleteRepository> _signedIn(Object error) async {
  SharedPreferences.setMockInitialValues({});
  final repo = _FailingDeleteRepository(error);
  await repo.init();
  await repo.signUpWithEmail(
    email: 'delete@test.com',
    password: testPassword,
    displayName: 'Delete Tester',
  );
  return repo;
}

Widget _deleteButton() => Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => confirmAndDeleteAccount(context),
            child: const Text('Delete'),
          ),
        ),
      ),
    );

void main() {
  group('Account deletion failure', () {
    testWidgets('shows plain words, never the raw exception', (tester) async {
      final repo = await _signedIn(StateError('PlatformException(uid=abc)'));
      await tester.pumpWidget(wrapApp(_deleteButton(), repo: repo));
      await tester.pumpAndSettle();

      await _deleteThroughDialog(tester);

      expect(
        find.text(
            "Couldn't delete your account. Check your connection and try again."),
        findsOneWidget,
      );
      expect(find.textContaining('PlatformException'), findsNothing);
      expect(find.textContaining('uid'), findsNothing);
    });

    testWidgets('keeps a message the repository wrote for the athlete',
        (tester) async {
      final repo = await _signedIn(const AuthException(
          'requires-recent-login', 'Sign in again, then delete.'));
      await tester.pumpWidget(wrapApp(_deleteButton(), repo: repo));
      await tester.pumpAndSettle();

      await _deleteThroughDialog(tester);

      expect(find.text('Sign in again, then delete.'), findsOneWidget);
    });
  });

  testWidgets('Home says "1 week", not "1 weeks"', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final state = AppState(clock: () => DateTime(2026, 10, 19, 9));
    final plan = PlanController(log: state)
      ..startFresh(
          weeklyTrainingDays: 3, goal: 'Gain muscle', level: 'Beginner');
    for (final session in plan.currentWeek!.sessions) {
      plan.complete(session, title: 'Session');
    }

    await tester.pumpWidget(wrapApp(DashboardScreen(onNavigate: (_) {}),
        repo: repo, state: state, planController: plan));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(find.text('Streak'), 200);
    expect(find.text('week'), findsOneWidget);
    expect(find.text('weeks'), findsNothing);
  });
}
