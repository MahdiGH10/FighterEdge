import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/screens/round_timer_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/state/app_state.dart';

/// Nutrition screen now shows an EdgeFuel entry card, so it needs an
/// [EdgeFuelController] in the tree alongside [AppState].
Widget _wrapNutrition(AppState state) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: state),
      ChangeNotifierProvider(
        create: (_) =>
            EdgeFuelController(repository: InMemoryEdgeFuelRepository()),
      ),
    ],
    child: const MaterialApp(home: NutritionScreen()),
  );
}

/// Widget tests for the three interactive features.
void main() {
  group('Round timer', () {
    testWidgets('counts down, pauses, and resets', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: RoundTimerScreen()));
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
      await tester.pumpWidget(const MaterialApp(home: RoundTimerScreen()));
      await tester.pump();

      await tester.tap(find.text('Boxing'));
      await tester.pump();
      expect(find.text('1 / 12'), findsOneWidget);
      expect(find.text('03:00'), findsWidgets);
    });
  });

  group('Nutrition', () {
    testWidgets('toggling a meal recomputes calories', (tester) async {
      final state = AppState();
      final before = state.consumedCalories;
      await tester.pumpWidget(_wrapNutrition(state));
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Breakfast'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.tap(find.text('Breakfast'));
      await tester.pump();
      expect(state.consumedCalories, before - 620);
    });

    testWidgets('tabs switch between Today, Meals and Analytics',
        (tester) async {
      await tester.pumpWidget(_wrapNutrition(AppState()));
      await tester.pump();

      expect(find.text('CALORIES'), findsOneWidget);
      await tester.tap(find.text('Analytics'));
      await tester.pump();
      expect(find.text('Analytics'), findsWidgets);
      expect(find.text('CALORIES'), findsNothing);
    });
  });

  group('Weight tracker', () {
    testWidgets('adding a weigh-in updates the number and history',
        (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: WeightTrackerScreen()),
        ),
      );
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
      await tester.pumpWidget(
        ChangeNotifierProvider(
          create: (_) => AppState(),
          child: const MaterialApp(home: WeightTrackerScreen()),
        ),
      );
      await tester.pump();
      expect(find.byType(FloatingActionButton), findsOneWidget);

      await tester.tap(find.text('Body Fat'));
      await tester.pumpAndSettle(); // let the FAB exit animation finish
      expect(find.text('Body Fat'), findsWidgets);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
