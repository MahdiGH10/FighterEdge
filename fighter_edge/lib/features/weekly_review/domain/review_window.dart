import '../../fight_camp/domain/calendar.dart';

/// Which week the weekly review is about, on a given day.
///
/// Sunday reviews the week that is ending; Monday still offers the week that
/// just ended. Any other day offers nothing, so a review is never a nag.
class ReviewWindow {
  ReviewWindow._();

  /// The Monday of the week to review on [today], or null.
  static DateTime? weekFor(DateTime today) {
    final day = calendarDay(today);
    if (day.weekday == DateTime.sunday) return weekStart(day);
    if (day.weekday == DateTime.monday) return addDays(day, -7);
    return null;
  }
}
