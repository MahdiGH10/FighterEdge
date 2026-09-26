import 'package:fighter_edge/data/in_memory_data_repository.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_path_screen.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_setup_screen.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/test_harness.dart';

final now = DateTime(2026, 10, 1, 9);

void main() {
  late InMemoryFightCampRepository fights;
  late AppState state;

  setUp(() {
    fights = InMemoryFightCampRepository();
    state =
        AppState(dataRepository: InMemoryDataRepository(), clock: () => now);
  });

  Future<void> pumpPath(
    WidgetTester tester, {
    required double limit,
    List<(int, double)> weighIns = const [(1, 80.4), (0, 79.6)],
  }) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final (daysAgo, kg) in weighIns) {
      state.addWeight(addDays(now, -daysAgo), kg);
    }
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await fights.saveFight(
      repo.currentUser!.id,
      FightCamp.tryCreate(
        fightDate: addDays(now, 78),
        weighInDate: addDays(now, 77),
        weightLimitKg: limit,
        category: CompetitionCategory.professional,
        campWeeks: 12,
      )!,
    );
    await tester.pumpWidget(wrapApp(
      const FightPathScreen(),
      repo: repo,
      state: state,
      fightCampRepo: fights,
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('on pace: summary, plan on the chart and weekly targets',
      (tester) async {
    await pumpPath(tester, limit: 73.5);

    expect(find.textContaining('Camp · week 2 of 12'), findsOneWidget);
    expect(find.text('Your weight path'), findsOneWidget);
    expect(find.textContaining('On pace: lose 0.5 kg a week'), findsOneWidget);
    expect(find.text('Plan'), findsOneWidget);
    expect(find.text('7-day trend'), findsOneWidget);
    expect(find.text('Limit 73.5'), findsNothing,
        reason: 'the chart is drawn, not text widgets');

    expect(find.text('Weekly targets'), findsOneWidget);
    expect(find.text('79.5 kg'), findsOneWidget, reason: 'first week');
    expect(find.text('75.0 kg'), findsOneWidget, reason: 'fight week entry');
    expect(find.text('Fight week starts'), findsOneWidget);
  });

  testWidgets('not safe: no plan line and no weekly targets', (tester) async {
    await pumpPath(tester, limit: 60);

    expect(find.textContaining('Not safe by this date'), findsOneWidget);
    expect(find.text('Plan'), findsNothing);
    expect(find.text('Weekly targets'), findsNothing);
  });

  testWidgets('one weigh-in is not enough to draw a trend', (tester) async {
    await pumpPath(tester, limit: 73.5, weighIns: [(0, 80)]);
    expect(find.text('Log two weigh-ins to draw your trend.'), findsOneWidget);
  });

  testWidgets('dashboard countdown opens the plan; edit opens the setup',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await fights.saveFight(
      repo.currentUser!.id,
      FightCamp.tryCreate(
        fightDate: addDays(now, 40),
        weightLimitKg: 73.5,
        category: CompetitionCategory.olympic,
      )!,
    );
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
      fightCampRepo: fights,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.textContaining('Fight night'));
    await tester.pumpAndSettle();
    expect(find.byType(FightPathScreen), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Edit fight'));
    await tester.pumpAndSettle();
    expect(find.byType(FightSetupScreen), findsOneWidget);
  });
}
