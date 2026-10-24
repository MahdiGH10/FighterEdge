import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_day_planner.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_match_calculator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/accepted_fuel_week.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_item.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_add_on.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_gap.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:fighter_edge/features/edge_fuel/presentation/widgets/fuel_day_panel.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

final _date = DateTime(2026, 10, 24);

final _target = NutritionTarget(
  status: NutritionTargetStatus.success,
  policyVersion: 2,
  calculatedAt: _date,
  targetCalories: 500,
  proteinGrams: 40,
  carbGrams: 70,
  fatGrams: 10,
);

FuelDayPlan _day(FuelDayType type) => FuelDayPlan(
      date: _date,
      type: type,
      load: type == FuelDayType.fightWeek ? FuelDayType.rest : type,
      carbTier: CarbTier.light,
      sessions: const [],
      sessionKcalPerKg: 0,
    );

Widget _app(Widget child, {Locale locale = const Locale('en')}) => MaterialApp(
      locale: locale,
      localizationsDelegates: L.localizationsDelegates,
      supportedLocales: L.supportedLocales,
      home: Scaffold(body: ListView(children: [child])),
    );

const _addOns = [
  FuelAddOn(
      id: 'yogurt',
      foodId: 'yogurt',
      group: AddOnGroup.dairy,
      grams: 200,
      unit: AddOnUnit.gram,
      unitCount: 200,
      source: FuelAddOn.sourceCurated),
  FuelAddOn(
      id: 'eggs',
      foodId: 'eggs',
      group: AddOnGroup.egg,
      grams: 150,
      unit: AddOnUnit.gram,
      unitCount: 150,
      source: FuelAddOn.sourceCurated),
  FuelAddOn(
      id: 'tofu',
      foodId: 'tofu',
      group: AddOnGroup.plantProtein,
      grams: 150,
      unit: AddOnUnit.gram,
      unitCount: 150,
      source: FuelAddOn.sourceCurated),
];

final _foods = {
  for (final id in ['yogurt', 'eggs', 'tofu'])
    id: FoodItem(
      id: id,
      name: id,
      category: FoodCategory.protein,
      kcalPer100g: 100,
      proteinPer100g: 15,
      carbsPer100g: 5,
      fatPer100g: 3,
      fibrePer100g: 0,
    ),
};

NutritionDay _log({int kcal = 0, int protein = 0}) {
  final day = NutritionDay.empty(
      localDate: '2026-10-24',
      timeZone: 'UTC',
      now: _date,
      targetSnapshot: _target);
  if (kcal == 0 && protein == 0) return day;
  return day.copyWith(entries: [
    FoodLogEntry(
      id: 'entry',
      name: 'meal',
      notes: '',
      calories: kcal,
      proteinGrams: protein,
      carbGrams: 0,
      fatGrams: 0,
      loggedAt: _date,
    ),
  ]);
}

