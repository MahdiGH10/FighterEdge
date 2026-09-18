import 'package:flutter/material.dart';

import 'reminder_gateway.dart';

/// Safe fallback for tests, web, and desktop: never touches a notifications
/// SDK, never schedules anything, never throws.
class UnavailableReminderGateway implements ReminderGateway {
  const UnavailableReminderGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<bool> requestPermission() async => false;

  @override
  Future<void> scheduleTrainingReminders({
    required Set<int> weekdays,
    required TimeOfDay time,
  }) async {}

  @override
  Future<void> cancelAll() async {}
}
