import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_week_plan.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_trend.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

FightCamp campIn(
  int daysToWeighIn, {
  int lead = 0,
  double limit = 73.5,
  CompetitionCategory category = CompetitionCategory.professional,
}) =>
    FightCamp.tryCreate(
      fightDate: addDays(today, daysToWeighIn + lead),
      weighInDate: addDays(today, daysToWeighIn),
      weightLimitKg: limit,
      category: category,
      campWeeks: 12,
    )!;

FightWeekPlan? planFor(
  double? kg,
  int daysToWeighIn, {
  int lead = 0,
  double limit = 73.5,
  CompetitionCategory category = CompetitionCategory.professional,
  int? age = 30,
  CampScreening screening = CampScreening.cleared,
  // The plan's own default is off. Most tests here describe the plan with
  // refuel on; the group "refuel guidance is off unless asked for" covers off.
  bool refuel = true,
}) =>
    FightWeekPlan.plan(
      camp: campIn(daysToWeighIn, lead: lead, limit: limit, category: category),
      weights: [if (kg != null) WeightPoint(today, kg)],
      today: today,
      ageYears: age,
      screening: screening,
      refuelGuidance: refuel,
    );

List<List<FightWeekStep>> stepsOf(FightWeekPlan plan) =>
    [for (final d in plan.days) d.steps];

const eat = [FightWeekStep.eatToPlan];
const fibre = [FightWeekStep.lowFibre];
const fibreAndCarbs = [FightWeekStep.lowFibre, FightWeekStep.lowerCarbs];

