import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/adaptive/calendar_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/data_tier.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/fuel_log_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/safety_reask.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/weigh_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/weight_slope.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/policies/energy_availability_proxy.dart';

final _today = CalendarDay(2026, 10, 22);

/// One standard weigh-in a day for [days] days ending on [end], on a straight
/// line of [kgPerWeek], with an optional alternating wobble.
List<WeighIn> _line({
  required CalendarDay end,
  int days = 21,
  double startKg = 80,
  double kgPerWeek = -0.4,
  double wobble = 0,
}) =>
    [
      for (var d = 0; d < days; d++)
        WeighIn(
          day: end.plusDays(d - days + 1),
          kg: startKg + kgPerWeek / 7 * d + (d.isEven ? wobble : -wobble),
        ),
    ];

List<FuelLogDay> _logs({
  required CalendarDay end,
  int days = 21,
  double kcal = 2200,
  LoggingCompleteness completeness = LoggingCompleteness.complete,
  Set<int> skip = const {},
  Set<int> partial = const {},
}) =>
    [
      for (var d = 0; d < days; d++)
        if (!skip.contains(d))
          FuelLogDay(
            day: end.plusDays(-d),
            intakeKcal: kcal,
            completeness: partial.contains(d)
                ? LoggingCompleteness.partial
                : completeness,
          ),
    ];

