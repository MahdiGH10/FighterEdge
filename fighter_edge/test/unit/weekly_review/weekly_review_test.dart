import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/weekly_review/domain/weekly_review.dart';

final _week = DateTime.utc(2026, 10, 19);

ReviewTraining _training({
  int planned = 4,
  int completed = 4,
  int? target,
  int missed = 0,
  String? movable,
}) =>
    ReviewTraining(
      planned: planned,
      completed: completed,
      target: target ?? planned,
      missed: missed,
      movableSessionId: movable,
    );

ReviewNutrition _food({
  int? target = 2500,
  int logged = 6,
  int? average = 2480,
  int? floor = 1900,
}) =>
    ReviewNutrition(
      targetCalories: target,
      targetProteinGrams: 160,
      loggedDays: logged,
      onTargetDays: 4,
      proteinHitDays: 5,
      averageCalories: average,
      restingEnergyKcal: floor,
    );

ReviewWeight _scale({double? change = -0.5, double? expected = -0.5, int n = 5}) =>
    ReviewWeight(changeKg: change, expectedChangeKg: expected, weighIns: n);

WeeklyReview _review({
  ReviewTraining? training,
  ReviewNutrition? food,
  ReviewWeight? scale,
}) =>
    WeeklyReviewCalculator.build(
      weekStart: _week,
      training: training ?? _training(),
      nutrition: food ?? _food(),
      weight: scale ?? _scale(),
    );

void main() {
  group('the one recommendation', () {
    test('everything on path holds the plan', () {
      expect(_review().recommendation,
          const ReviewRecommendation.hold(ReviewReason.onPath));
    });

    test('weight above the path with food on target eats a little less', () {
      final r = _review(scale: _scale(change: -0.1)).recommendation;
      expect(r.kind, RecommendationKind.adjustCalories);
      expect(r.calorieDelta, -100);
      expect(r.reason, ReviewReason.weightAbovePath);
    });

    test('a bigger gap earns the bigger step, never more than 150', () {
      final r = _review(scale: _scale(change: 0.4)).recommendation;
      expect(r.calorieDelta, -150);
      final up = _review(scale: _scale(change: -1.6)).recommendation;
      expect(up.calorieDelta, 150);
      expect(up.reason, ReviewReason.weightBelowPath);
    });

    test('weight below the path eats a little more', () {
      final r = _review(scale: _scale(change: -0.9)).recommendation;
      expect(r.calorieDelta, 100);
      expect(r.reason, ReviewReason.weightBelowPath);
    });

    test('a gap inside the scale noise changes nothing', () {
      for (final change in [-0.25, -0.5, -0.74, -0.26]) {
        expect(_review(scale: _scale(change: change)).recommendation.kind,
            RecommendationKind.hold,
            reason: '$change');
      }
    });

    test('every suggested step is 100 or 150 kcal, whatever the gap', () {
      for (var tenths = -30; tenths <= 30; tenths++) {
        final r = _review(scale: _scale(change: tenths / 10)).recommendation;
        if (r.kind == RecommendationKind.adjustCalories) {
          expect([100, 150], contains(r.calorieDelta.abs()),
              reason: '${tenths / 10}');
        }
      }
    });

    test('eating less never goes under the resting energy estimate', () {
      final r = _review(
        food: _food(target: 2000, average: 2000, floor: 1950),
        scale: _scale(change: 0.2),
      ).recommendation;
      expect(r, const ReviewRecommendation.hold(ReviewReason.atFloor));
    });

    test('eating more is not blocked by the floor', () {
      final r = _review(
        food: _food(target: 2000, average: 2000, floor: 5000),
        scale: _scale(change: -1.6),
      ).recommendation;
      expect(r.calorieDelta, 150);
    });
  });

  group('holds when the evidence is thin', () {
    test('no calorie target', () {
      expect(_review(food: _food(target: null)).recommendation.reason,
          ReviewReason.noTarget);
    });

    test('too few logged days', () {
      final r = _review(
        food: _food(logged: WeeklyReviewCalculator.minLoggedDays - 1),
        scale: _scale(change: 1),
      ).recommendation;
      expect(r, const ReviewRecommendation.hold(ReviewReason.needMoreLogs));
    });

    test('intake far from the target means the target was not tested', () {
      for (final average in [1900, 3000]) {
        expect(
          _review(
            food: _food(average: average),
            scale: _scale(change: 1),
          ).recommendation,
          const ReviewRecommendation.hold(ReviewReason.intakeOffTarget),
          reason: '$average',
        );
      }
    });

    test('no weight path, or too few weigh-ins', () {
      expect(_review(scale: _scale(expected: null)).recommendation.reason,
          ReviewReason.noWeightPath);
      expect(_review(scale: _scale(change: null)).recommendation.reason,
          ReviewReason.noWeightPath);
      expect(
          _review(scale: _scale(change: 1, n: 1)).recommendation.reason,
          ReviewReason.noWeightPath);
    });
  });

  group('training', () {
    test('a missed session that can move to today is the recommendation', () {
      final r = _review(
        training: _training(
            planned: 4, completed: 2, missed: 2, movable: '2026-10-21.skill'),
        scale: _scale(change: 1),
      ).recommendation;
      expect(r.kind, RecommendationKind.moveSession);
      expect(r.sessionId, '2026-10-21.skill');
    });

    test('nothing to move once the week met its target', () {
      final r = _review(
        training: _training(
            planned: 5,
            completed: 4,
            target: 4,
            missed: 1,
            movable: '2026-10-21.skill'),
      ).recommendation;
      expect(r.kind, isNot(RecommendationKind.moveSession));
    });

    test('a week below target with nothing movable falls to nutrition', () {
      final r = _review(
        training: _training(planned: 4, completed: 2, missed: 2),
      ).recommendation;
      expect(r.reason, ReviewReason.onPath);
    });

    test('a rest-only week is met and never recommends a move', () {
      final t = _training(planned: 0, completed: 0, movable: 'x');
      expect(t.targetMet, isTrue);
      expect(_review(training: t).recommendation.kind,
          isNot(RecommendationKind.moveSession));
    });
  });

  test('is deterministic', () {
    final a = _review(scale: _scale(change: 0.3)).recommendation;
    final b = _review(scale: _scale(change: 0.3)).recommendation;
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });

  test('the intake ratio is over logged days only', () {
    expect(_food(average: 2250).intakeRatio, closeTo(0.9, 1e-9));
    expect(_food(average: null).intakeRatio, isNull);
    expect(_food(target: null).intakeRatio, isNull);
  });
}