void main() {
  test('2% left for fight week: low fibre and fewer carbs for four days', () {
    final plan = planFor(80, 77)!;
    expect(plan.status, WeightPathStatus.onTrack);
    expect(plan.cut, FightWeekCut.lowFibreAndCarbs);
    expect(plan.acuteLossKg, 1.5);
    expect(stepsOf(plan), [
      eat,
      eat,
      eat,
      fibreAndCarbs,
      fibreAndCarbs,
      fibreAndCarbs,
      fibreAndCarbs,
      [FightWeekStep.weighIn, FightWeekStep.refuel, FightWeekStep.fight],
    ]);
    expect(plan.days.first.date, addDays(today, 70));
    expect(plan.cutStart, addDays(today, 73));
    expect(plan.days.last.isWeighIn && plan.days.last.isFight, isTrue);
  });

  test('under 1% left: low fibre alone', () {
    final plan = planFor(81, 77, limit: 75.5)!;
    expect(plan.cut, FightWeekCut.lowFibre);
    expect(plan.acuteLossKg, 0.5);
    expect(stepsOf(plan).sublist(3, 7), [fibre, fibre, fibre, fibre]);
  });

  test('camp reaches the limit: eat to plan all week', () {
    final plan = planFor(74.5, 40)!;
    expect(plan.cut, FightWeekCut.none);
    expect(plan.acuteLossKg, 0);
    expect(plan.cutStart, isNull);
    expect(stepsOf(plan).take(7), everyElement(eat));
  });

  test('at weight already: no cut', () {
    expect(planFor(73, 40)!.cut, FightWeekCut.none);
  });

  test('a supervised cut does not get food or refuel prescriptions', () {
    final plan = planFor(80, 28)!;
    expect(plan.status, WeightPathStatus.needsSupervision);
    expect(plan.cut, FightWeekCut.notPlanned);
    expect(plan.refuel, isNull);
    expect(plan.days.expand((d) => d.steps),
        isNot(contains(FightWeekStep.lowFibre)));
  });

  test('not safe, or no weight: no food or refuel plan', () {
    for (final plan in [planFor(90, 28)!, planFor(null, 28)!]) {
      expect(plan.cut, FightWeekCut.notPlanned);
      expect(stepsOf(plan).take(7), everyElement(isEmpty));
      expect(plan.refuel, isNull);
      expect(plan.days.last.steps, isNot(contains(FightWeekStep.refuel)));
    }
  });

  test('no plan for a minor', () {
    expect(planFor(80, 77, age: 17), isNull);
    expect(planFor(80, 77, age: 18), isNotNull);
  });

  test('unknown age or health review holds back the whole plan', () {
    expect(planFor(80, 77, age: null), isNull);
    expect(planFor(80, 77, screening: CampScreening.pending), isNull);
    expect(planFor(80, 77, screening: CampScreening.needsProfessionalReview),
        isNull);
  });

  group('days between weigh-in and fight', () {
    test('day before: refuel, then fight', () {
      final plan = planFor(80, 77, lead: 1)!;
      expect(plan.days, hasLength(9));
      expect(plan.days[7].steps, [FightWeekStep.weighIn, FightWeekStep.refuel]);
      expect(plan.days[8].steps, [FightWeekStep.fight]);
      expect(plan.days[8].daysToWeighIn, -1);
    });

    test('two days before: a full refuel day in between', () {
      final plan = planFor(80, 77, lead: 2)!;
      expect(plan.days, hasLength(10));
      expect(plan.days[8].steps, [FightWeekStep.refuel]);
      expect(plan.days[9].isFight, isTrue);
    });
  });

  group('refuel targets (points 12–14)', () {
    test('4–7 g/kg of carbohydrate at the limit, rounded to 10 g', () {
      final refuel = planFor(80, 77, lead: 1)!.refuel!;
      expect(refuel.totalCarbMinGrams, 290, reason: '73.5 × 4 = 294');
      expect(refuel.totalCarbMaxGrams, 510, reason: '73.5 × 7 = 514.5');
      expect(refuel.minLitresPerHour, 1.0);
      expect(refuel.maxLitresPerHour, 1.5);
      expect(refuel.maxCarbGramsPerHour, 60);
    });

    test('same-day weigh-in: rates only, no total', () {
      final refuel = planFor(80, 77)!.refuel!;
      expect(refuel.totalCarbMinGrams, isNull);
      expect(refuel.totalCarbMaxGrams, isNull);
    });
  });

  // The refuel numbers are not reviewed by a sports dietitian yet (launch
  // audit SAFE-2/3), so a plan only carries them when a caller asks.
  group('refuel guidance is off unless asked for', () {
    List<FightWeekStep> withoutRefuel(List<FightWeekStep> steps) => [
          for (final s in steps)
            if (s != FightWeekStep.refuel) s
        ];

    test('the default plan has no refuel steps and no targets', () {
      final plan = FightWeekPlan.plan(
        camp: campIn(77, lead: 1),
        weights: [WeightPoint(today, 80)],
        today: today,
        ageYears: 30,
        screening: CampScreening.cleared,
      )!;
      expect(plan.status, WeightPathStatus.onTrack);
      expect(plan.refuel, isNull);
      expect(plan.days.expand((d) => d.steps),
          isNot(contains(FightWeekStep.refuel)));
    });

    test('the weigh-in and the days after carry no refuel step', () {
      final plan = planFor(80, 77, lead: 2, refuel: false)!;
      expect(plan.days[7].steps, [FightWeekStep.weighIn]);
      expect(plan.days[8].steps, isEmpty);
      expect(plan.days[9].steps, [FightWeekStep.fight]);
      expect(plan.dayOn(addDays(today, 77))!.steps, [FightWeekStep.weighIn]);
    });

    test('the food steps before the weigh-in do not change', () {
      final on = planFor(80, 77)!;
      final off = planFor(80, 77, refuel: false)!;
      expect(off.cut, on.cut);
      expect(off.acuteLossKg, on.acuteLossKg);
      expect(off.cutStart, on.cutStart);
      expect(stepsOf(off).take(7), stepsOf(on).take(7));
    });

    test('off is exactly on, minus the refuel, across the whole grid', () {
      var checked = 0;
      for (var current = 55.0; current <= 110; current += 5) {
        for (var limit = 52.0; limit <= 100; limit += 6.2) {
          for (var days = 0; days <= 90; days += 6) {
            for (var lead = 0; lead <= 2; lead++) {
              final on = planFor(current, days, lead: lead, limit: limit)!;
              final off = planFor(current, days,
                  lead: lead, limit: limit, refuel: false)!;
              final reason = '$current kg, $limit limit, $days days, +$lead';
              checked++;
              expect(off.refuel, isNull, reason: reason);
              expect(off.status, on.status, reason: reason);
              expect(off.cut, on.cut, reason: reason);
              expect(off.acuteLossKg, on.acuteLossKg, reason: reason);
              expect(off.days, hasLength(on.days.length), reason: reason);
              for (var i = 0; i < on.days.length; i++) {
                expect(off.days[i].steps, withoutRefuel(on.days[i].steps),
                    reason: '$reason, day $i');
              }
              // With it on, the targets exist exactly when food is planned.
              expect(on.refuel != null, on.cut != FightWeekCut.notPlanned,
                  reason: reason);
            }
          }
        }
      }
      expect(checked, greaterThan(1000));
    });

    test('a plan that was never made stays never made', () {
      for (final refuel in [true, false]) {
        expect(planFor(80, 77, age: 17, refuel: refuel), isNull);
        expect(planFor(80, 77, age: null, refuel: refuel), isNull);
        expect(
            planFor(80, 77, screening: CampScreening.pending, refuel: refuel),
            isNull);
      }
    });
  });

  group('in fight week the plan is fixed from its first day', () {
    final camp = campIn(7);
    final start = camp.fightWeekStart;

    test('weight coming off mid-week does not change the steps', () {
      final weights = [
        for (var d = -6; d <= 0; d++) WeightPoint(addDays(start, d), 75.0),
        for (var d = 1; d <= 4; d++) WeightPoint(addDays(start, d), 74.0),
      ];
      final plan = FightWeekPlan.plan(
          camp: camp,
          weights: weights,
          today: addDays(start, 4),
          ageYears: 30,
          screening: CampScreening.cleared)!;
      expect(plan.cut, FightWeekCut.lowFibreAndCarbs);
      expect(plan.acuteLossKg, 1.5);
    });

    test('without a weigh-in before it, today stands in', () {
      final plan = FightWeekPlan.plan(
        camp: camp,
        weights: [WeightPoint(addDays(start, 2), 74.0)],
        today: addDays(start, 2),
        ageYears: 30,
        screening: CampScreening.cleared,
      )!;
      expect(plan.cut, FightWeekCut.lowFibre);
      expect(plan.acuteLossKg, 0.5);
    });

    test('after the weigh-in the week still reads as planned', () {
      final plan = FightWeekPlan.plan(
        camp: campIn(7, lead: 1),
        weights: [WeightPoint(start, 75.0)],
        today: addDays(start, 8),
        ageYears: 30,
        screening: CampScreening.cleared,
      )!;
      expect(plan.cut, FightWeekCut.lowFibreAndCarbs);
      expect(plan.dayOn(addDays(start, 8))!.steps, [FightWeekStep.fight]);
    });
  });

  test('dayOn is null outside the plan', () {
    final plan = planFor(80, 77)!;
    expect(plan.dayOn(today), isNull);
    expect(plan.dayOn(addDays(today, 70))!.daysToWeighIn, 7);
    expect(plan.dayOn(addDays(today, 78)), isNull);
  });

  test('every plan keeps to the position stand', () {
    var checked = 0;
    for (var current = 55.0; current <= 110; current += 2.5) {
      for (var limit = 52.0; limit <= 100; limit += 3.1) {
        for (var days = 0; days <= 90; days += 4) {
          for (var lead = 0; lead <= 2; lead++) {
            final plan = planFor(current, days, lead: lead, limit: limit)!;
            final reason = '$current kg, $limit limit, $days days, +$lead';
            checked++;
            expect(
                plan.days, hasLength(WeightCutPolicy.fightWeekDays + 1 + lead),
                reason: reason);
            expect(plan.days.where((d) => d.isWeighIn), hasLength(1),
                reason: reason);
            expect(plan.days.last.isFight, isTrue, reason: reason);
            for (final day in plan.days) {
              final changed = day.steps.contains(FightWeekStep.lowFibre);
              if (changed) {
                expect(day.daysToWeighIn,
                    inInclusiveRange(1, WeightCutPolicy.lowFibreDays),
                    reason: reason);
              }
              if (day.steps.contains(FightWeekStep.lowerCarbs)) {
                expect(changed, isTrue, reason: reason);
              }
            }
            if (plan.status == WeightPathStatus.notSafe) {
              expect(plan.cut, FightWeekCut.notPlanned, reason: reason);
            }
            if (plan.cut == FightWeekCut.lowFibre) {
              // acuteLossKg is rounded to 0.1 kg.
              expect(
                  plan.acuteLossKg,
                  lessThanOrEqualTo(
                      current * WeightCutPolicy.lowFibreAcuteFraction + 0.05),
                  reason: reason);
            }
          }
        }
      }
    }
    expect(checked, greaterThan(5000));
  });
}
