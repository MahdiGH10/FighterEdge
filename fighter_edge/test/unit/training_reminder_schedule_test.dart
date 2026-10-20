import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/notifications/training_reminder_schedule.dart';

void main() {
  test('reminders fire in the evening, after a typical session', () {
    expect(TrainingReminderSchedule.defaultTime.hour, 18);
    expect(TrainingReminderSchedule.defaultTime.minute, 0);
  });
}
