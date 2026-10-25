import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/edge_fuel/data/food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_display_mode.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/nutrition_mode_controller.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/widgets/add_food_sheet.dart';
import 'package:fighter_edge/main.dart';
import 'package:fighter_edge/routing/app_router.dart';
import 'package:fighter_edge/screens/home_shell.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/widgets/bottom_nav.dart';

import '../helpers/test_harness.dart';

/// "Hide numbers": food is still logged by name, but no calorie, gram, target,
/// percentage or weight is shown or typed in anywhere.
void main() {
  FoodLogEntry oats() => FoodLogEntry(
        id: 'm1',
        name: 'Oats and milk',
        notes: '80 g',
        calories: 350,
        proteinGrams: 12,
        carbGrams: 60,
        fatGrams: 6,
        source: FoodLogSource.manual,
        loggedAt: DateTime.now(),
      );

  /// Texts that would give a number away.
  final numberish = find.byWidgetPredicate((w) {
    if (w is! Text) return false;
    final s = w.data ?? w.textSpan?.toPlainText() ?? '';
    return RegExp(r'\d+\s*(kcal|calories|g\b|%)').hasMatch(s) ||
        s.contains('kcal');
  }, description: 'text with a nutrient number');

  group('the Fuel tab', () {
    Future<void> pumpFuel(
        WidgetTester tester, NutritionDisplayMode mode) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final repo = await makeRepo(signedIn: true);
      await tester.pumpWidget(
        wrapApp(const Scaffold(body: NutritionScreen()), repo: repo),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(() => tester
          .element(find.byType(NutritionScreen))
          .read<FoodCatalogRepository>()
          .loadAll());
      final context = tester.element(find.byType(NutritionScreen));
      await tester
          .runAsync(() => context.read<EdgeFuelController>().addEntry(oats()));
      await context.read<NutritionModeController>().setMode(mode);
      await tester.pumpAndSettle();
    }

    testWidgets('normal shows the numbers, as before', (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.normal);
      expect(find.text('350 kcal'), findsOneWidget);
      expect(find.text('Recipes'), findsOneWidget);
    });

    testWidgets('hidden: the meal is there by name, with no number',
        (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      expect(find.text('Oats and milk'), findsWidgets);
      expect(numberish, findsNothing);
      expect(find.text('80 g'), findsNothing);
      // The log is still usable: eaten check, delete, a note about names.
      expect(find.text('Log what you eat. The numbers stay hidden.'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('fuel-log-food')), findsOneWidget);
    });

    testWidgets('hidden: no ring, no macros, no plan link', (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      expect(find.text('Protein'), findsNothing);
      expect(find.text('Carbs'), findsNothing);
      expect(find.text('Fats'), findsNothing);
      expect(find.text('kcal left'), findsNothing);
      expect(find.text('logged today'), findsNothing);
    });

    testWidgets('hidden: no recipes tab', (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      expect(find.text('Recipes'), findsNothing);
      expect(find.text('Today'), findsWidgets);
      expect(find.text('Meals'), findsWidgets);
    });

    testWidgets('hidden: the meals tab shows names only', (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      await tester.tap(find.text('Meals').first);
      await tester.pumpAndSettle();
      expect(find.text('Oats and milk'), findsWidgets);
      expect(numberish, findsNothing);
    });

    testWidgets('hidden: the add sheet shows names, no numbers, no typing them',
        (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      await tester.tap(find.byKey(const ValueKey('fuel-log-food')));
      await tester.pumpAndSettle();
      expect(find.text('Enter macros manually'), findsNothing);
      // The remembered meal has no numbers next to it.
      expect(find.text('Oats and milk'), findsWidgets);
      expect(numberish, findsNothing);

      await tester.enterText(find.byType(TextField), 'banana');
      await tester.pumpAndSettle();
      expect(find.text('Banana, raw'), findsWidgets);
      expect(find.textContaining('per 100 g'), findsNothing);

      await tester.tap(find.descendant(
          of: find.byType(AddFoodSheet), matching: find.text('Banana, raw')));
      await tester.pumpAndSettle();
      expect(find.text('How much?'), findsOneWidget);
      // No kcal, no protein/carbs/fat breakdown.
      expect(find.textContaining('kcal'), findsNothing);
      expect(find.text('Protein'), findsNothing);

      await tester.tap(find.text('Add to today'));
      await tester.pumpAndSettle();
      expect(find.text('Banana, raw added'), findsOneWidget);
      expect(find.textContaining('kcal'), findsNothing);
    });

    testWidgets('normal: the add sheet still offers manual entry',
        (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.normal);
      await tester.tap(find.byKey(const ValueKey('fuel-log-food')));
      await tester.pumpAndSettle();
      expect(find.text('Enter macros manually'), findsOneWidget);
    });

    testWidgets('hidden: tapping a row does not open the number editor',
        (tester) async {
      await pumpFuel(tester, NutritionDisplayMode.hideNumbers);
      await tester.tap(find.text('Oats and milk').last);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsNothing);
    });
  });

  group('the app', () {
    void useTallScreen(WidgetTester tester) {
      tester.view.physicalSize = const Size(1400, 3400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
    }

    Future<void> boot(WidgetTester tester, NutritionDisplayMode mode) async {
      useTallScreen(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'fe_nutrition_mode.${repo.currentUser!.id}', mode.storageName);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      await tester.pumpAndSettle();
    }

    NutritionModeController modeOf(WidgetTester tester) => tester
        .element(find.byType(HomeShell, skipOffstage: false))
        .read<NutritionModeController>();

    void go(WidgetTester tester, String route) =>
        GoRouter.of(tester.element(find.byType(HomeShell))).push(route);

    testWidgets('Home: no weigh-in, no weight card; Fuel stays',
        (tester) async {
      await boot(tester, NutritionDisplayMode.hideNumbers);
      expect(find.text('Add weigh-in'), findsNothing);
      expect(find.text('Weight'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Fuel'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
    });

    testWidgets('the numeric screens are a note with a way back',
        (tester) async {
      await boot(tester, NutritionDisplayMode.hideNumbers);
      for (final route in [
        AppRoutes.weightTracker,
        AppRoutes.fuelPlan,
        AppRoutes.fuelSetup,
        AppRoutes.fuelRecipes,
        AppRoutes.fightSetup,
        AppRoutes.fightPath,
        AppRoutes.fightWeek,
      ]) {
        go(tester, route);
        await tester.pumpAndSettle();
        expect(find.text('Numbers are hidden'), findsOneWidget, reason: route);
        expect(find.text('Nutrition is paused'), findsNothing, reason: route);
        GoRouter.of(tester.element(find.text('Numbers are hidden'))).pop();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('Show numbers puts everything back', (tester) async {
      await boot(tester, NutritionDisplayMode.hideNumbers);
      go(tester, AppRoutes.weightTracker);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show numbers'));
      await tester.pumpAndSettle();
      expect(modeOf(tester).mode, NutritionDisplayMode.normal);
      expect(find.text('Numbers are hidden'), findsNothing);
    });

    testWidgets('Profile hides the weight line and the tracker',
        (tester) async {
      await boot(tester, NutritionDisplayMode.hideNumbers);
      tester.widget<AppBottomNav>(find.byType(AppBottomNav)).onTap(3);
      await tester.pumpAndSettle();
      expect(find.text('Weight tracker'), findsNothing);
      expect(find.text('Training days'), findsOneWidget);
    });

    testWidgets('Settings offers all three and remembers the choice',
        (tester) async {
      await boot(tester, NutritionDisplayMode.normal);
      go(tester, AppRoutes.settings);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Nutrition display'),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.tap(find.text('Nutrition display'));
      await tester.pumpAndSettle();
      expect(find.text('Show everything'), findsOneWidget);
      expect(find.text('Hide numbers'), findsOneWidget);
      expect(find.text('Pause nutrition'), findsOneWidget);

      await tester.tap(find.text('Hide numbers'));
      await tester.pumpAndSettle();
      expect(find.text('Numbers hidden'), findsOneWidget);
      expect(modeOf(tester).mode, NutritionDisplayMode.hideNumbers);
    });

    testWidgets('nothing numeric on a fresh hidden start, from frame one',
        (tester) async {
      useTallScreen(tester);
      final repo = await makeRepo(signedIn: true, onboarded: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fe_nutrition_mode.${repo.currentUser!.id}',
          NutritionDisplayMode.hideNumbers.storageName);
      await tester.pumpWidget(FighterEdgeApp(authRepo: repo));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(find.text('Weight'), findsNothing, reason: 'frame $i');
        expect(find.text('Add weigh-in'), findsNothing, reason: 'frame $i');
      }
    });
  });
}
