import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/screens/profile_screen.dart';
import 'package:fighter_edge/screens/training_camp_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:fighter_edge/theme/app_icons.dart';

import '../helpers/test_harness.dart';

/// Regression tests for the 2026-09-25 QA pass.
///
/// The two dialog tests type into a field and then save. That is the path the
/// old code broke on: it disposed the dialog's controllers as soon as
/// `showDialog` returned, while the closing dialog was still rebuilding its
/// focused text field ("A TextEditingController was used after being
/// disposed"). The tests that existed only tapped, so nothing caught it.
void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('manual food entry', () {
    Future<EdgeFuelController> openManualEntry(WidgetTester tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(
        wrapApp(const Scaffold(body: NutritionScreen()), repo: repo),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.plus).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enter macros manually'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      return tester
          .element(find.byType(AlertDialog))
          .read<EdgeFuelController>();
    }

    testWidgets('typing then saving closes cleanly and logs the meal',
        (tester) async {
      final fuel = await openManualEntry(tester);

      await tester.enterText(field('Food or meal name'), 'QA plain meal');
      await tester.enterText(field('Calories'), '300');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(fuel.entries.single.name, 'QA plain meal');
      expect(fuel.entries.single.calories, 300);
    });

    testWidgets('saving an empty form says what is missing instead of nothing',
        (tester) async {
      final fuel = await openManualEntry(tester);

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a name.'), findsOneWidget);
      expect(find.text('Enter 0 to 10000 kcal.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fuel.entries, isEmpty);
    });

    testWidgets('out-of-range numbers are refused, and signs cannot be typed',
        (tester) async {
      final fuel = await openManualEntry(tester);

      await tester.enterText(field('Food or meal name'), 'x');
      await tester.enterText(field('Calories'), '20000');
      await tester.enterText(field('Protein'), '5000');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter 0 to 10000 kcal.'), findsOneWidget);
      expect(find.text('Enter 0 to 1000 g.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(fuel.entries, isEmpty);

      await tester.enterText(field('Calories'), '-500');
      expect(
        tester.widget<TextField>(field('Calories')).controller!.text,
        '500',
        reason: 'the minus sign is filtered out, so a negative cannot be typed',
      );
    });
  });

  group('portion amount', () {
    testWidgets('above the 2000 g limit is flagged and cannot be added',
        (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(
        wrapApp(const Scaffold(body: NutritionScreen()), repo: repo),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester
          .element(find.byType(NutritionScreen))
          .read<FoodCatalogRepository>()
          .loadAll());
      final fuel = tester
          .element(find.byType(NutritionScreen))
          .read<EdgeFuelController>();

      await tester.tap(find.byIcon(AppIcons.plus).first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'chicken breast');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Chicken breast, skinless, raw'));
      await tester.pumpAndSettle();

      await tester.enterText(field('Grams'), '2500');
      await tester.pumpAndSettle();
      expect(find.text('Up to 2000 g per entry.'), findsOneWidget);
      await tester.tap(find.text('Add to today'));
      await tester.pumpAndSettle();
      expect(fuel.entries, isEmpty,
          reason: 'what is on screen must equal what would be logged');

      await tester.enterText(field('Grams'), '1500');
      await tester.pumpAndSettle();
      expect(find.text('Up to 2000 g per entry.'), findsNothing);
      await tester.tap(find.text('Add to today'));
      await tester.pumpAndSettle();
      expect(fuel.entries.single.notes, '1500 g');
    });
  });

  group('session log', () {
    testWidgets('a typed reflection saves without a disposed-controller crash',
        (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final state = AppState();
      await tester.pumpWidget(wrapApp(
        const Scaffold(body: TrainingCampScreen()),
        repo: repo,
        state: state,
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.bySemanticsLabel('Log session').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'felt sharp on entries');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(
          state.sessions.any((s) => s.note == 'felt sharp on entries'), isTrue);
    });
  });

  group('weigh-in', () {
    Future<AppState> openTracker(WidgetTester tester,
        {bool metric = true}) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      final state = AppState();
      await tester.pump(); // let saved settings load before changing one
      await state.setUseMetricUnits(metric);
      await tester.pumpWidget(
        wrapApp(const WeightTrackerScreen(), repo: repo, state: state),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel('Add weigh-in'));
      await tester.pumpAndSettle();
      return state;
    }

    testWidgets('an implausible weight is refused with the allowed range',
        (tester) async {
      final state = await openTracker(tester);
      final before = state.weights.length;

      await tester.enterText(find.byType(TextField), '999');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a weight from 35 to 220 kg.'), findsOneWidget);
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(state.weights.length, before);
    });

    testWidgets('the range is stated in the unit the user sees',
        (tester) async {
      await openTracker(tester, metric: false);

      await tester.enterText(find.byType(TextField), '999');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a weight from 77 to 485 lb.'), findsOneWidget);
    });

    testWidgets('a valid weight saves and closes cleanly', (tester) async {
      final state = await openTracker(tester);

      await tester.enterText(find.byType(TextField), '81.5');
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.byType(AlertDialog), findsNothing);
      expect(state.latestWeight, 81.5);
    });
  });

  group('imperial units', () {
    testWidgets('the profile header converts the weight, not just the label',
        (tester) async {
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final state = AppState();
      await tester.pump(); // let saved settings load before changing one
      await state.setUseMetricUnits(false);
      await tester.pumpWidget(
        wrapApp(const ProfileScreen(), repo: repo, state: state),
      );
      await tester.pumpAndSettle();

      // 77.2 kg is 170.2 lb; the bug printed "77.2 lb".
      expect(find.textContaining('170.2 lb'), findsOneWidget);
      expect(find.textContaining('77.2 lb'), findsNothing);
    });
  });

  group('empty plan', () {
    AppState emptyState() => AppState(dataRepository: InMemoryDataRepository());

    testWidgets('Train > Week explains itself instead of going blank',
        (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const Scaffold(body: TrainingCampScreen()),
        repo: repo,
        state: emptyState(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('No sessions planned yet'), findsOneWidget);
    });

    testWidgets('the dashboard does not call an empty week complete',
        (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        DashboardScreen(onNavigate: (_) {}),
        repo: repo,
        state: emptyState(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No sessions planned'), findsOneWidget);
      expect(find.text('Week complete'), findsNothing);
      expect(find.textContaining('Camp work complete'), findsNothing);
    });

    testWidgets('the weight tracker shows no invented change or average',
        (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(wrapApp(
        const WeightTrackerScreen(),
        repo: repo,
        state: emptyState(),
      ));
      await tester.pumpAndSettle();

      expect(find.textContaining('vs last weigh-in'), findsNothing);
      expect(find.text('0.0'), findsNothing);
    });
  });

  group('accessible names', () {
    testWidgets('the day arrows on Nutrition are named', (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(
        wrapApp(const Scaffold(body: NutritionScreen()), repo: repo),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Previous day'), findsOneWidget);
      expect(find.bySemanticsLabel('Next day'), findsOneWidget);
    });

    testWidgets('the weigh-in button and field are named', (tester) async {
      phone(tester);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(
        wrapApp(const WeightTrackerScreen(), repo: repo, state: AppState()),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Add weigh-in'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Add weigh-in'));
      await tester.pumpAndSettle();
      expect(field('Weight'), findsOneWidget);
    });
  });
}
