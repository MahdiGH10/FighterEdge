import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_trend.dart';
import 'package:flutter_test/flutter_test.dart';

final today = DateTime(2026, 9, 26, 8);

WeightPoint daysAgo(int days, double kg) =>
    WeightPoint(addDays(today, -days), kg);

void main() {
  test('averages this week and compares it with the week before', () {
    final trend = WeightTrend.from([
      daysAgo(4, 80.2),
      daysAgo(0, 80.0),
      daysAgo(2, 80.4),
      daysAgo(7, 81.0),
      daysAgo(13, 81.4),
      daysAgo(14, 90.0),
    ], today: today);
    expect(trend.trendKg, closeTo(80.2, 1e-9));
    expect(trend.weeklyChangeKg, closeTo(-1.0, 1e-9));
    expect(trend.weighInsLast7Days, 3);
    expect(trend.latestKg, 80.0);
    expect(trend.latestDate, calendarDay(today));
  });

  test('an old weigh-in is not passed off as today', () {
    final trend = WeightTrend.from([daysAgo(8, 79.0)], today: today);
    expect(trend.trendKg, isNull);
    expect(trend.weeklyChangeKg, isNull);
    expect(trend.latestKg, 79.0);
  });

  test('ignores future and impossible weigh-ins', () {
    final trend = WeightTrend.from([
      daysAgo(-1, 70.0),
      daysAgo(1, 0),
      daysAgo(1, double.nan),
      daysAgo(1, 78.0),
    ], today: today);
    expect(trend.trendKg, 78.0);
    expect(trend.weighInsLast7Days, 1);
  });

  test('no weigh-ins at all', () {
    final trend = WeightTrend.from(const [], today: today);
    expect(trend.trendKg, isNull);
    expect(trend.latestKg, isNull);
    expect(trend.weighInsLast7Days, 0);
  });

  test('series gives one trend point per day with recent weigh-ins', () {
    final series = WeightTrend.series(
      [daysAgo(10, 82), daysAgo(9, 81), daysAgo(1, 80), daysAgo(0, 79)],
      from: addDays(today, -10),
      to: addDays(today, 1),
    );
    final byAge = {
      for (final p in series) daysBetween(p.date, calendarDay(today)): p.kg,
    };
    expect(byAge[10], 82);
    expect(byAge[9], 81.5);
    expect(byAge[4], 81.5, reason: 'both old weigh-ins are within 7 days');
    expect(byAge[3], 81, reason: 'only the 9-days-ago weigh-in is in range');
    expect(byAge.containsKey(2), isFalse, reason: 'no weigh-in in 7 days');
    expect(byAge[1], 80);
    expect(byAge[0], 79.5);
    expect(byAge[-1], 79.5, reason: 'tomorrow still sees the last week');
    expect(series.map((p) => p.date).toSet().length, series.length);
  });
}
