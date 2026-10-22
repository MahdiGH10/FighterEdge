import 'dart:math' as math;

import 'calendar_day.dart';
import 'weigh_in.dart';

/// Whether a [WeightSlope] can be used for a decision.
enum WeightSlopeStatus {
  ok,

  /// Fewer usable weigh-in days than the window needs.
  insufficientPoints,

  /// The usable weigh-ins do not span enough days.
  insufficientSpan,
}

/// The decision slope: an ordinary-least-squares line through the usable
/// weigh-ins of the last 21 days (14 for the Tier-1 fallback), with a noise
/// band taken from the line's own residuals.
class WeightSlope {
  const WeightSlope({
    required this.status,
    required this.windowDays,
    this.slopeKgPerDay,
    this.noiseBandKgPerWeek,
    this.residualSdKg,
    this.pointsUsed = 0,
    this.spanDays = 0,
    this.excludedInvalid = 0,
    this.excludedNonStandard = 0,
    this.excludedFightWeek = 0,
    this.outlierDays = const [],
  });

  /// A slope that is not there: for callers with no weigh-ins at all.
  const WeightSlope.none()
      : status = WeightSlopeStatus.insufficientPoints,
        windowDays = WeightSlopeCalculator.windowDays,
        slopeKgPerDay = null,
        noiseBandKgPerWeek = null,
        residualSdKg = null,
        pointsUsed = 0,
        spanDays = 0,
        excludedInvalid = 0,
        excludedNonStandard = 0,
        excludedFightWeek = 0,
        outlierDays = const [];

  final WeightSlopeStatus status;

  /// 21 or 14.
  final int windowDays;

  /// Null unless [status] is [WeightSlopeStatus.ok].
  final double? slopeKgPerDay;

  /// 95% half-width of the slope, in kg per week: `1.96 x s / sqrt(Sxx) x 7`.
  final double? noiseBandKgPerWeek;

  /// Standard deviation of the residuals (n - 2 degrees of freedom).
  final double? residualSdKg;

  /// Distinct days that went into the line.
  final int pointsUsed;

  /// First to last day of the points used, in days.
  final int spanDays;

  /// Counts of window readings left out, by cause.
  final int excludedInvalid;
  final int excludedNonStandard;
  final int excludedFightWeek;

  /// Days dropped by the outlier rule. The UI may still show them, greyed.
  final List<CalendarDay> outlierDays;

  bool get isUsable => status == WeightSlopeStatus.ok && slopeKgPerDay != null;

  double? get slopeKgPerWeek =>
      slopeKgPerDay == null ? null : slopeKgPerDay! * 7;
}

/// Computes [WeightSlope] from raw weigh-ins. Pure.
///
/// Rules, from `docs/nutrition_research_20261022/targets.md` section 4.2:
///
/// 1. Only valid, standard-condition, non-fight-week readings count. Several
///    readings on one day become their mean.
/// 2. Outlier: a day more than `max(1.5 kg, 2% of the median)` from the median
///    of the other readings within 3 days either side is dropped. A day with
///    fewer than two neighbours cannot be judged and stays.
/// 3. The line needs 12 days and a 14-day span over 21 days, or 8 days and a
///    10-day span over the 14-day fallback.
///
/// Water events (salt, creatine, cycle, carb load) are not modelled; the long
/// window and the noise band are the defence. The thresholds are
/// implementation defaults pending dietitian review.
class WeightSlopeCalculator {
  const WeightSlopeCalculator._();

  static const int windowDays = 21;
  static const int fallbackWindowDays = 14;
  static const int minPoints = 12;
  static const int minSpanDays = 14;
  static const int fallbackMinPoints = 8;
  static const int fallbackMinSpanDays = 10;

  static const double outlierMinKg = 1.5;
  static const double outlierBodyWeightFraction = 0.02;
  static const int outlierNeighbourDays = 3;
  static const double noiseBandZ = 1.96;

  /// The 21-day slope, or the 14-day fallback when the long window is short
  /// of data. Returns the 21-day result (with its status) when neither works.
  static WeightSlope best(
    List<WeighIn> weighIns, {
    required CalendarDay today,
  }) {
    final long = compute(weighIns, today: today);
    if (long.isUsable) return long;
    final short = compute(weighIns, today: today, window: fallbackWindowDays);
    return short.isUsable ? short : long;
  }

