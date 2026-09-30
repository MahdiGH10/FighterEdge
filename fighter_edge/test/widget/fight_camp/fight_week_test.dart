import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/edge_fuel/data/in_memory_edge_fuel_repository.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_setup_draft.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_copy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_path_screen.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_week_screen.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_harness.dart';

/// A Thursday.
final now = DateTime(2026, 10, 1, 9);

/// Weigh-ins on the two days that end at the start of a fight week three
/// days from its weigh-in, averaging [entryKg].
List<(int, double)> entryAt(double entryKg) =>
    [(5, entryKg + 0.2), (4, entryKg - 0.2)];

void main() {
  late InMemoryFightCampRepository fights;
  late AppState state;

  setUp(() {
    // The imperial test stores its unit; every test starts metric.
    SharedPreferences.setMockInitialValues({});
    fights = InMemoryFightCampRepository();
    state =
        AppState(dataRepository: InMemoryDataRepository(), clock: () => now);
  });

  Future<void> pumpWeek(
    WidgetTester tester, {
    int daysToWeighIn = 3,
    int lead = 1,
    double limit = 73.5,
    required List<(int, double)> weighIns,
    int? ageYears,
    Widget? home,
  }) async {
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (daysAgo, kg) in weighIns) {
      state.addWeight(addDays(now, -daysAgo), kg);
    }
    final repo = await makeRepo(signedIn: true, onboarded: true);
    final uid = repo.currentUser!.id;
    await fights.saveFight(
      uid,
      FightCamp.tryCreate(
        fightDate: addDays(now, daysToWeighIn + lead),
        weighInDate: addDays(now, daysToWeighIn),
        weightLimitKg: limit,
        category: CompetitionCategory.professional,
      )!,
    );
    final edgeFuel = InMemoryEdgeFuelRepository();
    if (ageYears != null) {
      await edgeFuel.saveProfileDraft(
          uid, NutritionSetupDraft(ageYears: ageYears));
    }
    await tester.pumpWidget(wrapApp(
      home ?? const FightWeekScreen(),
      repo: repo,
      state: state,
      fightCampRepo: fights,
      edgeFuelRepo: edgeFuel,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('mid-week: today in full, every day, and the refuel',
      (tester) async {
    await pumpWeek(tester, weighIns: [...entryAt(75), (0, 74.0)]);

    expect(find.textContaining('Fight week · day 5 of 7'), findsOneWidget);
    expect(
        find.textContaining('Food takes about 1.5 kg off in fight week: low '
            'fibre and fewer carbs from'),
        findsOneWidget,
        reason: 'planned from the first day of fight week, not today');
    expect(
        find.text(
            'Drink normally all week. Fighter Edge never plans water cuts.'),
        findsOneWidget);

    expect(find.textContaining('Today · '), findsOneWidget);
    expect(find.text('Low fibre'), findsOneWidget);
    expect(find.text('Fewer carbs'), findsOneWidget);
    expect(find.textContaining('Under 10 g of fibre'), findsOneWidget);
    expect(
        find.textContaining('If you feel dizzy or weak, eat.'), findsOneWidget);

    expect(find.text('Low fibre · Fewer carbs'), findsNWidgets(4));
    expect(find.text('Eat to plan'), findsNWidgets(3));
    expect(find.text('Weigh-in · Refuel'), findsOneWidget);
    expect(find.text('Fight'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget, reason: "today's row");

    expect(find.text('1–1.5 L an hour'), findsOneWidget);
    expect(find.text('Up to 60 g an hour'), findsOneWidget);
    expect(find.text('290–510 g'), findsOneWidget);
    expect(find.text('Keep it low'), findsOneWidget);
  });

  testWidgets('a supervised cut keeps the food steps under a warning',
      (tester) async {
    await pumpWeek(tester, weighIns: entryAt(77));
    expect(
        find.textContaining('The rest needs a water cut, which needs a coach'),
        findsOneWidget);
    expect(find.text('Low fibre'), findsOneWidget);
  });

  testWidgets('not safe: no food plan, the refuel still shows', (tester) async {
    await pumpWeek(tester, weighIns: entryAt(80));
    expect(find.textContaining('Not safe by this date'), findsOneWidget);
    expect(find.text('Low fibre'), findsNothing);
    expect(find.text('Low fibre · Fewer carbs'), findsNothing);
    expect(find.text('Keep it low'), findsOneWidget);
  });

  testWidgets('before fight week: when it starts, and no today card',
      (tester) async {
    await pumpWeek(tester,
        daysToWeighIn: 30, limit: 77, weighIns: [(1, 80.2), (0, 79.8)]);
    expect(find.textContaining('Starts '), findsOneWidget);
    expect(find.textContaining('Today · '), findsNothing);
    expect(find.text('Day by day'), findsOneWidget);
  });

  testWidgets('same-day weigh-in: hourly rates only', (tester) async {
    await pumpWeek(tester, lead: 0, weighIns: entryAt(75));
    expect(find.text('Up to 60 g an hour'), findsOneWidget);
    expect(find.text('Carbs in total'), findsNothing);
  });

  testWidgets('under 18: no plan at all', (tester) async {
    await pumpWeek(tester, weighIns: entryAt(75), ageYears: 17);
    expect(
        find.textContaining('Weight cut plans are for adults'), findsOneWidget);
    expect(find.text('Day by day'), findsNothing);
    expect(find.text('After the weigh-in'), findsNothing);
  });

  testWidgets('imperial units: fluid in fl oz', (tester) async {
    await pumpWeek(tester, weighIns: entryAt(75));
    await state.setUseMetricUnits(false);
    await tester.pumpAndSettle();
    expect(find.text('34–51 fl oz an hour'), findsOneWidget);
    expect(find.textContaining('Food takes about 3.3 lb off'), findsOneWidget);
  });

  testWidgets('German: decimal comma and thousands dot', (tester) async {
    final copy = FightCampCopy(lookupL(const Locale('de')), state, 'de');
    expect(copy.fluidRange(1, 1.5), '1–1,5 L');
    expect(copy.gramsRange(1290, 2510), '1.290–2.510 g');
    expect(copy.weight(79.5), '79,5', reason: 'not "79.5"');
  });

  testWidgets('in fight week the dashboard countdown opens fight week',
      (tester) async {
    await pumpWeek(tester,
        weighIns: [...entryAt(75), (0, 74.0)],
        home: DashboardScreen(onNavigate: (_) {}));
    expect(find.text('Today: Low fibre · Fewer carbs'), findsOneWidget);
    expect(
        find.bySemanticsLabel(RegExp(r'Today: Low fibre · Fewer carbs\. '
            r'Fight week$')),
        findsOneWidget,
        reason: 'the label ends with where the tap goes');
    await tester.tap(find.textContaining('Fight night'));
    await tester.pumpAndSettle();
    expect(find.byType(FightWeekScreen), findsOneWidget);
  });

  testWidgets("on the dashboard a warning outranks today's steps",
      (tester) async {
    await pumpWeek(tester,
        weighIns: entryAt(77), home: DashboardScreen(onNavigate: (_) {}));
    expect(find.text('Needs a supervised water cut. Tap to review.'),
        findsOneWidget);
    expect(find.textContaining('Today: '), findsNothing);
  });

  testWidgets('the weight path links to the fight week plan', (tester) async {
    await pumpWeek(tester,
        daysToWeighIn: 30,
        limit: 77,
        weighIns: [(1, 80.2), (0, 79.8)],
        home: const FightPathScreen());
    await tester.tap(find.text('Fight week plan'));
    await tester.pumpAndSettle();
    expect(find.byType(FightWeekScreen), findsOneWidget);
  });

  testWidgets('fits a 320 px phone at 200% text', (tester) async {
    await pumpWeek(tester, weighIns: [...entryAt(75), (0, 74.0)]);
    tester.view.physicalSize = const Size(320, 640);
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(boldText: true, highContrast: true);
    addTearDown(() {
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });
    await tester.pumpAndSettle();
    final list = find
        .descendant(
            of: find.byType(FightWeekScreen), matching: find.byType(Scrollable))
        .first;
    await tester.scrollUntilVisible(find.text('Keep it low'), 400,
        scrollable: list);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