void main() {
  for (final (type, label) in [
    (FuelDayType.rest, 'Rest day'),
    (FuelDayType.easy, 'Easy training day'),
    (FuelDayType.hard, 'Hard training day'),
    (FuelDayType.doubleDay, 'Double training day'),
    (FuelDayType.fightWeek, 'Fight week'),
  ]) {
    testWidgets('$type renders its allocated target', (tester) async {
      final day = _day(type);
      await tester.pumpWidget(_app(FuelDayPanel(
        day: day,
        allocated: AcceptedFuelDay(
            plan: day,
            calories: 520,
            proteinGrams: 40,
            carbGrams: 75,
            fatGrams: 10),
        acceptedTarget: _target,
        adult: true,
        hints: const [],
      )));
      expect(find.text(label), findsOneWidget);
      expect(find.text('520 kcal target'), findsOneWidget);
      expect(find.text('40 g protein target'), findsOneWidget);
      expect(find.text('75 g carb target'), findsOneWidget);
    });
  }

  testWidgets('pending allocation identifies accepted average', (tester) async {
    await tester.pumpWidget(_app(FuelDayPanel(
      day: _day(FuelDayType.hard),
      allocated: null,
      acceptedTarget: _target,
      adult: true,
      hints: const [],
    )));
    expect(find.textContaining('Accepted daily average'), findsOneWidget);
    expect(find.text('500 kcal target'), findsOneWidget);
  });

  testWidgets('unknown age hides all targets', (tester) async {
    await tester.pumpWidget(_app(FuelDayPanel(
      day: _day(FuelDayType.hard),
      allocated: null,
      acceptedTarget: _target,
      adult: false,
      hints: const [],
    )));
    expect(find.textContaining('kcal target'), findsNothing);
    expect(find.textContaining('protein target'), findsNothing);
  });

  testWidgets('session hints stay qualitative with review gate off',
      (tester) async {
    final session = FuelDatedSession(
        date: _date,
        discipline: FuelDiscipline.boxing,
        intensity: FuelIntensity.hard,
        durationMinutes: 75);
    final day = FuelDayPlanner.planDay(date: _date, plan: [session]);
    await tester.pumpWidget(_app(FuelDayPanel(
      day: day,
      allocated: null,
      acceptedTarget: _target,
      adult: true,
      hints: FuelDayPlanner.hints(day, adultConfirmed: true),
    )));
    expect(find.text('Before: plan a familiar meal.'), findsOneWidget);
    expect(find.textContaining('carbohydrate and protein'), findsOneWidget);
    expect(find.textContaining('g/kg'), findsNothing);
  });

  testWidgets('protein gap offers up to three one-tap portions',
      (tester) async {
    final gap = FuelMatchCalculator.dayGap(
      target: _target,
      day: _log(),
      foodsById: _foods,
      ageYears: 28,
      addOns: _addOns,
      reviewedAmountsEnabled: true,
    );
    expect(gap.status, FuelGapStatus.ready);
    expect(gap.protein, isNotNull);
    FuelAddOn? logged;
    await tester.pumpWidget(_app(FuelGapPanel(
      gap: gap,
      canWrite: true,
      onAddOn: (addOn, _) => logged = addOn,
    )));
    expect(find.text('Protein left: 40 g'), findsOneWidget);
    expect(find.byType(TextButton), findsNWidgets(gap.protein!.options.length));
    expect(gap.protein!.options.length, inInclusiveRange(1, 3));
    await tester.tap(find.byType(TextButton).first);
    expect(logged, isNotNull);
  });

  testWidgets('kcal gap appears after protein is covered', (tester) async {
    final gap = FuelMatchCalculator.dayGap(
      target: _target,
      day: _log(kcal: 100, protein: 40),
      foodsById: _foods,
      ageYears: 28,
      addOns: _addOns,
      reviewedAmountsEnabled: true,
    );
    expect(gap.calories, isNotNull);
    await tester.pumpWidget(_app(FuelGapPanel(
      gap: gap,
      canWrite: true,
      onAddOn: (_, __) {},
    )));
    expect(find.text('Energy left: 400 kcal'), findsOneWidget);
    expect(find.textContaining('leaves'), findsWidgets);
  });

  testWidgets('gap remains visible when no catalog portion matches',
      (tester) async {
    final gap = FuelMatchCalculator.dayGap(
        target: _target,
        day: _log(),
        foodsById: const {},
        ageYears: 28,
        reviewedAmountsEnabled: true);
    expect(gap.status, FuelGapStatus.noMatch);
    await tester.pumpWidget(_app(FuelGapPanel(
      gap: gap,
      canWrite: true,
      onAddOn: (_, __) {},
    )));
    expect(find.text('Protein left: 40 g'), findsOneWidget);
    expect(find.text('No matching portions right now.'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
  });

  testWidgets('closed, unreviewed, minor and unknown gaps show no options',
      (tester) async {
    for (final (age, reviewed, day) in [
      (28, true, _log(kcal: 500, protein: 40)),
      (28, false, _log()),
      (17, true, _log()),
      (null, true, _log()),
    ]) {
      final gap = FuelMatchCalculator.dayGap(
          target: _target,
          day: day,
          foodsById: _foods,
          ageYears: age,
          addOns: _addOns,
          reviewedAmountsEnabled: reviewed);
      await tester.pumpWidget(_app(FuelGapPanel(
        gap: gap,
        canWrite: true,
        onAddOn: (_, __) {},
      )));
      expect(find.byKey(const ValueKey('fuel-gap-title')), findsNothing);
      expect(find.byType(TextButton), findsNothing);
    }
  });

  testWidgets('read-only shows the gap but cannot add', (tester) async {
    final gap = FuelMatchCalculator.dayGap(
        target: _target,
        day: _log(),
        foodsById: _foods,
        ageYears: 28,
        addOns: _addOns,
        reviewedAmountsEnabled: true);
    var added = false;
    await tester.pumpWidget(_app(FuelGapPanel(
      gap: gap,
      canWrite: false,
      onAddOn: (_, __) => added = true,
    )));
    expect(find.text('Protein left: 40 g'), findsOneWidget);
    expect(tester.widget<TextButton>(find.byType(TextButton).first).onPressed,
        isNull);
    expect(added, isFalse);
  });

  testWidgets('320 px at 200 percent text has no overflow in both languages',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    for (final locale in [const Locale('en'), const Locale('de')]) {
      final gap = FuelMatchCalculator.dayGap(
          target: _target,
          day: _log(),
          foodsById: _foods,
          ageYears: 28,
          addOns: _addOns,
          reviewedAmountsEnabled: true);
      final day = _day(FuelDayType.doubleDay);
      await tester.pumpWidget(_app(
          Column(children: [
            FuelDayPanel(
                day: day,
                allocated: AcceptedFuelDay(
                    plan: day,
                    calories: 520,
                    proteinGrams: 40,
                    carbGrams: 75,
                    fatGrams: 10),
                acceptedTarget: _target,
                adult: true,
                hints: const []),
            FuelGapPanel(gap: gap, canWrite: true, onAddOn: (_, __) {}),
          ]),
          locale: locale));
      expect(tester.takeException(), isNull);
    }
  });
}
