import 'package:flutter/material.dart';

class TrainingSession {
  final String day;      // Mon, Tue...
  final String title;    // Striking
  final String subtitle; // Boxing + Combinations
  final IconData icon;
  final bool completed;

  const TrainingSession({
    required this.day,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
  });
}

class ActivityEntry {
  final String title;
  final String subtitle;
  final String when;
  final IconData icon;
  const ActivityEntry(this.title, this.subtitle, this.when, this.icon);
}
