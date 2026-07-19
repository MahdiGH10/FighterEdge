import 'package:flutter/material.dart';

class TrainingSession {
  final String id;
  final String day; // Mon, Tue...
  final String title; // Striking
  final String subtitle; // Boxing + Combinations
  final IconData icon;
  final bool completed;

  const TrainingSession({
    String? id,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
  }) : id = id ?? '$day-$title';

  TrainingSession copyWith({bool? completed}) => TrainingSession(
        id: id,
        day: day,
        title: title,
        subtitle: subtitle,
        icon: icon,
        completed: completed ?? this.completed,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'title': title,
        'subtitle': subtitle,
        'iconName': _iconName(icon),
        'completed': completed,
      };

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String?,
      day: json['day'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: _iconFromName(json['iconName'] as String?),
      completed: json['completed'] as bool? ?? false,
    );
  }

  static String _iconName(IconData icon) {
    if (icon == Icons.sports_kabaddi) return 'sports_kabaddi';
    if (icon == Icons.sports_martial_arts) return 'sports_martial_arts';
    if (icon == Icons.bolt) return 'bolt';
    if (icon == Icons.fitness_center) return 'fitness_center';
    if (icon == Icons.directions_run) return 'directions_run';
    if (icon == Icons.spa) return 'spa';
    return 'sports_mma';
  }

  static IconData _iconFromName(String? name) {
    return switch (name) {
      'sports_kabaddi' => Icons.sports_kabaddi,
      'sports_martial_arts' => Icons.sports_martial_arts,
      'bolt' => Icons.bolt,
      'fitness_center' => Icons.fitness_center,
      'directions_run' => Icons.directions_run,
      'spa' => Icons.spa,
      _ => Icons.sports_mma,
    };
  }
}

class ActivityEntry {
  final String title;
  final String subtitle;
  final String when;
  final IconData icon;
  const ActivityEntry(this.title, this.subtitle, this.when, this.icon);
}
