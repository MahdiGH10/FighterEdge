import 'food_log_entry.dart';
import 'nutrition_target.dart';

class NutritionDay {
  static const schemaVersion = 1;

  final String localDate;
  final String timeZone;
  final NutritionTarget? targetSnapshot;
  final List<FoodLogEntry> entries;
  final FoodLogTotals totals;
  final String loggingCoverage;
  final bool migratedFromLegacyMeals;
  final DateTime createdAt;
  final DateTime updatedAt;

  const NutritionDay({
    required this.localDate,
    required this.timeZone,
    required this.entries,
    required this.totals,
    required this.createdAt,
    required this.updatedAt,
    this.targetSnapshot,
    this.loggingCoverage = 'none',
    this.migratedFromLegacyMeals = false,
  });

  factory NutritionDay.empty({
    required String localDate,
    required String timeZone,
    required DateTime now,
    NutritionTarget? targetSnapshot,
  }) {
    return NutritionDay(
      localDate: localDate,
      timeZone: timeZone,
      targetSnapshot: targetSnapshot,
      entries: const [],
      totals: const FoodLogTotals(),
      createdAt: now,
      updatedAt: now,
    );
  }

  NutritionDay copyWith({
    String? localDate,
    String? timeZone,
    NutritionTarget? targetSnapshot,
    List<FoodLogEntry>? entries,
    FoodLogTotals? totals,
    String? loggingCoverage,
    bool? migratedFromLegacyMeals,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    final resolvedEntries = entries ?? this.entries;
    return NutritionDay(
      localDate: localDate ?? this.localDate,
      timeZone: timeZone ?? this.timeZone,
      targetSnapshot: targetSnapshot ?? this.targetSnapshot,
      entries: List.unmodifiable(resolvedEntries),
      totals: totals ?? FoodLogTotals.fromEntries(resolvedEntries),
      loggingCoverage: loggingCoverage ?? _coverageFor(resolvedEntries),
      migratedFromLegacyMeals:
          migratedFromLegacyMeals ?? this.migratedFromLegacyMeals,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'localDate': localDate,
        'timeZone': timeZone,
        'targetSnapshot': targetSnapshot?.toJson(),
        'entries': [for (final entry in entries) entry.toJson()],
        'totals': totals.toJson(),
        'hydrationCheckIns': const [],
        'activitySnapshot': null,
        'loggingCoverage': loggingCoverage,
        'migratedFromLegacyMeals': migratedFromLegacyMeals,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory NutritionDay.fromJson(Map<String, dynamic> json) {
    final entries = [
      for (final raw in json['entries'] as List<dynamic>? ?? const [])
        FoodLogEntry.fromJson(Map<String, dynamic>.from(raw as Map)),
    ];
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    return NutritionDay(
      localDate: json['localDate'] as String? ?? '',
      timeZone: json['timeZone'] as String? ?? 'local',
      targetSnapshot: json['targetSnapshot'] is Map
          ? NutritionTarget.fromJson(
              Map<String, dynamic>.from(json['targetSnapshot'] as Map),
            )
          : null,
      entries: List.unmodifiable(entries),
      totals: json['totals'] is Map
          ? FoodLogTotals.fromJson(
              Map<String, dynamic>.from(json['totals'] as Map),
            )
          : FoodLogTotals.fromEntries(entries),
      loggingCoverage:
          json['loggingCoverage'] as String? ?? _coverageFor(entries),
      migratedFromLegacyMeals:
          json['migratedFromLegacyMeals'] as bool? ?? false,
      createdAt: createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
      updatedAt: updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0),
    );
  }

  static String _coverageFor(List<FoodLogEntry> entries) {
    if (entries.isEmpty) return 'none';
    if (entries.length < 3) return 'partial';
    return 'full';
  }
}
