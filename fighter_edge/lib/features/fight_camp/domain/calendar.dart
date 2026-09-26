/// Calendar-day math for the pure domain.
///
/// A date is its year, month and day; the time of day is ignored. Arithmetic
/// runs on UTC midnights so a 23- or 25-hour daylight-saving day still counts
/// as one day. Nothing here reads a clock: callers pass "today".
library;

/// [date]'s calendar day, as a UTC midnight.
DateTime calendarDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// Whole days from [from] to [to]; negative when [to] is earlier.
int daysBetween(DateTime from, DateTime to) =>
    calendarDay(to).difference(calendarDay(from)).inDays;

/// [days] calendar days after [date] (before, when negative).
DateTime addDays(DateTime date, int days) {
  final day = calendarDay(date);
  return DateTime.utc(day.year, day.month, day.day + days);
}

/// The Monday that starts [date]'s week, like the weekly plan and streak.
DateTime weekStart(DateTime date) =>
    addDays(date, -(calendarDay(date).weekday - DateTime.monday));
