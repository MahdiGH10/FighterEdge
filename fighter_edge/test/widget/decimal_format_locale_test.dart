import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_setup_screen.dart';
import 'package:fighter_edge/features/fight_camp/presentation/widgets/fight_countdown_card.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/screens/profile_screen.dart';
import 'package:fighter_edge/screens/weight_tracker_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_harness.dart';

/// A German-locale user reads the same numbers as everyone else, just with
/// ',' where an English screen shows '.'. These screens compute the number
/// before the locale (`LocaleController`, loaded async from prefs) has
/// necessarily settled, so `formatFixedDecimal` — and, on the two screens
/// with an editable weight field, moving the pre-fill out of `initState`
/// into `didChangeDependencies` — is what makes the display correct instead
/// of crashing or silently staying in English digits.
void main() {
  /// Switches the *next* pumped app to German by pre-seeding the same pref
  /// key `LocaleController` reads, before its `..load()` runs — the same
  /// mechanism Settings > Language writes, without navigating there.
  Future<void> useGermanLocale() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('fe_locale', 'de');
  }

  testWidgets('dashboard weight stat uses a German comma', (tester) async {
    final wednesday = DateTime(2026, 9, 23, 20);
    final repo = await makeRepo(signedIn: true);
    await useGermanLocale();
    final state = AppState(clock: () => wednesday);
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
    ));
    await tester.pumpAndSettle();

    expect(find.text('77.2'), findsNothing, reason: 'not the English form');
    expect(find.text('77,2'), findsWidgets);
  });

  testWidgets(
      'weight tracker: hero number, 7-day average and the weigh-in dialog',
      (tester) async {
    tester.view.physicalSize = const Size(430, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true);
    await useGermanLocale();
    final state = AppState();
    await tester.pumpWidget(
      wrapApp(const WeightTrackerScreen(), repo: repo, state: state),
    );
    await tester.pumpAndSettle();

    // The animated hero number and the "7-day avg" StatCard both round-trip
    // the German string back through NumberFormat (stat_card.dart) to
    // animate; if that parse ever regresses to double.tryParse, the number
    // silently stops animating but must still, per the fallback branch,
    // show the correct text — either way this text must be on screen.
    expect(find.text('77.2'), findsNothing);
    expect(find.text('77,2'), findsWidgets);

    // The header action is an icon-only HeaderIcon (its label is a
    // semantics string, localized, not visible text), so it's found by icon.
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byType(TextField).first);
    expect(field.controller!.text, '77,2',
        reason: 'pre-filled from didChangeDependencies, not initState');

    // The comma the field is pre-filled with must still save correctly —
    // the input formatter/parse path already tolerated ',' before this fix;
    // confirm the pre-fill did not disturb that.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('profile measurements use a German comma', (tester) async {
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await useGermanLocale();
    final state = AppState();
    await tester.pumpWidget(
      wrapApp(const ProfileScreen(), repo: repo, state: state),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('77.2'), findsNothing);
    expect(find.textContaining('77,2'), findsOneWidget);
  });

  testWidgets('fight setup pre-fills the weight limit with a German comma',
      (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await useGermanLocale();
    final state = AppState();
    final fights = InMemoryFightCampRepository();
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
      fightCampRepo: fights,
    ));
    await tester.pumpAndSettle();
    await fights.saveFight(
      repo.currentUser!.id,
      FightCamp.tryCreate(
        fightDate: addDays(state.now, 30),
        weightLimitKg: 77.1,
        category: CompetitionCategory.grappling,
        campWeeks: 6,
      )!,
    );
    await tester.pumpAndSettle();

    // Not found by text or semantics label: under German locale the card
    // reads "Kampfabend" and the edit action's semantics label is German
    // too, so both are found by type/icon instead.
    await tester.tap(find.byType(FightCountdownCard));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(find.byType(FightSetupScreen), findsOneWidget);

    final limitField = tester.widget<TextField>(find.byType(TextField).first);
    expect(limitField.controller!.text, '77,1');
  });
}
