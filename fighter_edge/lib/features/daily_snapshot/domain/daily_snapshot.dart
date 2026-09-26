import 'dart:math' as math;

import '../../fight_camp/domain/calendar.dart';
import '../../fight_camp/domain/fight_camp.dart';
import '../../fight_camp/domain/weight_path.dart';
import '../../fight_camp/domain/weight_trend.dart';

/// One piece of logged training, reduced to what the snapshot needs. The
/// app maps its TrainingLogEntry into this so the domain stays pure Dart.
class TrainingRecord {
  const TrainingRecord({
    required this.completedAt,
    required this.countsAsTrainingDay,
    this.durationMinutes,
    this.rpe = 0,
  });

  final DateTime completedAt;

  /// False for work that is logged but cannot stand in for a session
  /// (Reaction drills, decision D1).
  final bool countsAsTrainingDay;
  final int? durationMinutes;

  /// 1–10; 0 means not rated.
  final int rpe;
}

/// One day's food totals.
class NutritionDayTotals {
  const NutritionDayTotals({
    required this.date,
    required this.calories,
    required this.proteinGrams,
  });

  final DateTime date;
  final int calories;
  final int proteinGrams;
}

/// The calculated daily targets.
class NutritionGoal {
  const NutritionGoal({required this.calories, required this.proteinGrams});

  final int calories;
  final int proteinGrams;
}

class TrainingSummary {
  const TrainingSummary({
    required this.sessionsToday,
    required this.trainingDaysThisWeek,
    required this.plannedSessionsPerWeek,
    required this.trainingDaysLast7Days,
    required this.minutesLast7Days,
    required this.averageRpeLast7Days,
  });

  final int sessionsToday;

  /// Distinct training days since Monday.
  final int trainingDaysThisWeek;
  final int plannedSessionsPerWeek;
  final int trainingDaysLast7Days;

  /// All logged work, drills included.
  final int minutesLast7Days;

  /// Over rated sessions only; null when none was rated.
  final double? averageRpeLast7Days;
}

class NutritionSummary {
  const NutritionSummary({
    required this.targetCalories,
    required this.targetProteinGrams,
    required this.consumedCalories,
    required this.consumedProteinGrams,
    required this.loggedDaysLast7Days,
    required this.proteinTargetDaysLast7Days,
  });

  final int targetCalories;
  final int targetProteinGrams;
  final int consumedCalories;
  final int consumedProteinGrams;

  /// Negative when over target.
  int get remainingCalories => targetCalories - consumedCalories;
  int get remainingProteinGrams => targetProteinGrams - consumedProteinGrams;

  /// Days with anything logged, today included.
  final int loggedDaysLast7Days;

  /// Days that reached the protein target, today included.
  final int proteinTargetDaysLast7Days;
}

class CampSummary {
  const CampSummary({
    required this.phase,
    required this.daysToWeighIn,
    required this.daysToFight,
    required this.weightLimitKg,
    required this.weightPath,
  });

  final CampPhase phase;
  final int daysToWeighIn;
  final int daysToFight;
  final double weightLimitKg;
  final WeightPath weightPath;
}

/// Everything calculated about one day of training, food and weight, in
/// one place. Every AI feature reads this instead of assembling its own
/// facts, so they all see the same numbers (product plan, step 2).
class DailySnapshot {
  const DailySnapshot._({
    required this.date,
    required this.training,
    required this.nutrition,
    required this.weight,
    required this.camp,
  });

  final DateTime date;
  final TrainingSummary training;

  /// Null until a target has been calculated.
  final NutritionSummary? nutrition;
  final WeightTrend weight;

  /// Null without a fight on the calendar.
  final CampSummary? camp;

  /// "Last 7 days" is [today] and the six days before it.
  static DailySnapshot build({
    required DateTime today,
    required List<TrainingRecord> training,
    required int plannedSessionsPerWeek,
    required NutritionGoal? goal,
    required List<NutritionDayTotals> nutritionDays,
    required List<WeightPoint> weights,
    FightCamp? camp,
    int? ageYears,
  }) {
    final day = calendarDay(today);
    final trend = WeightTrend.from(weights, today: day);
    return DailySnapshot._(
      date: day,
      training: _training(day, training, plannedSessionsPerWeek),
      nutrition: goal == null ? null : _nutrition(day, goal, nutritionDays),
      weight: trend,
      camp: camp == null
          ? null
          : CampSummary(
              phase: camp.phaseOn(day),
              daysToWeighIn: camp.daysToWeighIn(day),
              daysToFight: camp.daysToFight(day),
              weightLimitKg: camp.weightLimitKg,
              weightPath: WeightPathCalculator.calculate(
                currentWeightKg: trend.trendKg,
                camp: camp,
                today: day,
                ageYears: ageYears,
              ),
            ),
    );
  }

