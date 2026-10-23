import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/safety/camp_length_check.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

FightCamp campIn(int daysToWeighIn, {double limit = 70}) => FightCamp.tryCreate(
      fightDate: addDays(today, daysToWeighIn),
      weightLimitKg: limit,
      category: CompetitionCategory.amateurStriking,
      campWeeks: 16,
    )!;

CampLengthResult? check(double walkAround, int days) =>
    CampLengthCheck.evaluate(
      walkAroundWeightKg: walkAround,
      camp: campIn(days),
      today: today,
    );

void main() {
  test('a small cut over a long camp shows no caution', () {
    final r = check(75, 70)!;
    expect(r.cautions, isEmpty);
    expect(r.showCaution, isFalse);
    expect(r.totalLossKg, closeTo(5, 1e-9));
    expect(r.totalLossFraction, closeTo(5 / 75, 1e-9));
    expect(r.daysToWeighIn, 70);
    expect(r.aboveUpperBand, isFalse);
  });

  test('total loss above 12% of walk-around weight', () {
    // 80 -> 70 is 12.5%.
    final r = check(80, 70)!;
    expect(r.cautions, {CampLengthCaution.largeTotalLoss});
    expect(r.aboveUpperBand, isFalse);
    // 84 -> 70 is 16.7%.
    expect(check(84, 70)!.aboveUpperBand, isTrue);
  });

  test('exactly 12% is not above it', () {
    // 70 / 0.88 = 79.545...: the cut is 12.0% of walk-around.
    expect(check(70 / 0.88, 70)!.cautions, isEmpty);
  });

  test('any cut with under 8 weeks to the weigh-in', () {
    expect(check(72, 55)!.cautions, {CampLengthCaution.shortCamp});
    expect(check(72, 56)!.cautions, isEmpty);
    expect(check(85, 30)!.cautions,
        {CampLengthCaution.shortCamp, CampLengthCaution.largeTotalLoss});
  });

  test('no cut, no caution, even in a short camp', () {
    final r = check(69, 20)!;
    expect(r.cautions, isEmpty);
    expect(r.totalLossKg, 0);
    expect(r.totalLossFraction, 0);
    expect(check(70, 20)!.cautions, isEmpty);
  });

  test('bad input or a past weigh-in gives no result', () {
    expect(check(0, 70), isNull);
    expect(check(-5, 70), isNull);
    expect(check(double.nan, 70), isNull);
    expect(check(double.infinity, 70), isNull);
    expect(
      CampLengthCheck.evaluate(
        walkAroundWeightKg: 80,
        camp: campIn(0),
        today: addDays(today, 1),
      ),
      isNull,
    );
  });

  test('thresholds match the spec', () {
    expect(CampLengthCheck.cautionLossFraction, 0.12);
    expect(CampLengthCheck.upperLossFraction, 0.15);
    expect(CampLengthCheck.minCampWeeks, 8);
  });
}
