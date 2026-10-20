/// One document of the old weekday-string schedule (`users/{uid}/sessions`):
/// a template slot such as "Tue Wrestling" that repeated every week.
///
/// Kept only as the source of the one-time migration to dated
/// `PlannedSession`s (`LegacyPlanMigration`) and of the older move of slot
/// completions into the training log. Nothing in the app plans from it.
class LegacySessionSlot {
  const LegacySessionSlot({
    required this.id,
    required this.day,
    required this.title,
    this.subtitle = '',
    this.iconName,
    this.completed = false,
    this.completedAt,
    this.rpe = 0,
    this.note = '',
  });

  final String id;

  /// "Mon", "Tue", ...
  final String day;
  final String title;
  final String subtitle;

  /// Stored as written; the migration does not need icons.
  final String? iconName;
  final bool completed;
  final DateTime? completedAt;
  final int rpe;
  final String note;

  /// The same slot with its completion removed.
  LegacySessionSlot cleared() => LegacySessionSlot(
        id: id,
        day: day,
        title: title,
        subtitle: subtitle,
        iconName: iconName,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'title': title,
        'subtitle': subtitle,
        'iconName': iconName,
        'completed': completed,
        'completedAt': completedAt?.toIso8601String(),
        'rpe': rpe,
        'note': note,
      };

  factory LegacySessionSlot.fromJson(Map<String, dynamic> json) {
    final day = json['day'] as String? ?? '';
    final title = json['title'] as String? ?? '';
    return LegacySessionSlot(
      id: json['id'] as String? ?? '$day-$title',
      day: day,
      title: title,
      subtitle: json['subtitle'] as String? ?? '',
      iconName: json['iconName'] as String?,
      completed: json['completed'] as bool? ?? false,
      completedAt: DateTime.tryParse(json['completedAt'] as String? ?? ''),
      rpe: (json['rpe'] as num?)?.toInt() ?? 0,
      note: json['note'] as String? ?? '',
    );
  }
}