void main() {
  group('CalendarDay', () {
    test('counts whole days, even across a daylight-saving change', () {
      final a = CalendarDay(2026, 3, 28);
      final b = CalendarDay(2026, 3, 30);
      expect(a.daysUntil(b), 2);
      expect(b.daysUntil(a), -2);
      expect(a.plusDays(2), b);
      expect(CalendarDay(2026, 10, 24).daysUntil(CalendarDay(2026, 10, 26)), 2);
    });

    test('ignores the time and zone of a DateTime', () {
      expect(
        CalendarDay.fromDateTime(DateTime(2026, 10, 22, 23, 59)),
        CalendarDay(2026, 10, 22),
      );
      expect(
        CalendarDay.fromDateTime(DateTime.utc(2026, 10, 22, 0, 1)),
        CalendarDay(2026, 10, 22),
      );
    });

    test('orders, compares and prints as ISO dates', () {
      final a = CalendarDay(2026, 1, 5);
      final b = CalendarDay(2026, 1, 6);
      expect(a.isBefore(b), isTrue);
      expect(b.isAfter(a), isTrue);
      expect(a.compareTo(b), lessThan(0));
      expect(a.isWithin(a, b), isTrue);
      expect(b.plusDays(1).isWithin(a, b), isFalse);
      expect(a == CalendarDay.fromEpochDay(a.epochDay), isTrue);
      expect(a.hashCode, CalendarDay.fromEpochDay(a.epochDay).hashCode);
      expect(a.toString(), '2026-01-05');
      expect(CalendarDay.fromEpochDay(0).toString(), '1970-01-01');
    });
  });

  group('WeighIn', () {
    test('only valid, standard, non-fight-week readings are usable', () {
      final day = _today;
      expect(WeighIn(day: day, kg: 80).isUsable, isTrue);
      expect(
        WeighIn(day: day, kg: 80, condition: WeighInCondition.morning).isUsable,
        isTrue,
      );
      expect(
        WeighIn(day: day, kg: 80, condition: WeighInCondition.afterTraining)
            .isUsable,
        isFalse,
      );
      expect(
        WeighIn(day: day, kg: 80, condition: WeighInCondition.other).isUsable,
        isFalse,
      );
      expect(WeighIn(day: day, kg: 80, inFightWeek: true).isUsable, isFalse);
      expect(WeighIn(day: day, kg: 19.9).isValid, isFalse);
      expect(WeighIn(day: day, kg: 250.1).isValid, isFalse);
      expect(WeighIn(day: day, kg: double.nan).isValid, isFalse);
    });
  });

  group('FuelLogDay', () {
    test('a partial day is never data, however much it holds', () {
      final d = FuelLogDay(
        day: _today,
        intakeKcal: 3000,
        completeness: LoggingCompleteness.partial,
      );
      expect(d.countsAsData(2000), isFalse);
      expect(d.isPartial, isTrue);
    });

    test('a complete day counts whenever something was logged', () {
      final d = FuelLogDay(
        day: _today,
        intakeKcal: 400,
        completeness: LoggingCompleteness.complete,
      );
      expect(d.countsAsData(2000), isTrue);
      expect(
          FuelLogDay(day: _today, completeness: LoggingCompleteness.complete)
              .countsAsData(2000),
          isFalse);
    });

    test('an unmarked day needs half the target: one snack is not a day', () {
      expect(
          FuelLogDay(day: _today, intakeKcal: 999).countsAsData(2000), isFalse);
      expect(
          FuelLogDay(day: _today, intakeKcal: 1000).countsAsData(2000), isTrue);
      expect(
          FuelLogDay(day: _today, intakeKcal: 1000).countsAsData(0), isFalse);
      expect(
        FuelLogDay(day: _today, intakeKcal: double.infinity).hasEntries,
        isFalse,
      );
    });

    test('LoggingSummary counts a window and lets the last record win', () {
      final logs = [
        ..._logs(end: _today, days: 7),
        // A later record for today replaces the first.
        FuelLogDay(
          day: _today,
          intakeKcal: 2000,
          completeness: LoggingCompleteness.partial,
        ),
        // Outside the window.
        FuelLogDay(day: _today.plusDays(-7), intakeKcal: 100),
      ];
      final w = LoggingSummary.window(logs, endDay: _today, targetKcal: 2200);
      expect(w.daysCounted, 6);
      expect(w.partialDays, 1);
      expect(w.daysWithEntries, 7);
      expect(w.averageIntakeKcal, 2200);
      final empty =
          LoggingSummary.window(const [], endDay: _today, targetKcal: 2200);
      expect(empty.averageIntakeKcal, isNull);
      const none = LogWindow.empty();
      expect(none.daysCounted, 0);
      expect(none.averageIntakeKcal, isNull);
    });
  });

  group('SafetyReask', () {
    final answered = CalendarDay(2026, 8, 1);

    test('due when never answered', () {
      expect(SafetyReask.isDue(lastAnsweredOn: null, today: _today), isTrue);
    });

    test('due again 8 weeks after the last answer, not a day before', () {
      final due = SafetyReask.nextDue(answered);
      expect(answered.daysUntil(due), 56);
      expect(
        SafetyReask.isDue(lastAnsweredOn: answered, today: due.plusDays(-1)),
        isFalse,
      );
      expect(SafetyReask.isDue(lastAnsweredOn: answered, today: due), isTrue);
    });

    test('due when a loss goal starts after the last answer', () {
      expect(
        SafetyReask.isDue(
          lastAnsweredOn: answered,
          today: answered.plusDays(3),
          lossGoalStartedOn: answered.plusDays(2),
        ),
        isTrue,
      );
      expect(
        SafetyReask.isDue(
          lastAnsweredOn: answered,
          today: answered.plusDays(3),
          lossGoalStartedOn: answered.plusDays(-2),
        ),
        isFalse,
      );
    });
  });

  group('EnergyAvailabilityProxy', () {
    test('resting energy plus half the session energy, rounded up to ten', () {
      expect(
        EnergyAvailabilityProxy.floorKcal(
          restingEnergyKcal: 1345,
          averageSessionKcalPerDay: 257,
        ),
        1480, // 1345 + 128.5 = 1473.5 -> 1480
      );
      expect(EnergyAvailabilityProxy.dietitianSignOffPending, isTrue);
    });

    test('no or broken session energy means resting energy only', () {
      for (final s in [0.0, -50.0, double.nan]) {
        expect(
          EnergyAvailabilityProxy.floorKcal(
            restingEnergyKcal: 1500,
            averageSessionKcalPerDay: s,
          ),
          1500,
        );
      }
      expect(
        EnergyAvailabilityProxy.floorKcal(
          restingEnergyKcal: double.nan,
          averageSessionKcalPerDay: 200,
        ),
        0,
      );
    });
  });

  group('WeightSlopeCalculator', () {
    test('a clean line gives its exact slope and no noise', () {
      final s = WeightSlopeCalculator.compute(
        _line(end: _today, kgPerWeek: -0.5),
        today: _today,
      );
      expect(s.status, WeightSlopeStatus.ok);
      expect(s.isUsable, isTrue);
      expect(s.slopeKgPerWeek, closeTo(-0.5, 1e-9));
      expect(s.residualSdKg, closeTo(0, 1e-9));
      expect(s.noiseBandKgPerWeek, closeTo(0, 1e-9));
      expect(s.pointsUsed, 21);
      expect(s.spanDays, 20);
      expect(s.windowDays, 21);
    });

    test('day-to-day wobble widens the noise band, not the slope', () {
      final s = WeightSlopeCalculator.compute(
        _line(end: _today, kgPerWeek: -0.5, wobble: 0.4),
        today: _today,
      );
      expect(s.slopeKgPerWeek, closeTo(-0.5, 0.1));
      expect(s.residualSdKg, greaterThan(0.3));
      expect(s.noiseBandKgPerWeek, greaterThan(0.1));
    });

    test('an outlier is dropped and reported; the line ignores it', () {
      final readings = _line(end: _today, kgPerWeek: 0);
      final spike = _today.plusDays(-10);
      readings.add(WeighIn(day: spike, kg: 80));
      // Same-day readings average: (80 + 80 + 87) / 3, about 2.3 kg off,
      // beyond max(1.5 kg, 2% of 80 kg).
      readings.add(WeighIn(day: spike, kg: 87));
      final s = WeightSlopeCalculator.compute(readings, today: _today);
      expect(s.outlierDays, [spike]);
      expect(s.pointsUsed, 20);
      expect(s.slopeKgPerWeek, closeTo(0, 1e-9));
    });

    test('a small swing inside 2% of body weight is not an outlier', () {
      final readings = [
        for (var d = 0; d < 21; d++)
          WeighIn(day: _today.plusDays(-d), kg: d == 5 ? 101.9 : 100),
      ];
      final s = WeightSlopeCalculator.compute(readings, today: _today);
      expect(s.outlierDays, isEmpty);
      expect(s.pointsUsed, 21);
    });

    test('a day without two neighbours cannot be judged and stays', () {
      final readings = [
        // Isolated far-off reading, then a tight run.
        WeighIn(day: _today.plusDays(-20), kg: 90),
        for (var d = 0; d < 12; d++) WeighIn(day: _today.plusDays(-d), kg: 80),
      ];
      final s = WeightSlopeCalculator.compute(readings, today: _today);
      expect(s.outlierDays, isEmpty);
      expect(s.pointsUsed, 13);
    });

    test('non-standard, invalid, fight-week and future readings stay out', () {
      final readings = [
        ..._line(end: _today, kgPerWeek: -0.3),
        WeighIn(
          day: _today,
          kg: 78,
          condition: WeighInCondition.afterTraining,
        ),
        WeighIn(day: _today.plusDays(-1), kg: 500),
        WeighIn(day: _today.plusDays(-2), kg: 75, inFightWeek: true),
        WeighIn(day: _today.plusDays(1), kg: 70),
        // Before the window: not counted as excluded.
        WeighIn(day: _today.plusDays(-40), kg: 500),
      ];
      final s = WeightSlopeCalculator.compute(readings, today: _today);
      expect(s.excludedNonStandard, 1);
      expect(s.excludedInvalid, 1);
      expect(s.excludedFightWeek, 1);
      expect(s.pointsUsed, 21);
      expect(s.slopeKgPerWeek, closeTo(-0.3, 1e-9));
    });

    test('too few points, or too short a span, is not usable', () {
      final eight = [
        for (var d = 0; d < 8; d++)
          WeighIn(day: _today.plusDays(-2 * d), kg: 80),
      ];
      final few = WeightSlopeCalculator.compute(eight, today: _today);
      expect(few.status, WeightSlopeStatus.insufficientPoints);
      expect(few.slopeKgPerWeek, isNull);
      expect(few.isUsable, isFalse);

      final bunched = [
        for (var d = 0; d < 10; d++) WeighIn(day: _today.plusDays(-d), kg: 80),
      ];
      final short = WeightSlopeCalculator.compute(bunched, today: _today);
      expect(short.status, WeightSlopeStatus.insufficientSpan);
      expect(short.spanDays, 9);
    });

    test('best() falls back to 14 days, and reports the 21-day miss', () {
      // 3 a week for two weeks: Tier 1's minimum.
      final six = [
        for (final d in [0, 2, 4, 7, 9, 11])
          WeighIn(day: _today.plusDays(-d), kg: 80 + d * 0.05),
      ];
      final best = WeightSlopeCalculator.best(six, today: _today);
      expect(best.isUsable, isTrue);
      expect(best.windowDays, WeightSlopeCalculator.fallbackWindowDays);

      final five = six.sublist(0, 5);
      final none = WeightSlopeCalculator.best(five, today: _today);
      expect(none.isUsable, isFalse);
      expect(none.windowDays, WeightSlopeCalculator.windowDays);
    });

    test('none() is an unusable empty slope', () {
      const s = WeightSlope.none();
      expect(s.isUsable, isFalse);
      expect(s.slopeKgPerWeek, isNull);
      expect(s.outlierDays, isEmpty);
    });
  });

  group('DataTierEvaluator', () {
    final asOf = _today.plusDays(-1);

    DataTierAssessment tierFor({
      int dataDays = 28,
      List<FuelLogDay>? logs,
      List<WeighIn>? weighIns,
    }) =>
        DataTierEvaluator.evaluate(
          asOf: asOf,
          targetStart: asOf.plusDays(-(dataDays - 1)),
          targetKcal: 2200,
          logDays: logs ?? _logs(end: asOf),
          weighIns: weighIns ?? _line(end: asOf),
        );

    test('under 14 days is Tier 0, formula only', () {
      final t = tierFor(dataDays: 13);
      expect(t.tier, DataTier.tier0);
      expect(t.mayPropose, isFalse);
      expect(t.reasons, [CheckInReason.programTooNew]);
      expect(t.dataDays, 13);
    });

    test('14 full days is Tier 1; Tier 2 waits for 21', () {
      final t = tierFor(dataDays: 14);
      expect(t.tier, DataTier.tier1);
      expect(t.mayPropose, isTrue);
      expect(t.reasons, [CheckInReason.programTooNew]);
    });

    test('21 full days is Tier 2', () {
      final t = tierFor(dataDays: 21);
      expect(t.tier, DataTier.tier2);
      expect(t.reasons, isEmpty);
      expect(t.weighInDaysIn21, 21);
      expect(t.weighInDaysThisWeek, 7);
      expect(t.weighInDaysLastWeek, 7);
      expect(t.thisWeek.daysCounted, 7);
    });

    test('4 of 7 days logged in either week drops to Tier 0', () {
      final thisWeek = tierFor(logs: _logs(end: asOf, skip: {0, 1, 2}));
      expect(thisWeek.tier, DataTier.tier0);
      expect(thisWeek.reasons, [CheckInReason.insufficientLogging]);
      final lastWeek = tierFor(logs: _logs(end: asOf, skip: {7, 8, 9}));
      expect(lastWeek.tier, DataTier.tier0);
    });

    test('5 of 7 in both weeks is enough for Tier 1', () {
      final t = tierFor(logs: _logs(end: asOf, skip: {0, 1, 7, 8}));
      expect(t.tier, DataTier.tier1);
      expect(t.reasons, [CheckInReason.insufficientLogging]);
    });

    test('2 weigh-ins in a week drops to Tier 0', () {
      final readings = [
        for (final w in _line(end: asOf))
          if (asOf.epochDay - w.day.epochDay > 6 ||
              asOf.epochDay - w.day.epochDay < 2)
            w,
      ];
      final t = tierFor(weighIns: readings);
      expect(t.tier, DataTier.tier0);
      expect(t.reasons, [CheckInReason.insufficientWeighIns]);
    });

    test('after-training readings do not count toward the weigh-in gate', () {
      final readings = [
        for (final w in _line(end: asOf))
          WeighIn(
            day: w.day,
            kg: w.kg,
            condition: asOf.epochDay - w.day.epochDay < 7
                ? WeighInCondition.afterTraining
                : WeighInCondition.morningFasted,
          ),
      ];
      expect(tierFor(weighIns: readings).weighInDaysThisWeek, 0);
    });

    test('a partial day, too few good weeks, or too few weigh-ins hold Tier 1',
        () {
      final partial = tierFor(logs: _logs(end: asOf, partial: {15}));
      expect(partial.tier, DataTier.tier1);
      expect(partial.reasons, [CheckInReason.partialLoggingFlagged]);

      final thin = tierFor(logs: _logs(end: asOf, skip: {0, 1, 7, 8}));
      expect(thin.reasons, contains(CheckInReason.insufficientLogging));

      final threeAWeek = [
        for (final w in _line(end: asOf))
          if ((asOf.epochDay - w.day.epochDay) % 7 < 3) w,
      ];
      final sparse = tierFor(weighIns: threeAWeek);
      expect(sparse.tier, DataTier.tier1);
      expect(sparse.weighInDaysIn21, 9);
      expect(sparse.reasons, [CheckInReason.insufficientWeighIns]);
    });

    test('snack-only unmarked days are not logged days', () {
      final t = tierFor(
        logs: _logs(
          end: asOf,
          kcal: 300,
          completeness: LoggingCompleteness.unmarked,
        ),
      );
      expect(t.tier, DataTier.tier0);
      expect(t.thisWeek.daysWithEntries, 7);
      expect(t.thisWeek.daysCounted, 0);
    });
  });

  group('ObservedExpenditure', () {
    final slope = WeightSlopeCalculator.compute(
      _line(end: _today, kgPerWeek: -0.7),
      today: _today,
    );

    test('Tier 2: intake minus the stored energy of the trend', () {
      // -0.1 kg a day x 7,700 = -770: expenditure = 2,000 + 770.
      expect(
        ObservedExpenditure.kcalPerDay(
          tier: DataTier.tier2,
          meanIntakeKcal: 2000,
          slope: slope,
        ),
        closeTo(2770, 1e-6),
      );
    });

    test('nothing below Tier 2, without intake, or without a slope', () {
      expect(
        ObservedExpenditure.kcalPerDay(
            tier: DataTier.tier1, meanIntakeKcal: 2000, slope: slope),
        isNull,
      );
      expect(
        ObservedExpenditure.kcalPerDay(
            tier: DataTier.tier2, meanIntakeKcal: null, slope: slope),
        isNull,
      );
      expect(
        ObservedExpenditure.kcalPerDay(
            tier: DataTier.tier2, meanIntakeKcal: double.nan, slope: slope),
        isNull,
      );
      expect(
        ObservedExpenditure.kcalPerDay(
          tier: DataTier.tier2,
          meanIntakeKcal: 2000,
          slope: const WeightSlope.none(),
        ),
        isNull,
      );
    });
  });
}
