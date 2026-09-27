import 'dart:math' as math;

import 'calendar.dart';
import 'fight_camp.dart';
import 'weight_cut_policy.dart';

enum WeightPathStatus {
  /// No current weight, or the weigh-in has passed.
  needsMoreData,

  /// Under [WeightCutPolicy.minimumAgeYears]. The app does not plan cuts
  /// for minors.
  notSupported,

  /// Already at or under the limit.
  atWeight,

  /// Reachable within [WeightCutPolicy.maxWeeklyLossKg] a week in camp and
  /// food-only methods in fight week.
  onTrack,

  /// Reachable only if the last days include a water cut, which needs a
  /// qualified coach or dietitian. The app plans the camp part at the
  /// fastest safe pace and does not plan the water cut.
  needsSupervision,

  /// Beyond the position stand's limits even with a supervised water cut.
  /// The athlete needs a heavier class or a later fight.
  notSafe,
}

/// One point on the camp path: the weight to be at on [date].
class WeightCheckpoint {
  const WeightCheckpoint(this.date, this.weightKg);

  final DateTime date;
  final double weightKg;

  @override
  bool operator ==(Object other) =>
      other is WeightCheckpoint &&
      other.date == date &&
      other.weightKg == weightKg;

  @override
  int get hashCode => Object.hash(date, weightKg);

  @override
  String toString() => 'WeightCheckpoint($date, $weightKg)';
}

/// A calculated route from today's weight to the weigh-in.
class WeightPath {
  const WeightPath._({
    required this.status,
    this.weeklyLossKg = 0,
    this.requiredWeeklyLossKg = 0,
    this.fightWeekEntryKg,
    this.acuteLossKg = 0,
    this.acuteLossFraction = 0,
    this.lightestSafeLimitKg,
    this.checkpoints = const [],
  });

  final WeightPathStatus status;

  /// The planned camp pace, kg a week. Never above
  /// [WeightCutPolicy.maxWeeklyLossKg].
  final double weeklyLossKg;

  /// The pace a food-only fight week would need. Above the planned pace
  /// when the status is [WeightPathStatus.needsSupervision] or
  /// [WeightPathStatus.notSafe].
  final double requiredWeeklyLossKg;

  /// The weight to reach by the start of fight week. Null when there is no
  /// camp left to plan.
  final double? fightWeekEntryKg;

  /// What is left for fight week after the camp path, in kg and as a share
  /// of the weight fight week starts at.
  final double acuteLossKg;
  final double acuteLossFraction;

  /// The lightest limit this athlete could make by this weigh-in with the
  /// fastest safe camp and a food-only fight week. Set when the chosen limit
  /// needs a water cut or is not safe.
  final double? lightestSafeLimitKg;

  /// Weekly targets from next week to the start of fight week, rounded to
  /// 0.1 kg. The last one is [fightWeekEntryKg].
  final List<WeightCheckpoint> checkpoints;

  /// Within the lower end of the recommended range.
  bool get isGentlePace =>
      weeklyLossKg <= WeightCutPolicy.gentleWeeklyLossKg + _epsilon;
}

const double _epsilon = 1e-9;

double _round(double value, int decimals) {
  final factor = math.pow(10, decimals);
  return (value * factor).roundToDouble() / factor;
}

/// Plans a safe route to the weigh-in. Every number comes from
/// [WeightCutPolicy]; nothing here is a guess or a model's output.
class WeightPathCalculator {
  WeightPathCalculator._();

