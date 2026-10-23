import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/fighter_safety_flags.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/refuel_timeline.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

FightCamp camp({int lead = 1, double limit = 70}) => FightCamp.tryCreate(
      fightDate: addDays(today, 30 + lead),
      weighInDate: addDays(today, 30),
      weightLimitKg: limit,
      category: CompetitionCategory.professional,
    )!;

const volumesOn = FighterSafetyFlags(refuelVolumes: true);

List<RefuelWindow> windowsOf(RefuelTimeline t) =>
    [for (final s in t.steps) s.window];

void main() {
  test('flags default off', () {
    expect(FighterSafetyFlags.off.refuelVolumes, isFalse);
    expect(FighterSafetyFlags.off.fightWeekTemplate, isFalse);
    expect(const FighterSafetyFlags().refuelVolumes, isFalse);
  });

  test('adults only', () {
    for (final age in [null, 0, 15, 17, 121]) {
      expect(RefuelTimeline.build(camp: camp(), ageYears: age), isNull,
          reason: '$age');
    }
    expect(RefuelTimeline.build(camp: camp(), ageYears: 18), isNotNull);
  });

  test('day-before weigh-in: every window, no amounts by default', () {
    final t = RefuelTimeline.build(camp: camp(), ageYears: 25)!;
    expect(windowsOf(t), RefuelWindow.values);
    expect(t.showsAmounts, isFalse);
    for (final step in t.steps) {
      expect(step.amounts, isNull, reason: step.window.name);
      expect(step.focus, isNotEmpty);
      expect(step.checks, isNotEmpty);
    }
    final first = t.step(RefuelWindow.firstTwoHours)!;
    expect(first.focus, contains(RefuelFocus.oralRehydrationSolution));
    expect(first.focus, contains(RefuelFocus.avoidGutIrritants));
    expect(first.startHour, 0);
    expect(t.step(RefuelWindow.threeToSixHours)!.startHour, 2);
    expect(t.step(RefuelWindow.sixHoursPlus)!.startHour, 6);
    expect(t.step(RefuelWindow.fightDay)!.startHour, isNull);
  });

  test('same-day weigh-in with unknown gap: first two hours and fight day', () {
    final t = RefuelTimeline.build(camp: camp(lead: 0), ageYears: 25)!;
    expect(windowsOf(t), [RefuelWindow.firstTwoHours, RefuelWindow.fightDay]);
  });

  test('a known gap trims the windows', () {
    List<RefuelWindow> forGap(int hours) => windowsOf(RefuelTimeline.build(
          camp: camp(lead: 0),
          ageYears: 25,
          hoursWeighInToFight: hours,
        )!);
    expect(forGap(2), [RefuelWindow.firstTwoHours, RefuelWindow.fightDay]);
    expect(forGap(5), [
      RefuelWindow.firstTwoHours,
      RefuelWindow.threeToSixHours,
      RefuelWindow.fightDay,
    ]);
    expect(forGap(8), RefuelWindow.values);
  });

  test('amounts behind the flag come from the policy', () {
    final t =
        RefuelTimeline.build(camp: camp(), ageYears: 25, flags: volumesOn)!;
    expect(t.showsAmounts, isTrue);

    final first = t.step(RefuelWindow.firstTwoHours)!.amounts!;
    expect(first.minLitresPerHour, WeightCutPolicy.refuelMinLitresPerHour);
    expect(first.maxLitresPerHour, WeightCutPolicy.refuelMaxLitresPerHour);
    expect(first.maxCarbGramsPerHour, 60);

    final mid = t.step(RefuelWindow.threeToSixHours)!.amounts!;
    expect(mid.maxCarbGramsPerHour, 60);
    expect(mid.minLitresPerHour, isNull);

    // 4-7 g/kg at the 70 kg limit.
    final late = t.step(RefuelWindow.sixHoursPlus)!.amounts!;
    expect(late.totalCarbMinGrams, 280);
    expect(late.totalCarbMaxGrams, 490);

    // 1-4 g/kg, 20-30 g protein a meal, low fat for 3 h.
    final fight = t.step(RefuelWindow.fightDay)!.amounts!;
    expect(fight.totalCarbMinGrams, 70);
    expect(fight.totalCarbMaxGrams, 280);
    expect(fight.proteinMinGramsPerMeal, 20);
    expect(fight.proteinMaxGramsPerMeal, 30);
    expect(fight.lowFatHoursBeforeBout, 3);
    expect(RefuelPolicy.fightDayMinCarbGramsPerKg, 1);
    expect(RefuelPolicy.fightDayMaxCarbGramsPerKg, 4);
  });

  test('carb totals round to 10 g', () {
    final t = RefuelTimeline.build(
        camp: camp(limit: 66.8), ageYears: 25, flags: volumesOn)!;
    // 66.8 * 4 = 267.2 -> 270; 66.8 * 7 = 467.6 -> 470.
    expect(t.step(RefuelWindow.sixHoursPlus)!.amounts!.totalCarbMinGrams, 270);
    expect(t.step(RefuelWindow.sixHoursPlus)!.amounts!.totalCarbMaxGrams, 470);
  });

  test('no between-weigh-in-and-fight total on a same-day weigh-in', () {
    final t = RefuelTimeline.build(
      camp: camp(lead: 0),
      ageYears: 25,
      hoursWeighInToFight: 10,
      flags: volumesOn,
    )!;
    expect(t.step(RefuelWindow.sixHoursPlus)!.amounts, isNull);
    expect(t.step(RefuelWindow.fightDay)!.amounts, isNotNull);
  });
}