  static bool _inLast7Days(DateTime today, DateTime date) {
    final age = daysBetween(date, today);
    return age >= 0 && age < 7;
  }

  static TrainingSummary _training(
    DateTime today,
    List<TrainingRecord> records,
    int planned,
  ) {
    final monday = weekStart(today);
    var sessionsToday = 0;
    var minutes = 0;
    final daysThisWeek = <DateTime>{};
    final daysLast7 = <DateTime>{};
    final rpes = <int>[];
    for (final record in records) {
      final date = calendarDay(record.completedAt);
      final age = daysBetween(date, today);
      if (age < 0) continue;
      if (age == 0) sessionsToday++;
      if (record.countsAsTrainingDay && !date.isBefore(monday)) {
        daysThisWeek.add(date);
      }
      if (!_inLast7Days(today, date)) continue;
      minutes += math.max(0, record.durationMinutes ?? 0);
      if (record.countsAsTrainingDay) daysLast7.add(date);
      if (record.rpe > 0) rpes.add(record.rpe);
    }
    return TrainingSummary(
      sessionsToday: sessionsToday,
      trainingDaysThisWeek: daysThisWeek.length,
      plannedSessionsPerWeek: planned,
      trainingDaysLast7Days: daysLast7.length,
      minutesLast7Days: minutes,
      averageRpeLast7Days:
          rpes.isEmpty ? null : rpes.reduce((a, b) => a + b) / rpes.length,
    );
  }

  static NutritionSummary _nutrition(
    DateTime today,
    NutritionGoal goal,
    List<NutritionDayTotals> days,
  ) {
    // One total per calendar day; a repeated day keeps its last entry.
    final byDay = <DateTime, NutritionDayTotals>{
      for (final d in days)
        if (_inLast7Days(today, d.date)) calendarDay(d.date): d,
    };
    final todayTotals = byDay[today];
    return NutritionSummary(
      targetCalories: goal.calories,
      targetProteinGrams: goal.proteinGrams,
      consumedCalories: todayTotals?.calories ?? 0,
      consumedProteinGrams: todayTotals?.proteinGrams ?? 0,
      loggedDaysLast7Days: byDay.values
          .where((d) => d.calories > 0 || d.proteinGrams > 0)
          .length,
      proteinTargetDaysLast7Days:
          byDay.values.where((d) => d.proteinGrams >= goal.proteinGrams).length,
    );
  }

  /// The facts an AI feature may be sent. Plain numbers and fixed names
  /// only: no free text, no identifiers.
  Map<String, Object?> toJson() {
    double? oneDecimal(double? value) =>
        value == null ? null : (value * 10).roundToDouble() / 10;
    final nutrition = this.nutrition;
    final camp = this.camp;
    return {
      'date': '${date.year.toString().padLeft(4, '0')}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}',
      'training': {
        'sessionsToday': training.sessionsToday,
        'trainingDaysThisWeek': training.trainingDaysThisWeek,
        'plannedSessionsPerWeek': training.plannedSessionsPerWeek,
        'trainingDaysLast7Days': training.trainingDaysLast7Days,
        'minutesLast7Days': training.minutesLast7Days,
        'averageRpeLast7Days': oneDecimal(training.averageRpeLast7Days),
      },
      'nutrition': nutrition == null
          ? null
          : {
              'targetCalories': nutrition.targetCalories,
              'targetProteinGrams': nutrition.targetProteinGrams,
              'consumedCalories': nutrition.consumedCalories,
              'consumedProteinGrams': nutrition.consumedProteinGrams,
              'remainingCalories': nutrition.remainingCalories,
              'remainingProteinGrams': nutrition.remainingProteinGrams,
              'loggedDaysLast7Days': nutrition.loggedDaysLast7Days,
              'proteinTargetDaysLast7Days':
                  nutrition.proteinTargetDaysLast7Days,
            },
      'weight': {
        'trendKg': oneDecimal(weight.trendKg),
        'weeklyChangeKg': oneDecimal(weight.weeklyChangeKg),
        'weighInsLast7Days': weight.weighInsLast7Days,
      },
      'camp': camp == null
          ? null
          : {
              'phase': camp.phase.name,
              'daysToWeighIn': camp.daysToWeighIn,
              'daysToFight': camp.daysToFight,
              'weightLimitKg': oneDecimal(camp.weightLimitKg),
              'weightPathStatus': camp.weightPath.status.name,
              'weeklyLossKg': camp.weightPath.weeklyLossKg,
              'fightWeekEntryKg': camp.weightPath.fightWeekEntryKg,
            },
    };
  }
}
