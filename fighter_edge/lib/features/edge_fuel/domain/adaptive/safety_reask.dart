import 'calendar_day.dart';

/// When the safety questions (clinical flags, eating-disorder screen) are due
/// again. The first answers are a one-time self-declaration; a person's
/// situation changes, so they are asked again every 8 weeks and whenever a
/// loss goal starts (`targets.md` section 4.7, gap G11). Pure: the caller
/// passes `today`.
///
/// The interval is an implementation default pending dietitian review, as is
/// the wording of the questions themselves.
class SafetyReask {
  const SafetyReask._();

  static const int intervalWeeks = 8;
  static const int intervalDays = intervalWeeks * 7;

  /// The day the questions fall due after they were answered on [answeredOn].
  static CalendarDay nextDue(CalendarDay answeredOn) =>
      answeredOn.plusDays(intervalDays);

  /// True when the questions are due on [today].
  ///
  /// - never answered ([lastAnsweredOn] null): due;
  /// - answered 8 or more weeks ago: due;
  /// - a loss goal started after the last answer ([lossGoalStartedOn]): due.
  static bool isDue({
    required CalendarDay? lastAnsweredOn,
    required CalendarDay today,
    CalendarDay? lossGoalStartedOn,
  }) {
    if (lastAnsweredOn == null) return true;
    if (lossGoalStartedOn != null && lossGoalStartedOn.isAfter(lastAnsweredOn)) {
      return true;
    }
    return !today.isBefore(nextDue(lastAnsweredOn));
  }
}
