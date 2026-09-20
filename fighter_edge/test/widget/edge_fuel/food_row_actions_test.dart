import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:fighter_edge/features/edge_fuel/data/food_catalog_repository.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';

import '../../helpers/test_harness.dart';

/// Covers the row-tap/toggle split this slice introduced: tapping a food row
/// used to silently toggle it eaten/not-eaten with no visible control and no
/// way back — a real tester hit exactly this. Now the row opens the entry
/// for editing, and a distinct control does the toggle, with Undo.
///
/// The toggle control was first built nested inside the row's own tappable
/// area; a widget test caught that the row's tap (built on [PressScale],
/// same as the toggle's own gesture family) always won the gesture arena, so
/// the toggle's own `onTap` never fired at all. Fixed by giving the two
/// controls non-overlapping tap regions instead of nesting one inside the
/// other's — keep that structure; do not go back to a single card-wide
/// `onTap` covering a nested tappable control.
void main() {
  Future<void> pumpWithOneMeal(WidgetTester tester) async {
    tester.view.physicalSize = const Size(430, 932);
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

    // Log one real meal through the same add flow a user would use.
    await tester.tap(find.byIcon(Icons.add).first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'banana');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Banana, raw'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ADD TO TODAY'));
    await tester.pumpAndSettle();
  }

  EdgeFuelController fuel(WidgetTester tester) =>
      tester.element(find.byType(NutritionScreen)).read<EdgeFuelController>();

  Future<void> tapToggle(WidgetTester tester, String label) async {
    await tester.scrollUntilVisible(find.bySemanticsLabel(label), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel(label));
    await tester.pumpAndSettle();
  }

  testWidgets('tapping the row opens it for editing, and does not toggle it',
      (tester) async {
    await pumpWithOneMeal(tester);
    final calories = fuel(tester).consumedCalories;
    expect(calories, greaterThan(0));

    await tester.scrollUntilVisible(find.text('Banana, raw'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Banana, raw'));
    await tester.pumpAndSettle();

    expect(find.text('Edit food'), findsOneWidget);
    expect(fuel(tester).consumedCalories, calories,
        reason: 'opening the row to edit it must not touch consumed state');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
  });

  testWidgets('the check toggles the meal, and says so with Undo',
      (tester) async {
    await pumpWithOneMeal(tester);
    final logged = fuel(tester).consumedCalories;
    expect(logged, greaterThan(0));

    await tapToggle(tester, 'Mark as not eaten');

    expect(fuel(tester).consumedCalories, 0,
        reason: 'unticking removes it from the day total');
    expect(fuel(tester).entries, hasLength(1),
        reason: 'but the entry itself is still there, not deleted');
    expect(find.textContaining('marked as not eaten'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect(fuel(tester).consumedCalories, logged,
        reason: 'undo restores exactly what was there before the toggle');
  });

  testWidgets('toggling twice in a row (no undo) lands on eaten again',
      (tester) async {
    await pumpWithOneMeal(tester);
    final logged = fuel(tester).consumedCalories;

    await tapToggle(tester, 'Mark as not eaten');
    expect(fuel(tester).consumedCalories, 0);

    await tapToggle(tester, 'Mark as eaten');
    expect(fuel(tester).consumedCalories, logged);
  });
}
