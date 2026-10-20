import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/weekly_review/domain/review_window.dart';
import 'package:fighter_edge/features/weekly_review/domain/target_adjustment.dart';

NutritionTarget _target({
  NutritionTargetStatus status = NutritionTargetStatus.success,
  int? kcal = 2500,
  int? carbs = 280,
}) =>
    NutritionTarget(
      status: status,
      policyVersion: 1,
      calculatedAt: DateTime(2026, 9, 1),
      estimatedRmrKcal: 1800,
      targetCalories: kcal,
      proteinGrams: 160,
      fatGrams: 80,
      carbGrams: carbs,
      appliedGoalAdjustmentPercent: -10,
    );

void main() {
  final now = DateTime(2026, 10, 25, 20);

  group('TargetAdjustment', () {
    test('moves calories and lets carbohydrate absorb the difference', () {
      final t = TargetAdjustment.apply(_target(), -100, now: now)!;
      expect(t.targetCalories, 2400);
      expect(t.carbGrams, 255);
      expect(t.proteinGrams, 160);
      expect(t.fatGrams, 80);
      expect(t.policyVersion, 1, reason: 'the policy itself is not changed');
      expect(t.calculatedAt, now);
      expect(t.estimatedRmrKcal, 1800);
    });

    test('macros still reconcile with the calories after a step', () {
      final before = _target(kcal: 160 * 4 + 280 * 4 + 80 * 9);
      for (final delta in [-150, -100, 100, 150]) {
        final t = TargetAdjustment.apply(before, delta, now: now)!;
        expect((t.macroDerivedCalories! - t.targetCalories!).abs(),
            lessThanOrEqualTo(2),
            reason: '$delta');
      }
    });

    test('never touches a target that is not a success', () {
      expect(
        TargetAdjustment.apply(
            _target(status: NutritionTargetStatus.needsProfessionalReview),
            -100,
            now: now),
        isNull,
      );
      expect(
          TargetAdjustment.apply(_target(kcal: null), 100, now: now), isNull);
      expect(
          TargetAdjustment.apply(_target(carbs: null), 100, now: now), isNull);
    });

    test('refuses a step that would empty the carbohydrate', () {
      expect(
          TargetAdjustment.apply(_target(carbs: 10), -150, now: now), isNull);
    });
  });

  group('ReviewWindow', () {
    test('Sunday reviews the week that is ending', () {
      expect(ReviewWindow.weekFor(DateTime(2026, 10, 25, 9)),
          DateTime.utc(2026, 10, 19));
    });

    test('Monday still offers the week that just ended', () {
      expect(ReviewWindow.weekFor(DateTime(2026, 10, 26, 9)),
          DateTime.utc(2026, 10, 19));
    });

    test('no other day offers a review', () {
      for (var day = 20; day <= 24; day++) {
        expect(ReviewWindow.weekFor(DateTime(2026, 10, day)), isNull,
            reason: 'Oct $day');
      }
    });
  });
}
