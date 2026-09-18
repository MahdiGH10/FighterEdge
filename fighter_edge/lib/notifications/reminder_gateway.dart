import 'package:flutter/material.dart';

/// Provider-neutral boundary for training-day reminders.
///
/// Mirrors the billing gateway: product code depends on this interface,
/// never on a notifications SDK directly, so tests and platforms without
/// local notification support (web, desktop) get a safe no-op instead of a
/// runtime failure.
abstract class ReminderGateway {
  /// Whether this platform can actually schedule local notifications. UI that
  /// offers reminders should hide or explain itself when this is false rather
  /// than let the user flip a switch that does nothing.
  bool get isAvailable;

  /// Asks the OS for notification permission. Returns whether it was granted.
  /// Safe to call repeatedly — already-granted or already-denied is not an
  /// error.
  Future<bool> requestPermission();

  /// Schedules a weekly reminder on each of [weekdays]
  /// (`DateTime.monday`..`DateTime.sunday`) at [time], replacing whatever was
  /// scheduled before. An empty set clears all reminders.
  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required TimeOfDay time,
  });

  /// Clears every scheduled reminder.
  Future<void> cancelAll();
}
