import '../domain/models/discipline.dart';
import '../domain/models/experience_level.dart';
import '../domain/models/plan_inputs.dart';
import '../domain/models/training_goal.dart';
import 'legacy_session_slot.dart';
import 'stored_training_plan.dart';

/// The one-time move from the weekday-string schedule to a dated plan.
///
/// It keeps what the athlete had chosen: the weekdays they trained on and
/// the disciplines in their slot titles. It does not copy the slot names;
/// the generator decides what each day is. The plan starts on the day it is
/// made, so no day before it can count against the athlete, and the training
/// log is untouched.
///
/// Pure and deterministic; the caller saves the result, and the saved plan is
/// the marker that the migration has run.
class LegacyPlanMigration {
  LegacyPlanMigration._();

  static const _weekdayByPrefix = {
    'mon': DateTime.monday,
    'tue': DateTime.tuesday,
    'wed': DateTime.wednesday,
    'thu': DateTime.thursday,
    'fri': DateTime.friday,
    'sat': DateTime.saturday,
    'sun': DateTime.sunday,
  };

  /// Null when no slot names a weekday: there is nothing to carry over.
  ///
  /// [goal] and [level] are the profile's onboarding answers (free text such
  /// as "Lose weight safely" and "Intermediate"); unknown text maps to the
  /// safest default.
  static StoredTrainingPlan? migrate(
    Iterable<LegacySessionSlot> slots, {
    required DateTime today,
    String goal = '',
    String level = '',
  }) {
    final weekdays = <int>{};
    final disciplines = <Discipline>[];
    final ordered = slots.toList()
      ..sort((a, b) => _weekdayOf(a.day).compareTo(_weekdayOf(b.day)));
    for (final slot in ordered) {
      final weekday = _weekdayOf(slot.day);
      if (weekday > DateTime.sunday) continue;
      weekdays.add(weekday);
      final discipline = disciplineOfTitle(slot.title);
      if (discipline != null && !disciplines.contains(discipline)) {
        disciplines.add(discipline);
      }
    }
    if (weekdays.isEmpty) return null;
    return StoredTrainingPlan(
      origin: PlanOrigin.migration,
      inputs: PlanInputs(
        disciplines: disciplines,
        goal: goalOfProfile(goal),
        level: levelOfProfile(level),
        weekdays: weekdays,
        startDate: today,
      ),
    );
  }

  /// 1-7 for "Mon".."Sun" (any longer spelling too); 99 when unrecognised.
  static int _weekdayOf(String day) {
    final text = day.trim().toLowerCase();
    for (final entry in _weekdayByPrefix.entries) {
      if (text.startsWith(entry.key)) return entry.value;
    }
    return 99;
  }

  /// The discipline a slot title names, or null for "Conditioning",
  /// "Strength", "Recovery" and anything else.
  static Discipline? disciplineOfTitle(String title) {
    final text = title.trim().toLowerCase();
    if (text.contains('kickbox')) return Discipline.kickboxing;
    if (text.contains('muay') || text.contains('thai')) {
      return Discipline.muayThai;
    }
    if (text.contains('strik') || text.contains('box')) {
      return Discipline.boxing;
    }
    if (text.contains('wrestl')) return Discipline.wrestling;
    if (text.contains('bjj') ||
        text.contains('jiu') ||
        text.contains('grappl')) {
      return Discipline.bjj;
    }
    if (text.contains('mma')) return Discipline.mma;
    return null;
  }

  /// The camp goal chosen at onboarding, as a plan goal.
  static TrainingGoal goalOfProfile(String goal) => switch (goal.trim()) {
        'Lose weight safely' => TrainingGoal.loseFat,
        'Gain muscle' => TrainingGoal.buildMuscle,
        'Improve technique' => TrainingGoal.improveTechnique,
        'Get competition ready' ||
        'Build fight-camp structure' =>
          TrainingGoal.competitionPrep,
        _ => TrainingGoal.buildFitness,
      };

  /// The experience level chosen at onboarding. Unknown means beginner, who
  /// gets no sparring.
  static ExperienceLevel levelOfProfile(String level) =>
      switch (level.trim()) {
        'Intermediate' => ExperienceLevel.intermediate,
        'Advanced' => ExperienceLevel.advanced,
        'Fighter' => ExperienceLevel.competitor,
        _ => ExperienceLevel.beginner,
      };
}
