import 'package:flutter/material.dart';

/// When training reminders fire. The weekdays come from the training plan
/// (`PlanController.trainingWeekdays`, `DateTime`'s 1-7 numbering).
class TrainingReminderSchedule {
  TrainingReminderSchedule._();

  /// Evening, after a typical training session and before sleep — early
  /// enough to still act on, late enough not to double as a morning alarm.
  static const TimeOfDay defaultTime = TimeOfDay(hour: 18, minute: 0);
}
