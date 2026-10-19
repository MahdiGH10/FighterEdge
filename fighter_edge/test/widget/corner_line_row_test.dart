import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fighter_edge/features/corner_brief/presentation/corner_line_row.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/screens/edge_fuel_setup_screen.dart';
import 'package:fighter_edge/widgets/stat_card.dart';

import '../helpers/test_harness.dart';

NutritionTarget _target() => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 1, 1),
      targetCalories: 2400,
      proteinGrams: 180,
      carbGrams: 280,
      fatGrams: 70,
    );

void main() {
  Future<void> pumpRow(
    WidgetTester tester, {
    bool withTarget = true,
    bool german = false,
  }) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    if (german) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fe_locale', 'de');
    }
    final edgeFuelRepo = InMemoryEdgeFuelRepository();
    if (withTarget) {
      await edgeFuelRepo.saveTarget(repo.currentUser!.id, _target());
    }
    await tester.pumpWidget(wrapApp(
      const Scaffold(body: SingleChildScrollView(child: CornerLineRow())),
      repo: repo,
      edgeFuelRepo: edgeFuelRepo,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the calculated line as a plain row, not a card',
      (tester) async {
    await pumpRow(tester);

    expect(find.text('Corner Brief'), findsOneWidget);
    expect(find.textContaining('Log your first meal'), findsOneWidget);
    expect(find.byType(AppCard), findsNothing);
  });

  testWidgets('without a plan the line opens EdgeFuel setup', (tester) async {
    await pumpRow(tester, withTarget: false);

    expect(find.textContaining('Set up EdgeFuel'), findsOneWidget);
    await tester.tap(find.textContaining('Set up EdgeFuel'));
    await tester.pumpAndSettle();
    expect(find.byType(EdgeFuelSetupScreen), findsOneWidget);
  });

  testWidgets('reads in German', (tester) async {
    await pumpRow(tester, german: true);

    expect(find.text('Ecken-Briefing'), findsOneWidget);
    expect(find.textContaining('erste Mahlzeit'), findsOneWidget);
  });
}
