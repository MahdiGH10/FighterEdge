import 'package:fighter_edge/features/fight_camp/data/in_memory_fight_camp_repository.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/screens/fight_setup_screen.dart';
import 'package:fighter_edge/screens/dashboard_screen.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:fighter_edge/widgets/primary_button.dart';
import 'package:fighter_edge/features/fight_camp/presentation/widgets/fight_countdown_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fighter_edge/theme/app_icons.dart';

import '../../helpers/test_harness.dart';

void main() {
  late InMemoryFightCampRepository fights;

  setUp(() {
    fights = InMemoryFightCampRepository();
  });

  Future<String> pumpDashboard(WidgetTester tester, {AppState? state}) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final repo = await makeRepo(signedIn: true, onboarded: true);
    await tester.pumpWidget(wrapApp(
      DashboardScreen(onNavigate: (_) {}),
      repo: repo,
      state: state,
      fightCampRepo: fights,
    ));
    await tester.pumpAndSettle();
    return repo.currentUser!.id;
  }

  PrimaryButton saveButton(WidgetTester tester) => tester
      .widget<PrimaryButton>(find.widgetWithText(PrimaryButton, 'Save fight'));

  testWidgets('sets a fight from the dashboard and shows the countdown',
      (tester) async {
    final userId = await pumpDashboard(tester);

    expect(find.text('Fight night', findRichText: false), findsNothing);
    await tester.tap(find.text('Add your next fight'));
    await tester.pumpAndSettle();
    expect(find.byType(FightSetupScreen), findsOneWidget);
    expect(saveButton(tester).onPressed, isNull, reason: 'nothing chosen yet');

    // The picker opens on eight weeks out; accept it.
    await tester.tap(find.text('Choose date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '70');
    await tester.tap(find.text('Professional'));
    await tester.pumpAndSettle();
    expect(saveButton(tester).onPressed, isNotNull);
    expect(find.text('Your weight path'), findsOneWidget);
    expect(
      find.textContaining('International Society of Sports Nutrition'),
      findsOneWidget,
    );

    await tester.tap(find.text('Save fight'));
    await tester.pumpAndSettle();

    expect(find.byType(FightSetupScreen), findsNothing);
    expect(find.textContaining('Fight night'), findsOneWidget);
    expect(find.text('56'), findsOneWidget);
    expect(find.text('days to go'), findsOneWidget);
    expect(find.text('Add your next fight'), findsNothing);

    final saved = (await fights.watchFight(userId).first)!;
    expect(saved.weightLimitKg, 70);
    expect(saved.category, CompetitionCategory.professional);
    expect(daysBetween(saved.weighInDate, saved.fightDate), 1);
    expect(saved.campWeeks, FightCamp.defaultCampWeeks);
  });

  testWidgets('edits and removes a saved fight', (tester) async {
    final state = AppState();
    final userId = await pumpDashboard(tester, state: state);
    await fights.saveFight(
      userId,
      FightCamp.tryCreate(
        fightDate: addDays(state.now, 30),
        weightLimitKg: 77.1,
        category: CompetitionCategory.grappling,
        campWeeks: 6,
      )!,
    );
    await tester.pumpAndSettle();

    expect(find.text('30'), findsOneWidget);
    await tester.tap(find.textContaining('Fight night'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Edit fight'));
    await tester.pumpAndSettle();

    expect(find.text('77.1'), findsOneWidget, reason: 'limit prefilled');
    expect(saveButton(tester).onPressed, isNotNull);

    await tester.tap(find.text('Remove fight'));
    await tester.pumpAndSettle();
    expect(find.text('Remove this fight?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Remove fight').last);
    await tester.pumpAndSettle();

    expect(find.byType(FightSetupScreen), findsNothing);
    expect(find.textContaining('Fight night'), findsNothing);
    expect(find.text('Add your next fight'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AddFightRow),
        matching: find.byIcon(AppIcons.caretRight),
      ),
      findsOneWidget,
      reason: 'one arrow, not two',
    );
    expect(await fights.watchFight(userId).first, isNull);
  });

  testWidgets('a limit outside the range is refused inline', (tester) async {
    await pumpDashboard(tester);
    await tester.tap(find.text('Add your next fight'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), '20');
    await tester.pumpAndSettle();
    expect(find.text('Enter a limit between 35 and 220 kg.'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '70,5');
    await tester.pumpAndSettle();
    expect(find.textContaining('Enter a limit'), findsNothing,
        reason: 'a decimal comma is accepted');
  });
}
