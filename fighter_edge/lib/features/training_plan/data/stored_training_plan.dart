import '../../fight_camp/domain/calendar.dart';
import '../domain/models/date_key.dart';
import '../domain/models/discipline.dart';
import '../domain/models/experience_level.dart';
import '../domain/models/plan_inputs.dart';
import '../domain/models/training_goal.dart';
import '../domain/session_status_resolver.dart';

/// Where a saved plan came from.
enum PlanOrigin {
  /// Made at onboarding.
  onboarding,

  /// Made once from the old weekday-string schedule.
  migration,
}

/// What is saved for the training plan: the inputs the generator reads and
/// the athlete's skip/move choices. The dated weeks are never stored; the
/// generator rebuilds them, and the same inputs always give the same weeks
/// (compare `PlannedWeek.toJson`).
///
/// The fight is not part of it: it has its own store and is joined in by the
/// controller (`PlanInputs.withFight`).
class StoredTrainingPlan {
  StoredTrainingPlan({
    required this.inputs,
    Iterable<SessionAdjustment> adjustments = const [],
    this.origin = PlanOrigin.onboarding,
    this.generatorVersion,
    this.templateSetVersion,
  }) : adjustments = _byId(adjustments);

  static const int schemaVersion = 1;

  /// Without a fight.
  final PlanInputs inputs;

  /// At most one per session id; the last one given wins.
  final Map<String, SessionAdjustment> adjustments;
  final PlanOrigin origin;

  /// The rules and template set that last made this plan's weeks, for the
  /// day a later version changes them.
  final int? generatorVersion;
  final int? templateSetVersion;

  static Map<String, SessionAdjustment> _byId(
    Iterable<SessionAdjustment> list,
  ) =>
      Map.unmodifiable({for (final a in list) a.sessionId: a});

  StoredTrainingPlan copyWith({
    PlanInputs? inputs,
    Iterable<SessionAdjustment>? adjustments,
    int? generatorVersion,
    int? templateSetVersion,
  }) =>
      StoredTrainingPlan(
        inputs: inputs ?? this.inputs,
        adjustments: adjustments ?? this.adjustments.values,
        origin: origin,
        generatorVersion: generatorVersion ?? this.generatorVersion,
        templateSetVersion: templateSetVersion ?? this.templateSetVersion,
      );

  /// This plan with the adjustment for the same session replaced.
  StoredTrainingPlan withAdjustment(SessionAdjustment adjustment) => copyWith(
        adjustments: [
          for (final a in adjustments.values)
            if (a.sessionId != adjustment.sessionId) a,
          adjustment,
        ],
      );

  /// This plan with any adjustment for [sessionId] removed.
  StoredTrainingPlan withoutAdjustment(String sessionId) => copyWith(
        adjustments: [
          for (final a in adjustments.values)
            if (a.sessionId != sessionId) a,
        ],
      );

  Map<String, Object?> toJson() {
    final days = inputs.trainingWeekdays.toList()..sort();
    final gym = inputs.gymClassWeekdays.toList()..sort();
    final sorted = adjustments.values.toList()
      ..sort((a, b) => a.sessionId.compareTo(b.sessionId));
    return {
      'schemaVersion': schemaVersion,
      'origin': origin.name,
      'generatorVersion': generatorVersion,
      'templateSetVersion': templateSetVersion,
      'inputs': {
        'disciplines': [for (final d in inputs.disciplines) d.name],
        'goal': inputs.goal.name,
        'level': inputs.level.name,
        'weekdays': days,
        'gymClassWeekdays': gym,
        'sessionMinutes': inputs.sessionMinutes,
        'startDate': dateKey(inputs.startDate),
      },
      'adjustments': [
        for (final a in sorted)
          {
            'sessionId': a.sessionId,
            'kind': a.kind.name,
            if (a.movedTo != null) 'movedTo': dateKey(a.movedTo!),
          },
      ],
    };
  }

  /// Null when the document cannot describe a plan (no usable start date).
  /// Unknown or missing values fall back to safe defaults rather than
  /// throwing: one bad field must not hide the whole week.
  static StoredTrainingPlan? fromJson(Map<String, dynamic> json) {
    final raw = json['inputs'];
    if (raw is! Map) return null;
    final inputs = Map<String, dynamic>.from(raw);
    final start = _parseDate(inputs['startDate']);
    if (start == null) return null;
    final plan = PlanInputs(
      disciplines: [
        for (final name in _list(inputs['disciplines']))
          ...Discipline.values.where((d) => d.name == name),
      ],
      goal: TrainingGoal.values.firstWhere(
        (g) => g.name == inputs['goal'],
        orElse: () => TrainingGoal.buildFitness,
      ),
      level: ExperienceLevel.values.firstWhere(
        (l) => l.name == inputs['level'],
        orElse: () => ExperienceLevel.beginner,
      ),
      weekdays: [
        for (final d in _list(inputs['weekdays']))
          if (d is num) d.toInt(),
      ],
      gymClassWeekdays: [
        for (final d in _list(inputs['gymClassWeekdays']))
          if (d is num) d.toInt(),
      ],
      sessionMinutes: (inputs['sessionMinutes'] as num?)?.toInt(),
      startDate: start,
    );
    final adjustments = <SessionAdjustment>[];
    for (final item in _list(json['adjustments'])) {
      if (item is! Map) continue;
      final id = item['sessionId'];
      if (id is! String || id.isEmpty) continue;
      if (item['kind'] == AdjustmentKind.skipped.name) {
        adjustments.add(SessionAdjustment.skipped(id));
      } else if (item['kind'] == AdjustmentKind.moved.name) {
        final to = _parseDate(item['movedTo']);
        if (to != null) adjustments.add(SessionAdjustment.moved(id, to));
      }
    }
    final origin = PlanOrigin.values.firstWhere(
      (o) => o.name == json['origin'],
      orElse: () => PlanOrigin.onboarding,
    );
    return StoredTrainingPlan(
      inputs: plan,
      adjustments: adjustments,
      origin: origin,
      generatorVersion: (json['generatorVersion'] as num?)?.toInt(),
      templateSetVersion: (json['templateSetVersion'] as num?)?.toInt(),
    );
  }

  static List<Object?> _list(Object? value) =>
      value is List ? List<Object?>.from(value) : const [];

  static DateTime? _parseDate(Object? value) {
    if (value is! String) return null;
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    final date = calendarDay(DateTime(y, m, d));
    // Reject 2026-02-31 style dates the constructor would roll over.
    return date.month == m && date.day == d ? date : null;
  }
}
