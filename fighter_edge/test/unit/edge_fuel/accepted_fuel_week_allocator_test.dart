import 'dart:math';

import 'package:fighter_edge/features/edge_fuel/domain/calculators/accepted_fuel_week_allocator.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_day_planner.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/fuel_week_allocation.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/accepted_fuel_week.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/fuel_day_plan.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';
import 'package:flutter_test/flutter_test.dart';

final _monday = DateTime(2026, 10, 19);

NutritionTarget _target({int kcal = 3000, int carbs = 420}) => NutritionTarget(
      status: NutritionTargetStatus.success,
      policyVersion: 1,
      calculatedAt: _monday,
      targetCalories: kcal,
      proteinGrams: 150,
      fatGrams: 80,
      carbGrams: carbs,
      estimatedRmrKcal: 1600,
    );

FuelDatedSession _session(int day, FuelIntensity intensity, int minutes) =>
    FuelDatedSession(
        date: DateTime(2026, 10, 19 + day),
        discipline: FuelDiscipline.boxing,
        intensity: intensity,
        durationMinutes: minutes);

List<FuelDayPlan> _week({FuelFightWindow? fight}) => FuelDayPlanner.planWeek(
      start: _monday,
      fight: fight,
      plan: [
        _session(0, FuelIntensity.hard, 60),
        _session(1, FuelIntensity.light, 30),
        _session(2, FuelIntensity.moderate, 45),
        _session(2, FuelIntensity.hard, 45),
      ],
    );

AcceptedFuelWeek _allocate(
        {NutritionTarget? target,
        List<FuelDayPlan>? days,
        int? age = 30,
        double? weight = 70,
        bool enabled = true}) =>
    AcceptedFuelWeekAllocator.allocate(
        acceptedTarget: target ?? _target(),
        days: days ?? _week(),
        ageYears: age,
        weightKg: weight,
        amountsEnabled: enabled);

