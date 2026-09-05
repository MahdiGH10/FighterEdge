import 'dart:io';

import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/asset_recipe_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/recipe_library_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

/// The shipped catalogs, read once in [setUpAll].
///
/// Widget tests run under a fake async clock, so a real `File.readAsString()`
/// inside the test body never completes and `pumpAndSettle` times out. Reading
/// them here — outside the fake clock — and handing back `Future.value` keeps
/// the tests running against the real content without real I/O.
late String _foodsJson;
late String _recipesJson;

Future<void> _pumpLibrary(WidgetTester tester, {Plan plan = Plan.free}) async {
  final repo = await makeRepo(signedIn: true, plan: plan);
  final foods = AssetFoodCatalogRepository(loadString: (_) async => _foodsJson);
  await tester.pumpWidget(
    wrapApp(
      const RecipeLibraryScreen(),
      repo: repo,
      foodCatalogRepo: foods,
      recipeCatalogRepo: AssetRecipeCatalogRepository(
        foodCatalog: foods,
        loadString: (_) async => _recipesJson,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    _foodsJson = File('assets/data/edge_fuel_foods_v1.json').readAsStringSync();
    _recipesJson = File(
      'assets/data/edge_fuel_recipes_v1.json',
    ).readAsStringSync();
  });

  testWidgets('renders recipes from the shipped catalog', (tester) async {
    await _pumpLibrary(tester);

    // AppHeader and PrimaryButton both uppercase their labels.
    expect(find.text('RECIPES'), findsOneWidget);
    expect(find.text('Greek yogurt and berry bowl'), findsOneWidget);
  });

  testWidgets('search narrows the list', (tester) async {
    await _pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'chickpea');
    await tester.pumpAndSettle();

    expect(find.text('Tunisian chickpea and bread bowl'), findsOneWidget);
    expect(find.text('Greek yogurt and berry bowl'), findsNothing);
  });

  testWidgets('a meal-type filter chip filters the list', (tester) async {
    await _pumpLibrary(tester);

    await tester.tap(find.text('Dinner'));
    await tester.pumpAndSettle();

    expect(find.text('Red lentil and vegetable stew'), findsOneWidget);
    expect(find.text('Greek yogurt and berry bowl'), findsNothing);
  });

  testWidgets('a free user sees a lock on premium recipes', (tester) async {
    await _pumpLibrary(tester, plan: Plan.free);

    await tester.enterText(find.byType(TextField), 'labneh');
    await tester.pumpAndSettle();

    expect(find.text('Labneh bowl with cucumber and olives'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsWidgets);
  });

  testWidgets('a Pro user sees no lock', (tester) async {
    await _pumpLibrary(tester, plan: Plan.pro);

    await tester.enterText(find.byType(TextField), 'labneh');
    await tester.pumpAndSettle();

    expect(find.text('Labneh bowl with cucumber and olives'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
  });

  testWidgets(
    'opening a premium recipe as a free user shows the upgrade moment, '
    'not the recipe',
    (tester) async {
      await _pumpLibrary(tester, plan: Plan.free);

      await tester.enterText(find.byType(TextField), 'labneh');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Labneh bowl with cucumber and olives'));
      await tester.pumpAndSettle();

      expect(find.text('SEE PRO'), findsOneWidget);
      // The method must not be readable through the lock.
      expect(find.text('METHOD'), findsNothing);
    },
  );

  testWidgets('an empty result set explains itself and offers a way out', (
    tester,
  ) async {
    await _pumpLibrary(tester);

    await tester.enterText(find.byType(TextField), 'zzzzzzz');
    await tester.pumpAndSettle();

    expect(find.text('Nothing matches'), findsOneWidget);
    expect(find.text('Clear filters'), findsOneWidget);
  });
}
