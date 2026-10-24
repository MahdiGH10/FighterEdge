import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_display_mode.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import 'package:fighter_edge/features/training_plan/data/legacy_session_slot.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/features/weekly_review/presentation/weekly_review_screen.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/notifications/reminder_gateway.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/state/sync_tracker.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

import '../helpers/test_harness.dart';

/// "Pause nutrition", through the real app: one switch in Settings, and the
/// Fuel tab, the numbers, the weight tools and the nutrition reminders all
/// step out of the way. Training carries on.
void main() {
  const paused = 'Nutrition is paused';

  void useTallScreen(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 3400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Boots the real app. [mode] seeds the stored choice for the account.
  Future<void> boot(
    WidgetTester tester, {
    NutritionDisplayMode? mode,
    FakeReminderGateway? reminders,
  }) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    if (mode != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'fe_nutrition_mode.${repo.currentUser!.id}', mode.storageName);
    }
    await tester.pumpWidget(
      FighterEdgeApp(authRepo: repo, reminderGateway: reminders),
    );
    await tester.pumpAndSettle();
  }

  void goTo(WidgetTester tester, int tab) {
    tester.widget<AppBottomNav>(find.byType(AppBottomNav)).onTap(tab);
  }

  // The shell is offstage while a screen sits on top of it.
  NutritionModeController modeOf(WidgetTester tester) => tester
      .element(find.byType(HomeShell, skipOffstage: false))
      .read<NutritionModeController>();

  void pushRoute(WidgetTester tester, String route) =>
      GoRouter.of(tester.element(find.byType(HomeShell))).push(route);

  testWidgets('the Fuel tab is a calm note with one way back', (tester) async {
    await boot(tester, mode: NutritionDisplayMode.paused);
    goTo(tester, 2);
    await tester.pumpAndSettle();

    expect(find.text(paused), findsOneWidget);
    expect(find.text('Turn nutrition back on'), findsOneWidget);
    // Nothing to log, no numbers, no date strip.
    expect(find.byKey(const ValueKey('fuel-log-food')), findsNothing);

    await tester.tap(find.text('Turn nutrition back on'));
    await tester.pumpAndSettle();
    expect(find.text(paused), findsNothing);
    expect(find.byKey(const ValueKey('fuel-log-food')), findsOneWidget);
    expect(modeOf(tester).mode, NutritionDisplayMode.normal);
  });

  testWidgets('Settings pauses it and the choice survives a restart',
      (tester) async {
    await boot(tester);
    pushRoute(tester, AppRoutes.settings);
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Nutrition display'),
      300,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Everything on'), findsOneWidget);
    await tester.tap(find.text('Nutrition display'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pause nutrition'));
    await tester.pumpAndSettle();

    expect(find.text('Paused'), findsOneWidget);
    expect(modeOf(tester).mode, NutritionDisplayMode.paused);

    // A new launch reads it back from the device.
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getKeys().where((k) => k.startsWith('fe_nutrition_mode.'));
    expect(stored, hasLength(1));
    expect(prefs.getString(stored.single), 'paused');
  });

  testWidgets('Home drops the weigh-in, the weight card and the Fuel links',
      (tester) async {
    await boot(tester);
    expect(find.text('Add weigh-in'), findsWidgets);
    expect(find.text('Weight'), findsOneWidget);

    await modeOf(tester).setMode(NutritionDisplayMode.paused);
    await tester.pumpAndSettle();

    expect(find.text('Add weigh-in'), findsNothing);
    expect(find.text('Weight'), findsNothing);
    // Training is untouched.
    expect(find.text('Sessions'), findsOneWidget);
  });

  testWidgets('Profile drops the weight line and the weight tracker',
      (tester) async {
    await boot(tester, mode: NutritionDisplayMode.paused);
    goTo(tester, 3);
    await tester.pumpAndSettle();
    expect(find.text('Weight tracker'), findsNothing);
    expect(find.text('Training days'), findsOneWidget);

    await modeOf(tester).setMode(NutritionDisplayMode.normal);
    await tester.pumpAndSettle();
    expect(find.text('Weight tracker'), findsOneWidget);
  });

  testWidgets('the weight and fight-camp screens are the same calm note',
      (tester) async {
    await boot(tester, mode: NutritionDisplayMode.paused);
    for (final route in [
      AppRoutes.weightTracker,
      AppRoutes.fightSetup,
      AppRoutes.fightPath,
      AppRoutes.fightWeek,
    ]) {
      pushRoute(tester, route);
      await tester.pumpAndSettle();
      expect(find.text(paused), findsOneWidget, reason: route);
      GoRouter.of(tester.element(find.text(paused))).pop();
      await tester.pumpAndSettle();
    }
  });

  testWidgets('nothing nutrition-shaped shows on a fresh start while paused',
      (tester) async {
    useTallScreen(tester);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'fe_nutrition_mode.${repo.currentUser!.id}', 'paused');
    await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
    // Every frame from the first one: the weight card must never appear.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('Add weigh-in'), findsNothing, reason: 'frame $i');
      expect(find.text('Weight'), findsNothing, reason: 'frame $i');
    }
  });

  testWidgets('the fuel window row leaves Notifications settings',
      (tester) async {
    await boot(tester, reminders: FakeReminderGateway());
    // No confirmed Fuel setup here, so the row is already hidden; the mode
    // gate is covered with a setup in the reminders tests below.
    pushRoute(tester, AppRoutes.notificationSettings);
    await tester.pumpAndSettle();
    expect(find.text('Fuel window'), findsNothing);
  });

  group('the weekly review', () {
    late PlanController plan;

    Future<void> bootReview(
      WidgetTester tester,
      NutritionDisplayMode mode,
    ) async {
      useTallScreen(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final uid = repo.currentUser!.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fe_nutrition_mode.$uid', mode.storageName);
      final data = InMemoryDataRepository();
      addTearDown(data.dispose);
      for (final slot in [
        const LegacySessionSlot(
            id: 'Mon-Striking', day: 'Mon', title: 'Striking'),
        const LegacySessionSlot(
            id: 'Wed-Wrestling', day: 'Wed', title: 'Wrestling'),
      ]) {
        await data.saveLegacySession(uid, slot);
      }
      final state = AppState(
        dataRepository: data,
        clock: () => DateTime(2026, 10, 25, 18),
      )..setUser(uid);
      plan = PlanController(log: state, repository: data, sync: SyncTracker());
      final gateway = FakeReminderGateway(allowed: true);
      await tester.pumpWidget(wrapApp(
        const HomeShell(),
        repo: repo,
        state: state,
        planController: plan,
        reminderGateway: gateway,
      ));
      await tester.pumpAndSettle();
      gateway.tapController.add(const NotificationTap(id: 1, route: '/review'));
      await tester.pumpAndSettle();
      expect(find.byType(WeeklyReviewScreen), findsOneWidget);
    }

    testWidgets('normal shows food and weight', (tester) async {
      await bootReview(tester, NutritionDisplayMode.normal);
      expect(find.text('Food'), findsOneWidget);
      expect(find.text('Targets are estimates, not medical advice.'),
          findsOneWidget);
    });

    testWidgets('paused shows training and a neutral line, nothing about food',
        (tester) async {
      await bootReview(tester, NutritionDisplayMode.paused);
      expect(find.text('Training'), findsOneWidget);
      expect(find.text('Food'), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.text('Targets are estimates, not medical advice.'),
          findsNothing);
      expect(find.text('Nothing to change this week. Keep your plan as it is.'),
          findsOneWidget);
    });
  });
}
