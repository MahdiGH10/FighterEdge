import 'package:flutter/material.dart';

import '../models/training_session.dart';

/// Turns the user's current training week into what a reminder gateway's
/// `scheduleTrainingReminders` needs.
///
/// A separate small file rather than a method on `AppState` or the gateway
/// itself, because it is pure mapping with no state of its own — the one
/// place `TrainingSession.day`'s three-letter format meets `DateTime`'s
/// weekday numbering, so that translation exists exactly once.
class TrainingReminderSchedule {
  TrainingReminderSchedule._();

  /// Evening, after a typical training session and before sleep — early
  /// enough to still act on, late enough not to double as a morning alarm.
  static const TimeOfDay defaultTime = TimeOfDay(hour: 18, minute: 0);

  static const _weekdayByPrefix = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  /// The weekdays the current plan has a session on, whether or not it has
  /// been completed yet — the reminder is about training days, not the
  /// remaining ones.
  static Set<int> weekdaysFor(List<TrainingSession> sessions) {
    final weekdays = <int>{};
    for (final session in sessions) {
      final prefix = session.day.trim().toLowerCase();
      for (final entry in _weekdayByPrefix.entries) {
        if (prefix.startsWith(entry.key)) {
          weekdays.add(entry.value);
          break;
        }
      }
    }
    return weekdays;
  }
}
