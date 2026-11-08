import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/screens/nutrition_screen.dart';

import '../helpers/published_recipes.dart';
import '../helpers/test_harness.dart';

void main() {
  Future<void> pumpFuel(WidgetTester tester, {required bool published}) async {
    tester.view.physicalSize = const Size(430, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    await tester.pumpWidget(
      wrapApp(
        const Scaffold(body: NutritionScreen()),
        repo: repo,
        recipeCatalogRepo: published ? publishedRecipeCatalog() : null,
      ),
    );
    await tester.pumpAndSettle();
    await tester.pumpAndSettle();
  }

  testWidgets('no published recipe: Fuel offers no recipe doorway',
      (tester) async {
    await pumpFuel(tester, published: false);
    expect(find.text('Recipes'), findsNothing);
  });

  testWidgets('a published recipe brings the Recipes tab back', (tester) async {
    await pumpFuel(tester, published: true);
    expect(find.text('Recipes'), findsOneWidget);
  });
}
