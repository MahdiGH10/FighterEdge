import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/training_plan_fuel_bridge.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/training_plan/presentation/plan_controller.dart';
import 'package:fighter_edge/screens/nutrition_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../../helpers/test_harness.dart';

void main() {
  Future<void> pumpScreen(WidgetTester tester,
      {int? age = 28, bool readOnly = false}) async {
    final auth = await makeRepo(signedIn: true);
    final fuel = InMemoryEdgeFuelRepository();
    if (age != null) {
      await fuel.saveProfileDraft(auth.currentUser!.id,
          NutritionSetupDraft(ageYears: age, confirmed: true));
    }
    await fuel.saveTarget(
        auth.currentUser!.id,
        NutritionTarget(
            status: NutritionTargetStatus.success,
            policyVersion: 2,
            calculatedAt: DateTime(2026, 10, 24),
            targetCalories: 2500,
            proteinGrams: 150,
            carbGrams: 280,
            fatGrams: 87));
    final state = AppState();
    if (readOnly) {
      state.accessSource = () => const AccessState.readOnly();
    }
    await tester.pumpWidget(wrapApp(const NutritionScreen(),
        repo: auth, edgeFuelRepo: fuel, state: state));
    await tester.pumpAndSettle();
    final plan =
        tester.element(find.byType(NutritionScreen)).read<PlanController>();
    plan.startFresh(
        weeklyTrainingDays: 4,
        goal: 'Build fight-camp structure',
        level: 'Intermediate');
    await tester.pumpAndSettle();
  }

  testWidgets('screen day type comes from the dated training plan',
      (tester) async {
    await pumpScreen(tester);
    final plan =
        tester.element(find.byType(NutritionScreen)).read<PlanController>();
    final week = plan.currentWeek!;
    final today = TrainingPlanFuelBridge.planWeek(week)
        .firstWhere((day) => FuelCalendar.sameDay(day.date, plan.today));
    final label = switch (today.type) {
      FuelDayType.rest => 'Rest day',
      FuelDayType.easy => 'Easy training day',
      FuelDayType.hard => 'Hard training day',
      FuelDayType.doubleDay => 'Double training day',
      FuelDayType.fightWeek => 'Fight week',
    };
    expect(find.text(label), findsOneWidget);
    expect(find.textContaining('Accepted daily average'), findsOneWidget);
    expect(find.text('2500 kcal target'), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel-gap-title')), findsNothing,
        reason: 'catalog portions are still awaiting review');
  });

  testWidgets('unknown and minor age hide target numbers on the screen',
      (tester) async {
    for (final age in <int?>[null, 17]) {
      await pumpScreen(tester, age: age);
      expect(find.text('2500 kcal target'), findsNothing);
      expect(find.text('2500'), findsNothing);
      expect(find.byKey(const ValueKey('fuel-gap-title')), findsNothing);
    }
  });

  testWidgets('read-only keeps accepted numbers visible', (tester) async {
    await pumpScreen(tester, readOnly: true);
    expect(find.text('2500 kcal target'), findsOneWidget);
    expect(find.text('2500'), findsOneWidget);
    expect(find.byKey(const ValueKey('fuel-gap-title')), findsNothing);
  });
}
