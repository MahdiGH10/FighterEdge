import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/first_run_controller.dart';
import 'package:fighter_edge/widgets/coach_marks.dart';

import '../helpers/test_harness.dart';

/// The first-week layer, through the real app: checklist, tour, the first-win
/// moment, and the reminder ask that waits for it.
void main() {
  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  FoodLogEntry meal(String id) => FoodLogEntry(
        id: id,
        name: 'Oats',
        notes: '',
        calories: 350,
        proteinGrams: 12,
        carbGrams: 60,
        fatGrams: 6,
        source: FoodLogSource.manual,
        loggedAt: DateTime.now(),
      );

  testWidgets('a new account gets the checklist, tour and first-win moment',
      (tester) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('fe_first_run.${repo.currentUser!.id}.active', true);
    final reminders = FakeReminderGateway();

    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pumpAndSettle();
    expect(find.text('Your first week'), findsOneWidget);

    // The tour runs from the checklist, and skipping still counts as seen.
    await tester.tap(find.text('Take the 30-second tour'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachMarkLayer), findsOneWidget);
    expect(find.text('1 of 4'), findsOneWidget);
    await tester.tap(find.text('Skip tour'));
    await tester.pumpAndSettle();
    expect(find.byType(CoachMarkLayer), findsNothing);

    final shell = tester.element(find.byType(HomeShell));
    expect(shell.read<FirstRunController>().tourDone, isTrue);

    // First meal: celebrated, and only now are reminders offered.
    await shell.read<EdgeFuelController>().addEntry(meal('m1'));
    await tester.pumpAndSettle();
    expect(find.text('First meal logged.'), findsOneWidget);
    expect(find.text('Want a nudge on training days?'), findsOneWidget);

    await tester.tap(find.text('REMIND ME'));
    await tester.pumpAndSettle();
    expect(find.text('First meal logged.'), findsNothing);
    expect(shell.read<AppState>().campReminders, isTrue);
    expect(reminders.permissionRequests, 1);
    expect(reminders.scheduledWeekdays, isNotNull);

    // Later meals are just meals.
    await shell.read<EdgeFuelController>().addEntry(meal('m2'));
    await tester.pumpAndSettle();
    expect(find.text('First meal logged.'), findsNothing);
  });

  testWidgets('accounts set up before this never see the first-week layer',
      (tester) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);

    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    await tester.pumpAndSettle();
    expect(find.text('Your first week'), findsNothing);

    final shell = tester.element(find.byType(HomeShell));
    await shell.read<EdgeFuelController>().addEntry(meal('m1'));
    await tester.pumpAndSettle();
    expect(find.text('First meal logged.'), findsNothing);
  });
}
