import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/models/training_session.dart';
import 'package:fighter_edge/notifications/training_reminder_schedule.dart';

void main() {
  TrainingSession session(String day) => TrainingSession(
        day: day,
        title: 't',
        subtitle: '',
        icon: Icons.circle,
        completed: false,
      );

  test('maps each three-letter day to its DateTime weekday', () {
    final weekdays = TrainingReminderSchedule.weekdaysFor([
      session('Mon'),
      session('Tue'),
      session('Wed'),
      session('Thu'),
      session('Fri'),
      session('Sat'),
      session('Sun'),
    ]);
    expect(
      weekdays,
      {
        DateTime.monday,
        DateTime.tuesday,
        DateTime.wednesday,
        DateTime.thursday,
        DateTime.friday,
        DateTime.saturday,
        DateTime.sunday,
      },
    );
  });

  test('counts a day once whether or not the session is completed', () {
    final weekdays = TrainingReminderSchedule.weekdaysFor([
      session('Mon'),
      TrainingSession(
        day: 'Mon',
        title: 'other',
        subtitle: '',
        icon: Icons.circle,
        completed: true,
        completedAt: DateTime.now(),
      ),
    ]);
    expect(weekdays, {DateTime.monday});
  });

  test('an empty plan has no reminder days', () {
    expect(TrainingReminderSchedule.weekdaysFor([]), isEmpty);
  });

  test('is case-insensitive and tolerates the stored casing', () {
    final weekdays = TrainingReminderSchedule.weekdaysFor([
      session('mon'),
      session('FRIDAY'),
    ]);
    expect(weekdays, {DateTime.monday, DateTime.friday});
  });
}
