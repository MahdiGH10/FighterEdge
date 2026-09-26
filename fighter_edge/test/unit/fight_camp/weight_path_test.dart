import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 10, 1);

/// 73.5 kg is chosen so a food-only fight week (2%) starts at 75.0 kg.
FightCamp campIn(
  int daysToWeighIn, {
  double limit = 73.5,
  CompetitionCategory category = CompetitionCategory.professional,
}) =>
    FightCamp.tryCreate(
      fightDate: addDays(today, daysToWeighIn),
      weightLimitKg: limit,
      category: category,
    )!;

WeightPath plan(
  double? current,
  int daysToWeighIn, {
  double limit = 73.5,
  CompetitionCategory category = CompetitionCategory.professional,
  int? age,
}) =>
    WeightPathCalculator.calculate(
      currentWeightKg: current,
      camp: campIn(daysToWeighIn, limit: limit, category: category),
      today: today,
      ageYears: age,
    );

void main() {
  test('10 weeks of camp, 5 kg over the food-only start: 0.5 kg a week', () {
    final path = plan(80, 77);
    expect(path.status, WeightPathStatus.onTrack);
    expect(path.weeklyLossKg, 0.5);
    expect(path.isGentlePace, isTrue);
    expect(path.fightWeekEntryKg, 75.0);
    expect(path.acuteLossKg, 1.5);
    expect(path.acuteLossFraction, closeTo(0.02, 1e-9));
    expect(path.lightestSafeLimitKg, isNull);
    expect(path.checkpoints, hasLength(10));
    expect(path.checkpoints.first, WeightCheckpoint(addDays(today, 7), 79.5));
    expect(path.checkpoints.last, WeightCheckpoint(addDays(today, 70), 75.0));
  });

  test('3 weeks is too short for food alone: fastest camp, flag supervision',
      () {
    final path = plan(80, 28);
    expect(path.status, WeightPathStatus.needsSupervision);
    expect(path.weeklyLossKg, 1.0);
    expect(path.requiredWeeklyLossKg, 1.67);
    expect(path.fightWeekEntryKg, 77.0);
    expect(path.acuteLossKg, 3.5);
    expect(path.acuteLossFraction, closeTo(3.5 / 77, 1e-9));
    expect(path.lightestSafeLimitKg, 75.5);
    expect(path.checkpoints.map((c) => c.weightKg), [79.0, 78.0, 77.0]);
  });

  test('grappling allows less water loss than pro MMA', () {
    expect(plan(80, 21).status, WeightPathStatus.needsSupervision);
    final grappling = plan(80, 21, category: CompetitionCategory.grappling);
    expect(grappling.status, WeightPathStatus.notSafe);
    expect(grappling.requiredWeeklyLossKg, 2.5);
    expect(grappling.lightestSafeLimitKg, 76.4);
    expect(grappling.checkpoints, isEmpty);
    expect(grappling.fightWeekEntryKg, isNull);
  });

  test('far too heavy for the date is not safe, with the class it can make',
      () {
    final path = plan(90, 28);
    expect(path.status, WeightPathStatus.notSafe);
    expect(path.weeklyLossKg, 0);
    expect(path.lightestSafeLimitKg, 85.3);
  });

  group('in fight week everything left is acute', () {
    test('within 2% is food-only', () {
      final path = plan(74.9, 2);
      expect(path.status, WeightPathStatus.onTrack);
      expect(path.acuteLossKg, 1.4);
      expect(path.checkpoints, isEmpty);
    });

    test('4.5% two days out needs supervision; one day out is not safe', () {
      expect(plan(77, 2).status, WeightPathStatus.needsSupervision);
      final oneDay = plan(77, 1);
      expect(oneDay.status, WeightPathStatus.notSafe);
      expect(oneDay.lightestSafeLimitKg, 75.5);
    });

    test('grappling caps at 5% even three days out', () {
      final grappling = CompetitionCategory.grappling;
      expect(plan(77, 3, category: grappling).status,
          WeightPathStatus.needsSupervision);
      expect(plan(78, 3, category: grappling).status, WeightPathStatus.notSafe);
    });
  });

  test('at or under the limit needs no plan', () {
    expect(plan(73.5, 40).status, WeightPathStatus.atWeight);
    expect(plan(70, 40).status, WeightPathStatus.atWeight);
  });

  test('just above the limit holds weight through camp', () {
    final path = plan(74.5, 40);
    expect(path.status, WeightPathStatus.onTrack);
    expect(path.weeklyLossKg, 0);
    expect(path.fightWeekEntryKg, 74.5);
  });

  test('never plans for a minor', () {
    expect(plan(80, 77, age: 17).status, WeightPathStatus.notSupported);
    expect(plan(80, 77, age: 18).status, WeightPathStatus.onTrack);
  });

  test('needs a current weight and a weigh-in still ahead', () {
    expect(plan(null, 40).status, WeightPathStatus.needsMoreData);
    expect(plan(double.nan, 40).status, WeightPathStatus.needsMoreData);
    expect(plan(0, 40).status, WeightPathStatus.needsMoreData);
    expect(plan(80, -1).status, WeightPathStatus.needsMoreData);
  });

  test('no plan anywhere exceeds the position stand limits', () {
    var planned = 0;
    for (var current = 55.0; current <= 110; current += 2.5) {
      for (var limit = 52.0; limit <= 100; limit += 3.1) {
        for (var days = 0; days <= 120; days += 3) {
          for (final category in CompetitionCategory.values) {
            final path = plan(current, days, limit: limit, category: category);
            final reason = '$current kg, $limit limit, $days days, $category';
            if (path.status != WeightPathStatus.onTrack &&
                path.status != WeightPathStatus.needsSupervision) {
              expect(path.checkpoints, isEmpty, reason: reason);
              continue;
            }
            planned++;
            expect(path.weeklyLossKg,
                lessThanOrEqualTo(WeightCutPolicy.maxWeeklyLossKg),
                reason: reason);
            final cap = path.status == WeightPathStatus.onTrack
                ? WeightCutPolicy.dietOnlyAcuteFraction
                : WeightCutPolicy.supervisedAcuteFraction(category, days);
            expect(path.acuteLossFraction, lessThanOrEqualTo(cap + 1e-9),
                reason: reason);
            final points = path.checkpoints;
            for (var i = 1; i < points.length; i++) {
              expect(
                  points[i].weightKg, lessThanOrEqualTo(points[i - 1].weightKg),
                  reason: reason);
              // Rounding to 0.1 kg is the only slack.
              final days = daysBetween(points[i - 1].date, points[i].date);
              expect(days, greaterThanOrEqualTo(4), reason: reason);
              expect(
                  points[i - 1].weightKg - points[i].weightKg,
                  lessThanOrEqualTo(
                      WeightCutPolicy.maxWeeklyLossKg * days / 7 + 0.1),
                  reason: reason);
            }
            if (points.isNotEmpty) {
              expect(points.last.weightKg, path.fightWeekEntryKg,
                  reason: reason);
            }
          }
        }
      }
    }
    expect(planned, greaterThan(1000));
  });
}
