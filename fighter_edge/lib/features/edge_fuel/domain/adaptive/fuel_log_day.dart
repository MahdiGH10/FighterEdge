import 'calendar_day.dart';

/// How complete the user says one day's food log is.
enum LoggingCompleteness {
  /// The user did not say. The kcal logged decide (see
  /// [FuelLogDay.countsAsData]).
  unmarked,

  /// "I logged everything."
  complete,

  /// "I did not log everything." A partial day is not data, however many
  /// kcal it holds, because a half-logged day silently lowers measured
  /// intake and drags an adaptive estimate down.
  partial,
}

/// One day of food logging, as the adaptive targets need it. Pure data: no UI
/// and no storage type.
class FuelLogDay {
  const FuelLogDay({
    required this.day,
    this.intakeKcal,
    this.completeness = LoggingCompleteness.unmarked,
  });

  final CalendarDay day;

  /// Total kcal logged that day; null when nothing was logged.
  final double? intakeKcal;
  final LoggingCompleteness completeness;

  /// An unmarked day counts only when it reaches this share of the target:
  /// one snack must not count as a logged day.
  static const double unmarkedMinTargetShare = 0.5;

  /// Anything was logged.
  bool get hasEntries =>
      intakeKcal != null && intakeKcal!.isFinite && intakeKcal! > 0;

  bool get isPartial => completeness == LoggingCompleteness.partial;

  /// Whether this day may be used as data for a target of [targetKcal].
  ///
  /// - partial: never;
  /// - complete: when something was logged;
  /// - unmarked: when at least half the target was logged.
  bool countsAsData(double targetKcal) {
    if (!hasEntries || isPartial) return false;
    if (completeness == LoggingCompleteness.complete) return true;
    return targetKcal.isFinite &&
        targetKcal > 0 &&
        intakeKcal! >= unmarkedMinTargetShare * targetKcal;
  }
}

/// A run of days summarised for one check-in.
class LogWindow {
  const LogWindow({
    required this.daysCounted,
    required this.partialDays,
    required this.daysWithEntries,
    this.averageIntakeKcal,
  });

  /// A window with nothing in it.
  const LogWindow.empty()
      : daysCounted = 0,
        partialDays = 0,
        daysWithEntries = 0,
        averageIntakeKcal = null;

  /// Days that count as data.
  final int daysCounted;

  /// Days the user marked partial.
  final int partialDays;

  /// Days with any food logged (counted or not).
  final int daysWithEntries;

  /// Mean intake over the counted days only; null when none counted.
  final double? averageIntakeKcal;
}

/// Summarises [FuelLogDay]s. Pure.
class LoggingSummary {
  const LoggingSummary._();

  /// The [length] days ending on [endDay] (inclusive). When several records
  /// share a day the last one in [days] wins.
  static LogWindow window(
    List<FuelLogDay> days, {
    required CalendarDay endDay,
    required double targetKcal,
    int length = 7,
  }) {
    final start = endDay.plusDays(-(length - 1));
    final byDay = <int, FuelLogDay>{};
    for (final d in days) {
      if (d.day.isWithin(start, endDay)) byDay[d.day.epochDay] = d;
    }
    var counted = 0;
    var partial = 0;
    var withEntries = 0;
    var sum = 0.0;
    for (final d in byDay.values) {
      if (d.hasEntries) withEntries++;
      if (d.isPartial) partial++;
      if (d.countsAsData(targetKcal)) {
        counted++;
        sum += d.intakeKcal!;
      }
    }
    return LogWindow(
      daysCounted: counted,
      partialDays: partial,
      daysWithEntries: withEntries,
      averageIntakeKcal: counted == 0 ? null : sum / counted,
    );
  }
}
