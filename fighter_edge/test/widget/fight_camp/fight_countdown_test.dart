import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_controller.dart';
import 'package:fighter_edge/features/fight_camp/presentation/fight_camp_copy.dart';
import 'package:fighter_edge/features/fight_camp/presentation/widgets/fight_countdown_card.dart';
import 'package:fighter_edge/l10n/gen/app_localizations.dart';
import 'package:fighter_edge/models/weight_entry.dart';
import 'package:fighter_edge/state/app_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final today = DateTime(2026, 10, 1);

FightCamp fight({
  required int daysToFight,
  int weighInLead = 1,
  double limit = 73.5,
  int campWeeks = 8,
}) =>
    FightCamp.tryCreate(
      fightDate: addDays(today, daysToFight),
      weighInDate: addDays(today, daysToFight - weighInLead),
      weightLimitKg: limit,
      category: CompetitionCategory.professional,
      campWeeks: campWeeks,
    )!;

FightCampStatus statusFor(FightCamp camp, {double? weightKg = 80}) =>
    FightCampStatus.of(
      camp,
      weights: [if (weightKg != null) WeightEntry(today, weightKg)],
      today: today,
    );

/// A localized [FightCampCopy], and the card when [status] is given.
Future<FightCampCopy> pump(
  WidgetTester tester, {
  FightCampStatus? status,
  bool metric = true,
  Size size = const Size(390, 900),
  double textScale = 1,
}) async {
  SharedPreferences.setMockInitialValues({});
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(() {
    tester.view.reset();
    tester.platformDispatcher.clearTextScaleFactorTestValue();
  });
  final units = AppState();
  if (!metric) await units.setUseMetricUnits(false);
  late FightCampCopy copy;
  await tester.pumpWidget(MaterialApp(
    localizationsDelegates: L.localizationsDelegates,
    supportedLocales: L.supportedLocales,
    home: Scaffold(
      body: Builder(builder: (context) {
        copy = FightCampCopy(L.of(context), units, 'en');
        return status == null
            ? const SizedBox.shrink()
            : SingleChildScrollView(
                child: FightCountdownCard(
                  status: status,
                  copy: copy,
                  today: today,
                  onTap: () {},
                ),
              );
      }),
    ),
  ));
  await tester.pumpAndSettle();
  return copy;
}

void main() {
  group('path messages', () {
    testWidgets('state the pace and target in the athlete unit',
        (tester) async {
      final path = statusFor(fight(daysToFight: 78)).path; // 10 weeks of camp
      expect(path.status, WeightPathStatus.onTrack);

      final kg = await pump(tester);
      expect(kg.pathMessage(path),
          'On pace: lose 0.5 kg a week to reach 75.0 kg by fight week.');

      final lb = await pump(tester, metric: false);
      expect(lb.pathMessage(path),
          'On pace: lose 1.1 lb a week to reach 165.3 lb by fight week.');
    });

    testWidgets('cover every status', (tester) async {
      final copy = await pump(tester);
      String message(FightCamp camp, {double? weightKg = 80}) =>
          copy.pathMessage(statusFor(camp, weightKg: weightKg).path);

      // Camp takes a small excess off gently; only fight week holds.
      expect(message(fight(daysToFight: 40, limit: 79.9), weightKg: 80.5),
          'On pace: lose 0.1 kg a week to reach 79.9 kg by fight week.');
      expect(message(fight(daysToFight: 5, limit: 79.9), weightKg: 80.5),
          startsWith('Within reach'));
      expect(message(fight(daysToFight: 29)),
          allOf(contains('water cut'), contains('75.5 kg')));
      expect(message(fight(daysToFight: 29), weightKg: 90),
          allOf(startsWith('Not safe'), contains('85.3 kg')));
      expect(message(fight(daysToFight: 40, limit: 85)),
          "You're at weight. Hold steady.");
      expect(message(fight(daysToFight: 40), weightKg: null),
          'Log a weigh-in this week to see your path.');
      final minor = FightCampStatus.of(fight(daysToFight: 40),
          weights: [WeightEntry(today, 80)], today: today, ageYears: 15);
      expect(copy.pathMessage(minor.path),
          startsWith('Weight cut plans are for adults'));
    });

    testWidgets('warnings shorten to a pointer on the dashboard',
        (tester) async {
      final copy = await pump(tester);
      expect(copy.pathLine(statusFor(fight(daysToFight: 29)).path),
          'Needs a supervised water cut. Tap to review.');
      expect(
          copy.pathLine(statusFor(fight(daysToFight: 29), weightKg: 90).path),
          'Not safe by this date. Tap to review.');
    });
  });

  group('countdown card', () {
    testWidgets('in camp: days, week of camp and filled week segments',
        (tester) async {
      // Weigh-in 41 days out with an 8-week camp: day 15 of camp, week 3.
      await pump(tester, status: statusFor(fight(daysToFight: 42)));
      expect(find.textContaining('Fight night · '), findsOneWidget);
      expect(find.text('42'), findsOneWidget);
      expect(find.text('days to go'), findsOneWidget);
      expect(find.text('Camp · week 3 of 8'), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Fight night.*42 days to go')),
          findsOneWidget);
    });

    testWidgets('before camp starts it says when', (tester) async {
      await pump(tester, status: statusFor(fight(daysToFight: 100)));
      expect(find.textContaining('Camp starts '), findsOneWidget);
    });

    testWidgets('in fight week it counts the days', (tester) async {
      await pump(tester, status: statusFor(fight(daysToFight: 4)));
      expect(find.text('4'), findsOneWidget);
      expect(find.text('Fight week · day 5 of 7'), findsOneWidget);
    });

    testWidgets('weigh-in day and fight day replace the number',
        (tester) async {
      await pump(tester, status: statusFor(fight(daysToFight: 1)));
      expect(find.text('Weigh-in today'), findsOneWidget);

      await pump(tester, status: statusFor(fight(daysToFight: 0)));
      expect(find.text('Fight day'), findsOneWidget);
      expect(find.text('0'), findsNothing);

      await pump(tester,
          status: statusFor(fight(daysToFight: 0, weighInLead: 0)));
      expect(find.text('Fight day'), findsOneWidget);
    });

    testWidgets('fits a 320 px phone at 200 percent text', (tester) async {
      await pump(
        tester,
        status: statusFor(fight(daysToFight: 29)),
        size: const Size(320, 1400),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Needs a supervised water cut. Tap to review.'),
          findsOneWidget);
    });
  });
}
