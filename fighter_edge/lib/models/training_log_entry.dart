import '../data/data_repository.dart';

/// Where a piece of logged training came from.
enum TrainingSource {
  /// One of the weekly plan's sessions, marked done.
  planned,

  /// A round-timer workout finished without a planned session behind it.
  timer,

  /// A finished Reaction drill.
  reaction,

  /// Training the athlete logged by hand.
  manual;

  /// Whether this source makes a day count as a training day for the weekly
  /// target and streak. A 30-second Reaction drill is real work, and it is
  /// logged and shown, but it cannot stand in for a session (decision D1 in
  /// docs/IMPLEMENTATION_PLAN_RETENTION_20260923.md).
  bool get countsAsTrainingDay => this != TrainingSource.reaction;
}

/// One occurrence of training, kept forever.
///
/// The weekly plan (`TrainingSession`) is a template that repeats every week;
/// this is the record of what actually happened on a given day. Before the
/// log existed, completing a plan slot overwrote the slot itself, so the app
/// could never hold more than one week of history.
class TrainingLogEntry {
  final String id;
  final DateTime completedAt;
  final TrainingSource source;
  final String title;

  /// The weekly plan slot this entry fulfils (`TrainingSession.id`), if any.
  final String? planSlotId;
  final int? durationSeconds;

  /// Session effort 1–10; 0 means not rated.
  final int rpe;
  final String note;

  /// Small, fixed facts about the work (e.g. a Reaction drill's discipline
  /// and level). Never free text from the athlete — that belongs in [note].
  final Map<String, Object> detail;

  const TrainingLogEntry({
    required this.id,
    required this.completedAt,
    required this.source,
    required this.title,
    this.planSlotId,
    this.durationSeconds,
    this.rpe = 0,
    this.note = '',
    this.detail = const {},
  });

  /// The one entry a plan slot gets per calendar day. Deterministic, so the
  /// legacy migration and repeated saves write the same document instead of
  /// piling up duplicates.
  static String plannedId(String slotId, DateTime day) =>
      'plan-$slotId-${mealDateKey(day)}';

  /// The calendar day this entry counts for (local time).
  String get dateKey => mealDateKey(completedAt);

  TrainingLogEntry copyWith({
    DateTime? completedAt,
    int? durationSeconds,
    int? rpe,
    String? note,
  }) =>
      TrainingLogEntry(
        id: id,
        completedAt: completedAt ?? this.completedAt,
        source: source,
        title: title,
        planSlotId: planSlotId,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        rpe: rpe ?? this.rpe,
        note: note ?? this.note,
        detail: detail,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'completedAt': completedAt.toIso8601String(),
        // Sortable across time zones, unlike the ISO string above.
        'completedAtMs': completedAt.millisecondsSinceEpoch,
        'dateKey': dateKey,
        'source': source.name,
        'title': title,
        'planSlotId': planSlotId,
        'durationSeconds': durationSeconds,
        'rpe': rpe,
        'note': note,
        'detail': detail,
      };

  /// Tolerates missing or malformed fields rather than throwing: one bad
  /// document must not take the whole history screen down with it. Returns
  /// null only when the entry has no usable time, since everything that reads
  /// the log is organised by date.
  static TrainingLogEntry? fromJson(Map<String, dynamic> json, {String? id}) {
    final ms = json['completedAtMs'];
    final completedAt = ms is num
        ? DateTime.fromMillisecondsSinceEpoch(ms.toInt())
        : DateTime.tryParse(json['completedAt'] as String? ?? '');
    if (completedAt == null) return null;
    final sourceName = json['source'] as String?;
    final rawDetail = json['detail'];
    return TrainingLogEntry(
      id: id ?? json['id'] as String? ?? '',
      completedAt: completedAt,
      source: TrainingSource.values.firstWhere(
        (s) => s.name == sourceName,
        orElse: () => TrainingSource.manual,
      ),
      title: json['title'] as String? ?? '',
      planSlotId: json['planSlotId'] as String?,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      rpe: (json['rpe'] as num?)?.toInt() ?? 0,
      note: json['note'] as String? ?? '',
      detail: rawDetail is Map
          ? {
              for (final e in rawDetail.entries)
                if (e.key is String && e.value != null)
                  e.key as String: e.value as Object,
            }
          : const {},
    );
  }
}
