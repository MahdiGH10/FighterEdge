import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Widget tests for the three interactive features.
void main() {
  group('Round timer', () {
    testWidgets('counts down, pauses, and resets', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: RoundTimerScreen(),
      ));
      await tester.pump();

      expect(find.text('05:00'), findsWidgets); // MMA default work
      expect(find.text('1 / 5'), findsOneWidget);

      await tester.tap(find.text('START'));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('04:58'), findsWidgets);

      await tester.tap(find.text('PAUSE'));
      await tester.pump(const Duration(seconds: 2));
      expect(find.text('04:58'), findsWidgets); // frozen

      await tester.tap(find.text('RESET'));
      await tester.pump();
      expect(find.text('05:00'), findsWidgets);
    });

    testWidgets('switching style changes rounds and work time', (tester) async {
      await tester.pumpWidget(const MaterialApp(
        localizationsDelegates: L.localizationsDelegates,
        supportedLocales: L.supportedLocales,
        home: RoundTimerScreen(),
      ));
      await tester.pump();

      await tester.tap(find.text('Boxing'));
      await tester.pump();
      expect(find.text('1 / 12'), findsOneWidget);
      expect(find.text('03:00'), findsWidgets);
    });
  });

  group('Nutrition', () {
    test('toggling a meal recomputes calories', () async {
      final controller =
          EdgeFuelController(repository: InMemoryEdgeFuelRepository())
            ..setUser('u1');
      await Future<void>.delayed(Duration.zero);
      await controller.addEntry(FoodLogEntry(
        id: 'breakfast',
        name: 'Breakfast',
        notes: 'Eggs and toast',
        calories: 620,
        proteinGrams: 45,
        carbGrams: 55,
        fatGrams: 20,
        loggedAt: DateTime(2026, 7, 27, 8),
      ));
      final before = controller.consumedCalories;

      await controller.toggleEntry(controller.entries.single);
      expect(controller.consumedCalories, before - 620);
      controller.dispose();
    });

    test('date switching keeps historical logs separate', () async {
      final controller =
          EdgeFuelController(repository: InMemoryEdgeFuelRepository())
            ..setUser('u1');
      await Future<void>.delayed(Duration.zero);
      await controller.addEntry(FoodLogEntry(
        id: 'today',
        name: 'Today meal',
        notes: '',
        calories: 410,
        proteinGrams: 30,
        carbGrams: 38,
        fatGrams: 12,
        loggedAt: DateTime.now(),
      ));
      controller.shiftDate(-1);
      await Future<void>.delayed(Duration.zero);

      expect(controller.entries, isEmpty);
      controller.dispose();
    });
  });

  group('Weight tracker', () {
    // Unit preference persists; one test switching to pounds must not leak
    // into the next.
    setUp(() => SharedPreferences.setMockInitialValues({}));

    Widget trackerHost(AppState state, {EdgeFuelController? fuel}) =>
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: state),
            ChangeNotifierProvider.value(
              value: fuel ??
                  EdgeFuelController(
                    repository: InMemoryEdgeFuelRepository(),
                  ),
            ),
          ],
          child: const MaterialApp(home: WeightTrackerScreen()),
        );

    testWidgets('adding a weigh-in updates the number and history',
        (tester) async {
      await tester.pumpWidget(trackerHost(AppState()));
      await tester.pump();
      expect(find.text('77.2'), findsWidgets);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '75.0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('75.0'), findsWidgets); // headline
      await tester.scrollUntilVisible(find.text('75.0 kg'), 240,
          scrollable: find.byType(Scrollable).first);
      expect(find.text('75.0 kg'), findsOneWidget); // history row
    });

    testWidgets('non-weight tabs show an empty state and hide the FAB',
        (tester) async {
      await tester.pumpWidget(trackerHost(AppState()));
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.text('Body Fat'));
      await tester.pumpAndSettle(); // let the FAB exit animation finish
      expect(find.text('Body Fat'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('reads and records in pounds when metric is off',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final state = AppState();
      await tester.pump(); // let saved settings load before changing one
      await state.setUseMetricUnits(false);

      await tester.pumpWidget(trackerHost(state));
      await tester.pump();
      // The seed's latest 77.2 kg, shown as pounds with the pound label.
      expect(find.text('170.2'), findsWidgets);
      expect(find.text('lb'), findsWidgets);

      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      expect(find.text('lb'), findsWidgets); // the input's suffix
      await tester.enterText(find.byType(TextField), '165.0');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      // Stored in kg, whatever the user typed in.
      expect(state.latestWeight, closeTo(74.84, 0.01));
    });

    testWidgets('measures the gap to the EdgeFuel target weight',
        (tester) async {
      final repo = InMemoryEdgeFuelRepository();
      await repo.saveProfileDraft(
          'u1', const NutritionSetupDraft(targetWeightKg: 72));
      final fuel = EdgeFuelController(repository: repo)..setUser('u1');

      await tester.pumpWidget(trackerHost(AppState(), fuel: fuel));
      await tester.pumpAndSettle(); // the draft arrives on a stream
      // Seed latest is 77.2 kg: 5.2 to go, to the user's own 72.
      expect(find.text('GOAL GAP'), findsOneWidget);
      expect(find.text('5.2'), findsOneWidget);
      expect(find.text('To 72.0 kg'), findsOneWidget);
    });

    testWidgets('has no goal until one is set in EdgeFuel', (tester) async {
      await tester.pumpWidget(trackerHost(AppState()));
      await tester.pump();
      expect(find.text('Set in EdgeFuel'), findsOneWidget);
      // The old made-up 74 kg goal is gone.
      expect(find.text('GOAL GAP'), findsNothing);
      expect(find.text('To 74 kg'), findsNothing);
    });
  });
}
