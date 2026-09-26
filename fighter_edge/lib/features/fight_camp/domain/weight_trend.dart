import 'calendar.dart';

/// One weigh-in.
class WeightPoint {
  const WeightPoint(this.date, this.kg);

  final DateTime date;
  final double kg;
}

/// Body weight smoothed over a week, because a single weigh-in moves by
/// a kilo or more with water and food alone.
class WeightTrend {
  const WeightTrend._({
    this.trendKg,
    this.weeklyChangeKg,
    this.latestKg,
    this.latestDate,
    required this.weighInsLast7Days,
  });

  /// Days in each averaging window, today included in the current one.
  static const int windowDays = 7;

  /// Mean of the weigh-ins in the last [windowDays] days. Null when there
  /// is none: an old weight must not pass for today's.
  final double? trendKg;

  /// [trendKg] minus the mean of the [windowDays] days before. Negative
  /// means losing. Null without a weigh-in in both windows.
  final double? weeklyChangeKg;

  final double? latestKg;
  final DateTime? latestDate;
  final int weighInsLast7Days;

  /// Weigh-ins after [today] are ignored.
  static WeightTrend from(List<WeightPoint> points, {required DateTime today}) {
    final current = <double>[];
    final previous = <double>[];
    WeightPoint? latest;
    for (final point in points) {
      final age = daysBetween(point.date, today);
      if (age < 0 || !point.kg.isFinite || point.kg <= 0) continue;
      if (latest == null || point.date.isAfter(latest.date)) latest = point;
      if (age < windowDays) {
        current.add(point.kg);
      } else if (age < windowDays * 2) {
        previous.add(point.kg);
      }
    }
    final trend = _mean(current);
    final before = _mean(previous);
    return WeightTrend._(
      trendKg: trend,
      weeklyChangeKg: trend == null || before == null ? null : trend - before,
      latestKg: latest?.kg,
      latestDate: latest == null ? null : calendarDay(latest.date),
      weighInsLast7Days: current.length,
    );
  }

  static double? _mean(List<double> values) =>
      values.isEmpty ? null : values.reduce((a, b) => a + b) / values.length;
}
