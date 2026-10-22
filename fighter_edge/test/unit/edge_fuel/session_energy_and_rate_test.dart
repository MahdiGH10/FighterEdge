import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/nutrition_policy_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/session_energy_table.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/weight_rate_policy.dart';

PlannedFuelSession _s(
  FuelDiscipline d,
  FuelIntensity i,
  int minutes, {
  int day = 0,
}) =>
    PlannedFuelSession(
      dayIndex: day,
      discipline: d,
      intensity: i,
      durationMinutes: minutes,
    );

void main() {
  group('versions', () {
    test('current policy is v2 and v1 is kept as its own constant', () {
      expect(NutritionPolicy.version, 2);
      expect(NutritionPolicy.v1, 1);
      expect(NutritionPolicyV2.version, NutritionPolicy.version);
    });

    test('the session energy table is flagged as awaiting sign-off', () {
      expect(SessionEnergyTable.dietitianSignOffPending, isTrue);
    });
  });

  group('SessionEnergyTable', () {
    test('every discipline rises with intensity', () {
      for (final d in FuelDiscipline.values) {
        final light = SessionEnergyTable.grossMet(d, FuelIntensity.light);
        final moderate = SessionEnergyTable.grossMet(d, FuelIntensity.moderate);
        final hard = SessionEnergyTable.grossMet(d, FuelIntensity.hard);
        expect(light, lessThan(moderate), reason: d.name);
        expect(moderate, lessThan(hard), reason: d.name);
      }
    });

    test('values are conservative against the Compendium', () {
      // Compendium: boxing sparring 12.8, kickboxing 10.3, wrestling 6.0.
      expect(
        SessionEnergyTable.grossMet(FuelDiscipline.boxing, FuelIntensity.hard),
        lessThan(12.8),
      );
      expect(
        SessionEnergyTable.grossMet(
            FuelDiscipline.kickboxing, FuelIntensity.hard),
        lessThan(10.3),
      );
      for (final d in FuelDiscipline.values) {
        for (final i in FuelIntensity.values) {
          expect(SessionEnergyTable.grossMet(d, i), lessThanOrEqualTo(10.3));
          expect(SessionEnergyTable.netMet(d, i),
              SessionEnergyTable.grossMet(d, i) - 1);
        }
      }
    });

    test('a known session: 60 min moderate boxing at 80 kg', () {
      // (7.0 - 1) * 80 * 1.0 h
      expect(
        SessionEnergyTable.sessionKcal(
            _s(FuelDiscipline.boxing, FuelIntensity.moderate, 60), 80),
        closeTo(480, 1e-9),
      );
    });

    test('energy scales linearly with body weight', () {
      final s = _s(FuelDiscipline.bjj, FuelIntensity.hard, 75);
      expect(
        SessionEnergyTable.sessionKcal(s, 100),
        closeTo(SessionEnergyTable.sessionKcal(s, 50) * 2, 1e-9),
      );
    });

    test('duration: linear to 90 min, tapered after, capped at 240', () {
      expect(SessionEnergyTable.effectiveHours(60), closeTo(1.0, 1e-12));
      expect(SessionEnergyTable.effectiveHours(90), closeTo(1.5, 1e-12));
      // 90 + 30 * 0.8 = 114 min.
      expect(SessionEnergyTable.effectiveHours(120), closeTo(114 / 60, 1e-12));
      expect(SessionEnergyTable.effectiveHours(240),
          SessionEnergyTable.effectiveHours(10000));
      expect(SessionEnergyTable.effectiveHours(0), 0);
      expect(SessionEnergyTable.effectiveHours(-30), 0);
    });

    test('duration never makes energy fall', () {
      var last = -1.0;
      for (var m = 0; m <= 300; m += 5) {
        final kcal = SessionEnergyTable.sessionKcal(
            _s(FuelDiscipline.mma, FuelIntensity.moderate, m), 75);
        expect(kcal, greaterThanOrEqualTo(last));
        last = kcal;
      }
    });

    test('a bad weight costs nothing', () {
      final s = _s(FuelDiscipline.boxing, FuelIntensity.hard, 60);
      expect(SessionEnergyTable.sessionKcal(s, 0), 0);
      expect(SessionEnergyTable.sessionKcal(s, -5), 0);
      expect(SessionEnergyTable.sessionKcal(s, double.nan), 0);
      expect(SessionEnergyTable.sessionKcal(s, double.infinity), 0);
    });

    test('day index validity', () {
      expect(
          _s(FuelDiscipline.boxing, FuelIntensity.light, 30, day: 6)
              .hasValidDay,
          isTrue);
      expect(
          _s(FuelDiscipline.boxing, FuelIntensity.light, 30, day: 7)
              .hasValidDay,
          isFalse);
      expect(
          _s(FuelDiscipline.boxing, FuelIntensity.light, 30, day: -1)
              .hasValidDay,
          isFalse);
    });
  });

  group('WeightRatePolicy', () {
    test('7,700 kcal per kg: 0.5% of 80 kg is about 440 kcal a day', () {
      expect(WeightRatePolicy.dailyKcalFor(0.5, 80), closeTo(440, 1e-9));
    });

    test('outside a camp loss is capped at 0.75% a week', () {
      expect(WeightRatePolicy.maxPercentFor(NutritionGoal.loseFat, 80), 0.75);
      expect(WeightRatePolicy.maxPercentFor(NutritionGoal.loseFat, 125), 0.75);
      // 1 kg is still the tighter cap for a very heavy athlete.
      expect(
        WeightRatePolicy.maxPercentFor(NutritionGoal.loseFat, 150),
        closeTo(1 / 1.5, 1e-12),
      );
      expect(WeightRatePolicy.maxPercentFor(NutritionGoal.loseFat, 0), 0);
      expect(WeightRatePolicy.lossOptionsPercent, isNot(contains(1.0)));
    });

    test('in a fight camp loss is capped at 1% and 1 kg, whichever is tighter',
        () {
      double camp(double kg) => WeightRatePolicy.maxPercentFor(
          NutritionGoal.loseFat, kg,
          inFightCamp: true);
      expect(camp(80), 1.0);
      expect(camp(100), 1.0);
      expect(camp(125), closeTo(0.8, 1e-12));
      expect(camp(0), 0);
    });

    test('gain is capped at 0.5%, maintenance at 0', () {
      expect(WeightRatePolicy.maxPercentFor(NutritionGoal.gainMuscle, 70), 0.5);
      expect(WeightRatePolicy.maxPercentFor(NutritionGoal.maintain, 70), 0);
    });

    test('a too-large request is clamped and flagged', () {
      final r = WeightRatePolicy.apply(
        goal: NutritionGoal.loseFat,
        weightKg: 80,
        requestedPercent: 2.5,
      );
      expect(r.percentPerWeek, 0.75);
      expect(r.wasClamped, isTrue);
      final camp = WeightRatePolicy.apply(
        goal: NutritionGoal.loseFat,
        weightKg: 80,
        requestedPercent: 2.5,
        inFightCamp: true,
      );
      expect(camp.percentPerWeek, 1.0);
      expect(camp.wasClamped, isTrue);
      final heavy = WeightRatePolicy.apply(
        goal: NutritionGoal.loseFat,
        weightKg: 125,
        requestedPercent: 1.0,
        inFightCamp: true,
      );
      expect(heavy.percentPerWeek, closeTo(0.8, 1e-12));
      expect(heavy.wasClamped, isTrue);
    });

    test('an in-range request passes through unflagged', () {
      for (final p in WeightRatePolicy.lossOptionsPercent) {
        final r = WeightRatePolicy.apply(
            goal: NutritionGoal.loseFat, weightKg: 80, requestedPercent: p);
        expect(r.percentPerWeek, p);
        expect(r.wasClamped, isFalse);
      }
      for (final p in WeightRatePolicy.gainOptionsPercent) {
        final r = WeightRatePolicy.apply(
            goal: NutritionGoal.gainMuscle, weightKg: 70, requestedPercent: p);
        expect(r.percentPerWeek, p);
        expect(r.wasClamped, isFalse);
      }
    });

    test('unusable requests fall back to the goal default', () {
      for (final bad in <double?>[null, -1, double.nan, double.infinity]) {
        final r = WeightRatePolicy.apply(
            goal: NutritionGoal.loseFat, weightKg: 80, requestedPercent: bad);
        expect(r.percentPerWeek, WeightRatePolicy.lossDefaultPercent);
        expect(r.wasClamped, isTrue);
      }
      final gain =
          WeightRatePolicy.apply(goal: NutritionGoal.gainMuscle, weightKg: 70);
      expect(gain.percentPerWeek, WeightRatePolicy.gainDefaultPercent);
    });

    test('maintenance is always zero', () {
      final r = WeightRatePolicy.apply(
          goal: NutritionGoal.maintain, weightKg: 80, requestedPercent: 0.7);
      expect(r.percentPerWeek, 0);
      expect(r.wasClamped, isFalse);
    });

    test('every existing pace maps to a rate and mismatches map to null', () {
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.gentle, NutritionGoal.loseFat),
          0.25);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.standard, NutritionGoal.loseFat),
          0.5);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.upperLimit, NutritionGoal.loseFat),
          0.75);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.conservative, NutritionGoal.gainMuscle),
          0.1);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.gainStandard, NutritionGoal.gainMuscle),
          0.25);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.gentle, NutritionGoal.gainMuscle),
          isNull);
      expect(
          WeightRatePolicy.percentForPace(
              GoalPace.gainStandard, NutritionGoal.loseFat),
          isNull);
      expect(
          WeightRatePolicy.percentForPace(null, NutritionGoal.loseFat), isNull);
      expect(WeightRatePolicy.percentForPace(null, NutritionGoal.maintain), 0);
    });

    test('no pace the app offers exceeds the safe cap', () {
      for (final pace in GoalPace.values) {
        for (final goal in [NutritionGoal.loseFat, NutritionGoal.gainMuscle]) {
          final p = WeightRatePolicy.percentForPace(pace, goal);
          if (p == null) continue;
          expect(
              p, lessThanOrEqualTo(WeightRatePolicy.maxPercentFor(goal, 90)));
        }
      }
    });
  });
}
