import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_display_mode.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/notifications/domain/notification_channel.dart';
import 'package:fighter_edge/notifications/notification_controller.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/notifications/notification_settings_screen.dart';
import 'package:fighter_edge/widgets/grouped_list.dart';

import '../helpers/test_harness.dart';

/// Which channels Settings offers, and to whom. The fuel window is a nutrition
/// note: only an adult with a confirmed Fuel setup sees it.
void main() {
  late FakeReminderGateway gateway;

  /// [age] null means no confirmed Fuel setup.
  Future<void> open(WidgetTester tester,
      {int? age, bool confirmed = true, NutritionDisplayMode? mode}) async {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = await makeRepo(signedIn: true, onboarded: true);
    if (mode != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'fe_nutrition_mode.${repo.currentUser!.id}', mode.storageName);
    }
    final fuelRepo = InMemoryEdgeFuelRepository();
    if (age != null) {
      await fuelRepo.saveProfileDraft(
        repo.currentUser!.id,
        NutritionSetupDraft(
            ageYears: age,
            confirmed: confirmed,
            screeningStatus: NutritionScreeningStatus.completed),
      );
    }
    gateway = FakeReminderGateway();
    await tester.pumpWidget(FighterEdgeApp(
      authRepo: repo,
      edgeFuelRepo: fuelRepo,
      reminderGateway: gateway,
    ));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.notificationSettings);
    await tester.pumpAndSettle();
    expect(find.byType(NotificationSettingsScreen), findsOneWidget);
  }

  Finder row(String title) => find.ancestor(
        of: find.text(title),
        matching: find.byType(GroupedRow),
      );

  Finder switchFor(String title) =>
      find.descendant(of: row(title), matching: find.byType(Switch));

  NotificationController controller(WidgetTester tester) => tester
      .element(find.byType(NotificationSettingsScreen))
      .read<NotificationController>();

  testWidgets('everyone sees the session, review and fight rows',
      (tester) async {
    await open(tester);
    expect(row('Session reminder'), findsOneWidget);
    expect(row('Weekly review'), findsOneWidget);
    expect(row('Fight countdown'), findsOneWidget);
  });

  testWidgets('no fuel window or nutrition switch without a Fuel setup',
      (tester) async {
    await open(tester);
    expect(row('Fuel window'), findsNothing);
  });

  testWidgets('an unconfirmed Fuel setup does not unlock them', (tester) async {
    await open(tester, age: 30, confirmed: false);
    expect(row('Fuel window'), findsNothing);
  });

  testWidgets('under 18 never sees the fuel window', (tester) async {
    await open(tester, age: 17);
    expect(row('Fuel window'), findsNothing);
  });

  testWidgets('an adult with a confirmed setup does', (tester) async {
    await open(tester, age: 18);
    expect(row('Fuel window'), findsOneWidget);
    expect(tester.widget<Switch>(switchFor('Fuel window')).value, isFalse);
  });

  testWidgets(
      'paused nutrition takes the fuel window row away, even for an adult',
      (tester) async {
    await open(tester, age: 30, mode: NutritionDisplayMode.paused);
    expect(row('Fuel window'), findsNothing);
    // The other reminders are untouched.
    expect(row('Session reminder'), findsOneWidget);
    expect(row('Weekly review'), findsOneWidget);
    expect(row('Fight countdown'), findsOneWidget);
  });

  testWidgets('switching the fuel window on asks once and turns it on',
      (tester) async {
    await open(tester, age: 30);
    await tester.tap(switchFor('Fuel window'));
    await tester.pumpAndSettle();

    expect(gateway.permissionRequests, 1);
    expect(tester.widget<Switch>(switchFor('Fuel window')).value, isTrue);
    expect(
      controller(tester).settings.isEnabled(NotificationChannel.fuelWindow),
      isTrue,
    );
  });

  testWidgets('the fight countdown switch asks once and turns on',
      (tester) async {
    await open(tester);
    await tester.tap(switchFor('Fight countdown'));
    await tester.pumpAndSettle();
    expect(gateway.permissionRequests, 1);
    expect(
      controller(tester).settings.isEnabled(NotificationChannel.fightCountdown),
      isTrue,
    );
  });

  testWidgets('the trial notice has no switch of its own', (tester) async {
    await open(tester, age: 30);
    expect(find.textContaining('trial'), findsNothing);
  });

  testWidgets('the screen holds at 200% text on a 320 px phone with every row',
      (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    final repo = await makeRepo(signedIn: true, onboarded: true);
    final fuelRepo = InMemoryEdgeFuelRepository();
    await fuelRepo.saveProfileDraft(
      repo.currentUser!.id,
      const NutritionSetupDraft(
          ageYears: 30,
          confirmed: true,
          screeningStatus: NutritionScreeningStatus.completed),
    );
    await tester.pumpWidget(FighterEdgeApp(
      authRepo: repo,
      edgeFuelRepo: fuelRepo,
      reminderGateway: FakeReminderGateway(),
    ));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.byType(HomeShell)))
        .push(AppRoutes.notificationSettings);
    await tester.pumpAndSettle();

    for (final title in ['Fuel window', 'Fight countdown']) {
      // The list builds rows lazily: scroll until the row exists.
      await tester.scrollUntilVisible(
        row(title),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      expect(row(title), findsOneWidget);
    }
    expect(tester.takeException(), isNull);
  });
}