void main() {
  test('default review gate and adult gate expose no numeric targets', () {
    final pending = AcceptedFuelWeekAllocator.allocate(
        acceptedTarget: _target(), days: _week(), ageYears: 30, weightKg: 70);
    expect(pending.status, AcceptedFuelWeekStatus.awaitingSignOff);
    expect(pending.days, isEmpty);
    for (final age in [null, 0, 17]) {
      for (final enabled in [false, true]) {
        final result = _allocate(age: age, enabled: enabled);
        expect(result.status, AcceptedFuelWeekStatus.adultRequired);
        expect(result.days, isEmpty);
      }
    }
  });

  test('allocates rest/easy/hard/double without replacing accepted anchors',
      () {
    final target = _target();
    final before = target.toJson();
    final result = _allocate(target: target);
    expect(result.status, AcceptedFuelWeekStatus.ready);
    expect(
        result.days.map((d) => d.plan.type).toSet(),
        containsAll([
          FuelDayType.rest,
          FuelDayType.easy,
          FuelDayType.hard,
          FuelDayType.doubleDay
        ]));
    expect(result.shiftApplied, isTrue);
    expect(result.days[2].calories, greaterThan(result.days[6].calories));
    expect(result.days.fold(0, (sum, d) => sum + d.calories), 3000 * 7);
    expect(result.days.fold(0, (sum, d) => sum + d.carbGrams), 420 * 7);
    for (final day in result.days) {
      expect(day.proteinGrams, 150);
      expect(day.fatGrams, 80);
      expect((day.macroDerivedCalories - day.calories).abs(),
          lessThanOrEqualTo(20));
    }
    expect(target.toJson(), before);
    expect(() => result.days.clear(), throwsUnsupportedError);
  });

  test('fight-week targets stay withheld even in an enabled build', () {
    final result = _allocate(
        days: _week(
            fight: FuelFightWindow(
                weighInDate: DateTime(2026, 10, 24),
                fightDate: DateTime(2026, 10, 25))));
    expect(result.status, AcceptedFuelWeekStatus.fightWeek);
    expect(result.days, isEmpty);
  });

  test('insufficient accepted budget is refused, never increased', () {
    final target = _target(kcal: 1700, carbs: 95);
    final before = target.toJson();
    final result = _allocate(target: target);
    expect(result.status, AcceptedFuelWeekStatus.incompatibleTarget);
    expect(result.days, isEmpty);
    expect(target.toJson(), before);
  });

  test('non-ten kcal anchor falls back exactly to accepted values', () {
    final result = _allocate(target: _target(kcal: 3001));
    expect(result.isReady, isTrue);
    expect(result.shiftApplied, isFalse);
    expect(result.days.every((d) => d.calories == 3001 && d.carbGrams == 420),
        isTrue);
  });

  test('rejects missing data, malformed calendar weeks and invalid energy', () {
    for (final weight in [null, 0.0, -1.0, double.nan, double.infinity]) {
      expect(_allocate(weight: weight).status,
          AcceptedFuelWeekStatus.needsMoreData);
    }
    expect(_allocate(age: 121).status, AcceptedFuelWeekStatus.needsMoreData);
    final days = _week();
    for (final invalid in [
      <FuelDayPlan>[],
      days.reversed.toList(),
      [days.first, ...days.take(6)]
    ]) {
      expect(_allocate(days: invalid).status,
          AcceptedFuelWeekStatus.needsMoreData);
    }
    final invalidEnergy = [
      FuelDayPlan(
          date: days.first.date,
          type: FuelDayType.hard,
          load: FuelDayType.hard,
          carbTier: CarbTier.heavy,
          sessions: const [],
          sessionKcalPerKg: double.nan),
      ...days.skip(1)
    ];
    expect(_allocate(days: invalidEnergy).status,
        AcceptedFuelWeekStatus.needsMoreData);
    final missing = NutritionTarget(
        status: NutritionTargetStatus.success,
        policyVersion: 1,
        calculatedAt: _monday);
    expect(_allocate(target: missing).status,
        AcceptedFuelWeekStatus.needsMoreData);
    expect(
        AcceptedFuelWeekAllocator.allocate(
                acceptedTarget: null,
                days: days,
                ageYears: 30,
                weightKg: 70,
                amountsEnabled: true)
            .days,
        isEmpty);
  });

  test('seeded varied weeks conserve every accepted weekly budget and floor',
      () {
    final random = Random(824);
    for (var run = 0; run < 200; run++) {
      final weight = 55.0 + random.nextInt(30);
      final kcal = 2800 + random.nextInt(20) * 40;
      final carbs = (kcal - 1320) ~/ 4;
      final days = FuelDayPlanner.planWeek(start: _monday, plan: [
        for (var day = 0; day < 7; day++)
          for (var s = 0; s < random.nextInt(3); s++)
            _session(day, FuelIntensity.values[random.nextInt(3)],
                20 + random.nextInt(100)),
      ]);
      final result = _allocate(
          target: _target(kcal: kcal, carbs: carbs),
          days: days,
          weight: weight);
      expect(result.isReady, isTrue, reason: 'case $run');
      expect(result.days.fold(0, (sum, d) => sum + d.calories), kcal * 7);
      expect(result.days.fold(0, (sum, d) => sum + d.carbGrams), carbs * 7);
      for (final day in result.days) {
        final g = FuelDayPlanner.guidance(day.plan,
            weightKg: weight, adultConfirmed: true, amountsEnabled: true)!;
        expect(day.carbGrams, greaterThanOrEqualTo(g.carbFloorGrams));
        expect(day.calories, greaterThanOrEqualTo(1600));
        expect((day.macroDerivedCalories - day.calories).abs(),
            lessThanOrEqualTo(20));
      }
    }
  });

  test('shared allocator validates inputs and keeps rounding immutable', () {
    List<int>? split(
            {List<double> d = const [30, -5, -5, -5, -5, -5, -5],
            List<int> floors = const [0, 0, 0, 0, 0, 0, 0],
            double shift = 0.5,
            int average = 3000,
            int quantum = 10}) =>
        FuelWeekAllocation.split(
            average: average,
            deviations: d,
            shift: shift,
            minimums: floors,
            quantum: quantum);
    final result = split()!;
    expect(result.reduce((a, b) => a + b), 21000);
    expect(split(), result);
    expect(() => result[0] = 0, throwsUnsupportedError);
    expect(split(d: const []), isNull);
    expect(split(d: [double.nan, 0, 0, 0, 0, 0, 0]), isNull);
    expect(split(floors: const []), isNull);
    expect(split(floors: const [-1, 0, 0, 0, 0, 0, 0]), isNull);
    expect(split(shift: double.infinity), isNull);
    expect(split(shift: -1), isNull);
    expect(split(quantum: 0), isNull);
    expect(split(average: 3001), isNull);
    expect(split(floors: List.filled(7, 4000)), isNull);
  });
}
