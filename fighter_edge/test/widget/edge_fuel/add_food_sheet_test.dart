import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fighter_edge/features/edge_fuel/data/food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<void> pumpNutrition(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(
      wrapApp(const Scaffold(body: NutritionScreen()), repo: repo),
    );
    await tester.pumpAndSettle();
    // The catalog reads its JSON off disk; real file IO has to run outside
    // the fake clock once, after which searches hit the cache.
    await tester.runAsync(() => tester
        .element(find.byType(NutritionScreen))
        .read<FoodCatalogRepository>()
        .loadAll());
  }

  EdgeFuelController fuel(WidgetTester tester) =>
      tester.element(find.byType(NutritionScreen)).read<EdgeFuelController>();

  testWidgets(
      'search → portion → add logs the scaled food, and Undo takes '
      'it back', (tester) async {
    await pumpNutrition(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('Add to Today'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'chicken breast');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chicken breast, skinless, raw'));
    await tester.pumpAndSettle();

    expect(find.text('HOW MUCH?'), findsOneWidget);
    expect(find.text('113 kcal'), findsOneWidget, reason: '100 g default');
    await tester.tap(find.text('150 g'));
    await tester.pumpAndSettle();
    expect(find.text('170 kcal'), findsOneWidget);

    await tester.tap(find.text('ADD TO TODAY'));
    await tester.pumpAndSettle();

    expect(fuel(tester).consumedCalories, 170);
    expect(fuel(tester).entries.single.notes, '150 g');
    expect(find.textContaining('170 kcal added'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fuel(tester).entries, isEmpty);
  });

  testWidgets('a logged food is one tap away next time', (tester) async {
    await pumpNutrition(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana, raw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO TODAY'));
    await tester.pumpAndSettle();

    // Tomorrow, the log is empty but the banana is remembered.
    fuel(tester).shiftDate(1);
    await tester.pumpAndSettle();
    expect(fuel(tester).entries, isEmpty);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    expect(find.text('RECENT'), findsOneWidget);
    await tester.tap(find.text('Banana, raw'));
    await tester.pumpAndSettle();

    expect(fuel(tester).entries.single.name, 'Banana, raw');
  });

  testWidgets('manual entry is still there for anything not listed',
      (tester) async {
    await pumpNutrition(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Enter macros manually'));
    await tester.pumpAndSettle();

    expect(find.text('Food or meal name'), findsOneWidget);
  });

  testWidgets('an unknown search says so and points to manual entry',
      (tester) async {
    await pumpNutrition(tester);

    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'zzzz');
    await tester.pumpAndSettle();

    expect(find.text('Not in the food list yet'), findsOneWidget);
  });
}
