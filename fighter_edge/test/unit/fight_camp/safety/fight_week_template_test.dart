import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_week_plan.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/cut_safety_screen.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/fight_week_template.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/fighter_safety_flags.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/refuel_timeline.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);
const on = FighterSafetyFlags(fightWeekTemplate: true);

FightCamp campIn(int daysToWeighIn, {int lead = 1, double limit = 73.5}) =>
    FightCamp.tryCreate(
      fightDate: addDays(today, daysToWeighIn + lead),
      weighInDate: addDays(today, daysToWeighIn),
      weightLimitKg: limit,
      category: CompetitionCategory.professional,
      campWeeks: 12,
    )!;

WeightPath pathFor(FightCamp camp, double kg, {int age = 30}) =>
    WeightPathCalculator.calculate(
      currentWeightKg: kg,
      camp: camp,
      today: today,
      ageYears: age,
      screening: CampScreening.cleared,
    );

final cleared = CutSafetyScreen.evaluate(
    answers: const CutSafetyAnswers(ageYears: 30), today: today);

FightWeekTemplate? templateFor(
  double kg, {
  int days = 77,
  int lead = 1,
  FighterSafetyFlags flags = on,
  CutSafetyDecision? safety,
  int? age = 30,
}) {
  final camp = campIn(days, lead: lead);
  return FightWeekTemplate.build(
    camp: camp,
    path: pathFor(camp, kg),
    safety: safety ?? cleared,
    ageYears: age,
    flags: flags,
  );
}

