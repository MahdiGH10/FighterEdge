/// A calendar day with no time of day and no time zone, counted in whole days.
///
/// The adaptive targets work in days, not instants: a weigh-in belongs to the
/// day the user saw on their own calendar. Keeping that as an integer makes
/// "days between" exact (no daylight-saving off-by-one) and keeps the domain
/// free of the clock: callers pass `today`.
class CalendarDay implements Comparable<CalendarDay> {
  /// Days since 1970-01-01 (negative before it).
  const CalendarDay.fromEpochDay(this.epochDay);

  factory CalendarDay(int year, int month, int day) => CalendarDay.fromEpochDay(
        DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
            Duration.millisecondsPerDay,
      );

  /// The calendar day [value] shows, ignoring its time and zone offset.
  factory CalendarDay.fromDateTime(DateTime value) =>
      CalendarDay(value.year, value.month, value.day);

  final int epochDay;

  CalendarDay plusDays(int days) => CalendarDay.fromEpochDay(epochDay + days);

  /// Whole days from this day to [other]; negative when [other] is earlier.
  int daysUntil(CalendarDay other) => other.epochDay - epochDay;

  bool isBefore(CalendarDay other) => epochDay < other.epochDay;
  bool isAfter(CalendarDay other) => epochDay > other.epochDay;

  /// True when this day is within `[start, end]` inclusive.
  bool isWithin(CalendarDay start, CalendarDay end) =>
      epochDay >= start.epochDay && epochDay <= end.epochDay;

  @override
  int compareTo(CalendarDay other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) =>
      other is CalendarDay && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  /// ISO 8601 date, e.g. `2026-10-22`.
  @override
  String toString() {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    String two(int v) => v.toString().padLeft(2, '0');
    return '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}';
  }
}