  /// The slope over the last [window] days ending on [today], inclusive.
  static WeightSlope compute(
    List<WeighIn> weighIns, {
    required CalendarDay today,
    int window = windowDays,
  }) {
    final start = today.plusDays(-(window - 1));
    var invalid = 0;
    var nonStandard = 0;
    var fightWeek = 0;
    // Day -> readings, for every usable reading (also just before the window:
    // they are neighbours for the outlier rule).
    final byDay = <int, List<double>>{};
    for (final w in weighIns) {
      final inWindow = w.day.isWithin(start, today);
      if (!w.isValid) {
        if (inWindow) invalid++;
        continue;
      }
      if (w.inFightWeek) {
        if (inWindow) fightWeek++;
        continue;
      }
      if (!w.isStandardCondition) {
        if (inWindow) nonStandard++;
        continue;
      }
      if (w.day.isAfter(today)) continue;
      byDay.putIfAbsent(w.day.epochDay, () => []).add(w.kg);
    }
    final daily = <int, double>{
      for (final e in byDay.entries)
        e.key: e.value.reduce((a, b) => a + b) / e.value.length,
    };

    final inWindowDays = [
      for (final d in daily.keys)
        if (d >= start.epochDay && d <= today.epochDay) d,
    ]..sort();

    final outliers = <int>[];
    final kept = <int>[];
    for (final d in inWindowDays) {
      final neighbours = <double>[
        for (var o = -outlierNeighbourDays; o <= outlierNeighbourDays; o++)
          if (o != 0 && daily.containsKey(d + o)) daily[d + o]!,
      ];
      if (neighbours.length < 2) {
        kept.add(d);
        continue;
      }
      final median = _median(neighbours);
      final limit = math.max(outlierMinKg, outlierBodyWeightFraction * median);
      if ((daily[d]! - median).abs() > limit) {
        outliers.add(d);
      } else {
        kept.add(d);
      }
    }

    final outlierDays = [
      for (final d in outliers) CalendarDay.fromEpochDay(d),
    ];
    WeightSlope failed(WeightSlopeStatus status, int span) => WeightSlope(
          status: status,
          windowDays: window,
          pointsUsed: kept.length,
          spanDays: span,
          excludedInvalid: invalid,
          excludedNonStandard: nonStandard,
          excludedFightWeek: fightWeek,
          outlierDays: outlierDays,
        );

    final needPoints = window >= windowDays ? minPoints : fallbackMinPoints;
    final needSpan = window >= windowDays ? minSpanDays : fallbackMinSpanDays;
    final span = kept.isEmpty ? 0 : kept.last - kept.first;
    if (kept.length < needPoints) {
      return failed(WeightSlopeStatus.insufficientPoints, span);
    }
    if (span < needSpan) {
      return failed(WeightSlopeStatus.insufficientSpan, span);
    }

    final n = kept.length;
    final meanX = kept.fold<double>(0, (a, d) => a + d) / n;
    final meanY = kept.fold<double>(0, (a, d) => a + daily[d]!) / n;
    var sxx = 0.0;
    var sxy = 0.0;
    for (final d in kept) {
      final dx = d - meanX;
      sxx += dx * dx;
      sxy += dx * (daily[d]! - meanY);
    }
    final slope = sxy / sxx;
    final intercept = meanY - slope * meanX;
    var ssr = 0.0;
    for (final d in kept) {
      final r = daily[d]! - (intercept + slope * d);
      ssr += r * r;
    }
    final sd = math.sqrt(ssr / (n - 2));
    final band = noiseBandZ * sd / math.sqrt(sxx) * 7;
    return WeightSlope(
      status: WeightSlopeStatus.ok,
      windowDays: window,
      slopeKgPerDay: slope,
      noiseBandKgPerWeek: band,
      residualSdKg: sd,
      pointsUsed: n,
      spanDays: span,
      excludedInvalid: invalid,
      excludedNonStandard: nonStandard,
      excludedFightWeek: fightWeek,
      outlierDays: outlierDays,
    );
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
