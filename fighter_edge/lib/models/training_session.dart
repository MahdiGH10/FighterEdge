import 'package:flutter/material.dart';
import '../theme/app_icons.dart';

class TrainingSession {
  final String id;
  final String day; // Mon, Tue...
  final String title; // Striking
  final String subtitle; // Boxing + Combinations
  final IconData icon;
  final bool completed;
  final DateTime? completedAt;
  final int rpe;
  final String note;

  const TrainingSession({
    String? id,
    required this.day,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    this.completedAt,
    this.rpe = 0,
    this.note = '',
  }) : id = id ?? '$day-$title';

  TrainingSession copyWith({
    bool? completed,
    DateTime? completedAt,
    int? rpe,
    String? note,
    bool clearCompletedAt = false,
  }) =>
      TrainingSession(
        id: id,
        day: day,
        title: title,
        subtitle: subtitle,
        icon: icon,
        completed: completed ?? this.completed,
        completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
        rpe: rpe ?? this.rpe,
        note: note ?? this.note,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'title': title,
        'subtitle': subtitle,
        'iconName': _iconName(icon),
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
        'rpe': rpe,
        'note': note,
      };

  factory TrainingSession.fromJson(Map<String, dynamic> json) {
    return TrainingSession(
      id: json['id'] as String?,
      day: json['day'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      icon: _iconFromName(json['iconName'] as String?),
      completed: json['completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      rpe: (json['rpe'] as num?)?.toInt() ?? 0,
      note: json['note'] as String? ?? '',
    );
  }

  static String _iconName(IconData icon) {
    if (icon == AppIcons.handGrabbing) return 'sports_kabaddi';
    if (icon == AppIcons.handFist) return 'sports_martial_arts';
    if (icon == AppIcons.lightning) return 'bolt';
    if (icon == AppIcons.barbell) return 'fitness_center';
    if (icon == AppIcons.personSimpleRun) return 'directions_run';
    if (icon == AppIcons.flowerLotus) return 'spa';
    return 'sports_mma';
  }

  static IconData _iconFromName(String? name) {
    return switch (name) {
      'sports_kabaddi' => AppIcons.handGrabbing,
      'sports_martial_arts' => AppIcons.handFist,
      'bolt' => AppIcons.lightning,
      'fitness_center' => AppIcons.barbell,
      'directions_run' => AppIcons.personSimpleRun,
      'spa' => AppIcons.flowerLotus,
      _ => AppIcons.boxingGlove,
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