void main() {
  group('gates', () {
    test('off by default', () {
      final camp = campIn(77);
      expect(
        FightWeekTemplate.build(
          camp: camp,
          path: pathFor(camp, 80),
          safety: cleared,
          ageYears: 30,
        ),
        isNull,
      );
    });

    test('only on track or at weight', () {
      expect(templateFor(80)!.days, isNotEmpty); // onTrack
      expect(templateFor(70), isNotNull); // atWeight
      // 95 kg to 73.5 kg in 10 weeks is not safe.
      final camp = campIn(77);
      final unsafe = pathFor(camp, 95);
      expect(unsafe.status, WeightPathStatus.notSafe);
      expect(
        FightWeekTemplate.build(
            camp: camp, path: unsafe, safety: cleared, ageYears: 30, flags: on),
        isNull,
      );
      // Needs a supervised water cut.
      final near = campIn(5);
      final supervised = pathFor(near, 77);
      expect(supervised.status, WeightPathStatus.needsSupervision);
      expect(
        FightWeekTemplate.build(
            camp: near,
            path: supervised,
            safety: cleared,
            ageYears: 30,
            flags: on),
        isNull,
      );
    });

    test('only when the safety screen clears', () {
      final referral = CutSafetyScreen.evaluate(
        answers: const CutSafetyAnswers(
          ageYears: 30,
          warningSigns: {CutWarningSign.fainting},
        ),
        today: today,
      );
      expect(templateFor(80, safety: referral), isNull);
      final minor = CutSafetyScreen.evaluate(
        answers: const CutSafetyAnswers(ageYears: 16),
        today: today,
      );
      expect(templateFor(80, safety: minor), isNull);
    });

    test('only with a valid adult age', () {
      expect(templateFor(80, age: null), isNull);
      expect(templateFor(80, age: 17), isNull);
    });
  });

  test('D-7 to fight day, then the week after', () {
    final t = templateFor(80)!;
    expect(t.cut, FightWeekCut.lowFibreAndCarbs);
    expect([for (final d in t.days) d.daysToWeighIn],
        [7, 6, 5, 4, 3, 2, 1, 0, -1, -2]);
    expect([
      for (final d in t.days) d.kind
    ], [
      for (var i = 0; i < 7; i++) TemplateDayKind.fightWeek,
      TemplateDayKind.weighIn,
      TemplateDayKind.fight,
      TemplateDayKind.postFight,
    ]);
    final camp = campIn(77);
    expect(t.days.first.date, camp.fightWeekStart);
    expect(t.days[7].date, camp.weighInDate);
    expect(t.days[8].date, camp.fightDate);
    expect(t.days.last.date, addDays(camp.fightDate, 1));
    expect(t.days.last.daysToFight, -1);
  });

  test('food changes come only from the fight-week plan', () {
    final t = templateFor(80)!;
    final food = [for (final d in t.days.take(7)) d.food];
    for (var i = 0; i < 3; i++) {
      expect(food[i], contains(TemplateFood.eatAsCamp));
      expect(food[i], isNot(contains(TemplateFood.lowerFibre)));
    }
    for (var i = 3; i < 7; i++) {
      expect(food[i],
          containsAll([TemplateFood.lowerFibre, TemplateFood.lowerCarbs]));
    }
    expect(food[0], contains(TemplateFood.practiseRefuelFoods));
    expect(food[6], contains(TemplateFood.regularMeals));
  });

  test('at weight: eat as in camp all week', () {
    final t = templateFor(70)!;
    expect(t.cut, FightWeekCut.none);
    for (final d in t.days.take(7)) {
      expect(d.food, contains(TemplateFood.eatAsCamp));
      expect(d.food, isNot(contains(TemplateFood.lowerFibre)));
      expect(d.food, isNot(contains(TemplateFood.lowerCarbs)));
    }
  });

  test('hydration is never restricted before the weigh-in', () {
    final t = templateFor(80)!;
    for (final d in t.days) {
      if (d.isWeighInDay) {
        expect(d.hydration, TemplateHydration.refuelAfterScale);
      } else {
        expect(d.hydration, TemplateHydration.drinkToThirst);
      }
    }
  });

  test('day checks follow the research skeleton', () {
    final t = templateFor(80)!;
    expect(t.days[0].training, TemplateTraining.lastHardSession);
    expect(t.days[0].checks, contains(TemplateCheck.confirmWeighInRules));
    expect(t.days[4].daysToWeighIn, 3);
    expect(t.days[4].checks, [TemplateCheck.overLimitReferral]);
    expect(t.days[6].checks, [TemplateCheck.weightOptions]);
    expect(t.days[7].checks, [TemplateCheck.logWeighInWeight]);
    expect(t.days[7].food, [TemplateFood.followRefuelTimeline]);
    expect(t.days[8].food, contains(TemplateFood.fightDayFuel));
    expect(t.days[8].training, TemplateTraining.perEvent);
    expect(t.days.last.food, contains(TemplateFood.noDeficit));
    for (final d in t.days) {
      expect(d.food, isNotEmpty);
      expect(d.checks, isNotEmpty);
    }
  });

  test('two-day weigh-in lead adds a refuel day', () {
    final t = templateFor(80, lead: 2)!;
    expect([for (final d in t.days) d.kind].sublist(7), [
      TemplateDayKind.weighIn,
      TemplateDayKind.refuel,
      TemplateDayKind.fight,
      TemplateDayKind.postFight,
    ]);
    expect(t.days[8].checks, [TemplateCheck.logWeightRegain]);
    expect(t.days.last.daysToWeighIn, -3);
  });

  test('same-day weigh-in: one day is weigh-in and fight', () {
    final t = templateFor(80, lead: 0)!;
    final day = t.days[7];
    expect(day.kind, TemplateDayKind.fight);
    expect(day.daysToWeighIn, 0);
    expect(day.food.first, TemplateFood.followRefuelTimeline);
    expect(day.hydration, TemplateHydration.refuelAfterScale);
    expect(day.checks,
        [TemplateCheck.logWeighInWeight, TemplateCheck.reportSymptoms]);
    expect(t.days.length, 9);
    expect(t.refuel.steps.map((s) => s.window),
        [RefuelWindow.firstTwoHours, RefuelWindow.fightDay]);
  });

  test('the refuel timeline rides along, amounts behind their own flag', () {
    expect(templateFor(80)!.refuel.showsAmounts, isFalse);
    final both = templateFor(80,
        flags: const FighterSafetyFlags(
            fightWeekTemplate: true, refuelVolumes: true))!;
    expect(both.refuel.showsAmounts, isTrue);
  });

  test('dayOn finds the day, and the post-fight entry for the week after', () {
    final t = templateFor(80)!;
    final camp = campIn(77);
    expect(t.dayOn(addDays(camp.fightWeekStart, -1)), isNull);
    expect(t.dayOn(camp.fightWeekStart)!.daysToWeighIn, 7);
    expect(t.dayOn(camp.weighInDate)!.kind, TemplateDayKind.weighIn);
    expect(t.dayOn(camp.fightDate)!.kind, TemplateDayKind.fight);
    expect(
        t.dayOn(addDays(camp.fightDate, 1))!.kind, TemplateDayKind.postFight);
    expect(
        t.dayOn(addDays(camp.fightDate, 7))!.kind, TemplateDayKind.postFight);
    expect(t.dayOn(addDays(camp.fightDate, 8)), isNull);
  });

  test('caveats are always all shown', () {
    expect(FightWeekTemplate.caveats, TemplateCaveat.values);
    expect(
        FightWeekTemplate.caveats, contains(TemplateCaveat.notAWeightLossPlan));
    expect(WeightCutPolicy.fightWeekDays, 7);
  });
}