  /// [currentWeightKg] should be the trend weight (see WeightTrend), not a
  /// single weigh-in: daily water swings are larger than a week of camp
  /// progress.
  static WeightPath calculate({
    required double? currentWeightKg,
    required FightCamp camp,
    required DateTime today,
    int? ageYears,
  }) {
    if (ageYears != null && ageYears < WeightCutPolicy.minimumAgeYears) {
      return const WeightPath._(status: WeightPathStatus.notSupported);
    }
    final daysToWeighIn = camp.daysToWeighIn(today);
    final current = currentWeightKg;
    if (current == null ||
        !current.isFinite ||
        current <= 0 ||
        daysToWeighIn < 0) {
      return const WeightPath._(status: WeightPathStatus.needsMoreData);
    }
    final limit = camp.weightLimitKg;
    if (current <= limit) {
      return const WeightPath._(status: WeightPathStatus.atWeight);
    }

    final supervisedFraction = WeightCutPolicy.supervisedAcuteFraction(
      camp.category,
      daysToWeighIn,
    );

    if (daysToWeighIn <= WeightCutPolicy.fightWeekDays) {
      return _inFightWeek(current, limit, supervisedFraction);
    }

    final weeks = (daysToWeighIn - WeightCutPolicy.fightWeekDays) / 7;
    const maxRate = WeightCutPolicy.maxWeeklyLossKg;
    final dietEntry = limit / (1 - WeightCutPolicy.dietOnlyAcuteFraction);
    final supervisedEntry = limit / (1 - supervisedFraction);
    final requiredRate = math.max(0.0, (current - dietEntry) / weeks);
    final lightestSafe = _round(
      (current - maxRate * weeks) * (1 - WeightCutPolicy.dietOnlyAcuteFraction),
      1,
    );

    WeightPathStatus status;
    double rate;
    if (requiredRate <= maxRate + _epsilon) {
      status = WeightPathStatus.onTrack;
      // Camp does the work, up to the gentle pace, so fight week only needs
      // food for what is left: often nothing, never more than food can do.
      final toLimitRate = (current - limit) / weeks;
      rate = math.max(requiredRate,
          math.min(WeightCutPolicy.gentleWeeklyLossKg, toLimitRate));
    } else if ((current - supervisedEntry) / weeks <= maxRate + _epsilon) {
      status = WeightPathStatus.needsSupervision;
      rate = maxRate;
    } else {
      return WeightPath._(
        status: WeightPathStatus.notSafe,
        requiredWeeklyLossKg: _round(requiredRate, 2),
        lightestSafeLimitKg: lightestSafe,
      );
    }

    // Never below the limit: a camp that reaches it leaves nothing, not -0.0.
    final entry = math.max(limit, current - rate * weeks);
    return WeightPath._(
      status: status,
      weeklyLossKg: _round(rate, 2),
      requiredWeeklyLossKg: _round(requiredRate, 2),
      fightWeekEntryKg: _round(entry, 1),
      acuteLossKg: _round(entry - limit, 1),
      acuteLossFraction: (entry - limit) / entry,
      lightestSafeLimitKg:
          status == WeightPathStatus.onTrack ? null : lightestSafe,
      checkpoints: _checkpoints(today, camp.fightWeekStart, current, rate),
    );
  }

  /// Inside fight week there is no camp left: what remains is all acute.
  static WeightPath _inFightWeek(
    double current,
    double limit,
    double supervisedFraction,
  ) {
    final fraction = (current - limit) / current;
    final WeightPathStatus status;
    if (fraction <= WeightCutPolicy.dietOnlyAcuteFraction + _epsilon) {
      status = WeightPathStatus.onTrack;
    } else if (fraction <= supervisedFraction + _epsilon) {
      status = WeightPathStatus.needsSupervision;
    } else {
      status = WeightPathStatus.notSafe;
    }
    return WeightPath._(
      status: status,
      acuteLossKg: _round(current - limit, 1),
      acuteLossFraction: fraction,
      lightestSafeLimitKg: status == WeightPathStatus.onTrack
          ? null
          : _round(current * (1 - WeightCutPolicy.dietOnlyAcuteFraction), 1),
    );
  }

  static List<WeightCheckpoint> _checkpoints(
    DateTime today,
    DateTime fightWeekStart,
    double current,
    double rate,
  ) {
    final totalDays = daysBetween(today, fightWeekStart);
    final points = <WeightCheckpoint>[];
    // A weekly target closer than this to the start of fight week would sit
    // a day or two from the final one and add nothing but noise.
    const minGapToFinal = 4;
    for (var day = 7; day <= totalDays - minGapToFinal; day += 7) {
      points.add(WeightCheckpoint(
        addDays(today, day),
        _round(current - rate * day / 7, 1),
      ));
    }
    points.add(WeightCheckpoint(
      calendarDay(fightWeekStart),
      _round(current - rate * totalDays / 7, 1),
    ));
    return points;
  }
}
