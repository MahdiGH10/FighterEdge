import 'package:fighter_edge/billing/subscription.dart';
import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_path_screen.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_setup_screen.dart';
import 'package:fighter_edge/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';
import 'large_text_test.dart' show expectNoFlutterException;

void main() {
  testWidgets(
      'the countdown and the prefilled setup fit a 320 px phone at 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2.0;
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(
      boldText: true,
      highContrast: true,
      disableAnimations: true,
    );
    addTearDown(() {
      tester.view.reset();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
    });

    final repo =
        await makeRepo(signedIn: true, plan: Plan.free, onboarded: true);
    final fights = InMemoryFightCampRepository();
    await fights.saveFight(
      repo.currentUser!.id,
      FightCamp.tryCreate(
        fightDate: addDays(DateTime.now(), 40),
        weightLimitKg: 61.2,
        category: CompetitionCategory.amateurStriking,
      )!,
    );

    await tester
        .pumpWidget(FighterEdgeApp(authRepo: repo, fightCampRepo: fights));
    await tester.pumpAndSettle();
    expectNoFlutterException(tester);
    expect(find.textContaining('Fight night'), findsOneWidget);

    await tester.tap(find.textContaining('Fight night'));
    await tester.pumpAndSettle();
    expect(find.byType(FightPathScreen), findsOneWidget);
    expectNoFlutterException(tester);

    await tester.tap(find.bySemanticsLabel('Edit fight'));
    await tester.pumpAndSettle();
    expect(find.byType(FightSetupScreen), findsOneWidget);
    expectNoFlutterException(tester);

    await tester.scrollUntilVisible(find.text('Remove fight'), 300,
        scrollable: find
            .descendant(
                of: find.byType(FightSetupScreen),
                matching: find.byType(Scrollable))
            .first);
    await tester.pumpAndSettle();
    expectNoFlutterException(tester);
  });
}
