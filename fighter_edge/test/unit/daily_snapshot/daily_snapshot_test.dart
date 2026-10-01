import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/camp_screening.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_week_plan.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_trend.dart';
import 'package:flutter_test/flutter_test.dart';

/// A Thursday; that week started on Monday 28 September.
final today = DateTime(2026, 10, 1, 20, 15);

TrainingRecord session(
  DateTime at, {
  int minutes = 60,
  int rpe = 0,
  bool counts = true,
}) =>
    TrainingRecord(
      completedAt: at,
      durationMinutes: minutes,
      rpe: rpe,
      countsAsTrainingDay: counts,
    );

final training = [
  session(DateTime(2026, 10, 1, 7), minutes: 60, rpe: 7),
  session(DateTime(2026, 10, 1, 18), minutes: 5, counts: false), // drill
  session(DateTime(2026, 9, 29), minutes: 90, rpe: 8),
  session(DateTime(2026, 9, 27), minutes: 45), // last week, still 7 days
  session(DateTime(2026, 9, 24), minutes: 60), // 7 days ago: outside
  session(DateTime(2026, 10, 2), minutes: 60), // tomorrow: ignored
];

final nutritionDays = [
  NutritionDayTotals(
      date: DateTime(2026, 10, 1), calories: 1220, proteinGrams: 74),
  NutritionDayTotals(
      date: DateTime(2026, 9, 30), calories: 2250, proteinGrams: 165),
  NutritionDayTotals(
      date: DateTime(2026, 9, 29), calories: 2400, proteinGrams: 160),
  NutritionDayTotals(date: DateTime(2026, 9, 25), calories: 0, proteinGrams: 0),
  NutritionDayTotals(
      date: DateTime(2026, 9, 24), calories: 2000, proteinGrams: 170),
];

const goal = NutritionGoal(calories: 2300, proteinGrams: 160);

DailySnapshot build({
  NutritionGoal? nutritionGoal = goal,
  List<WeightPoint> weights = const [],
  FightCamp? camp,
}) =>
    DailySnapshot.build(
      today: today,
      training: training,
      plannedSessionsPerWeek: 4,
      goal: nutritionGoal,
      nutritionDays: nutritionDays,
      weights: weights,
      camp: camp,
      ageYears: 30,
      screening: CampScreening.cleared,
    );

void main() {
  test('training: this week, the last 7 days, and effort', () {
    final t = build().training;
    expect(t.sessionsToday, 2);
    expect(t.trainingDaysThisWeek, 2);
    expect(t.plannedSessionsPerWeek, 4);
    expect(t.trainingDaysLast7Days, 3);
    expect(t.minutesLast7Days, 200);
    expect(t.averageRpeLast7Days, 7.5);
  });

  test('nutrition: today against the target, and the week', () {
    final n = build().nutrition!;
    expect(n.consumedCalories, 1220);
    expect(n.remainingCalories, 1080);
    expect(n.remainingProteinGrams, 86);
    expect(n.loggedDaysLast7Days, 3);
    expect(n.proteinTargetDaysLast7Days, 2);
  });

  test('no target yet means no nutrition summary', () {
    expect(build(nutritionGoal: null).nutrition, isNull);
  });

  test('no fight means no camp summary', () {
    expect(build().camp, isNull);
  });

  test('a fight adds the phase and a weight path from the trend weight', () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 78),
      weighInDate: addDays(today, 77),
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
      campWeeks: 12,
    )!;
    final snapshot = build(
      camp: camp,
      weights: [
        WeightPoint(addDays(today, -1), 80.4),
        WeightPoint(today, 79.6),
      ],
    );
    expect(snapshot.weight.trendKg, closeTo(80.0, 1e-9));
    final c = snapshot.camp!;
    expect(c.phase, CampPhase.camp);
    expect(c.daysToWeighIn, 77);
    expect(c.daysToFight, 78);
    expect(c.weightPath.status, WeightPathStatus.onTrack);
    expect(c.weightPath.weeklyLossKg, 0.5);
    expect(c.fightWeekCut, FightWeekCut.lowFibreAndCarbs,
        reason: 'the planned 2% for fight week');
    expect(c.todaySteps, isEmpty, reason: 'fight week is 10 weeks away');
  });

  test("in fight week the camp carries today's steps", () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 4),
      weighInDate: addDays(today, 3),
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
    )!;
    // 75.0 kg on the first day of fight week: 2% to go, food only.
    final weights = [
      WeightPoint(addDays(today, -5), 75.2),
      WeightPoint(addDays(today, -4), 74.8),
    ];
    final snapshot = DailySnapshot.build(
      today: today,
      training: training,
      plannedSessionsPerWeek: 4,
      goal: goal,
      nutritionDays: nutritionDays,
      weights: weights,
      camp: camp,
      ageYears: 30,
      screening: CampScreening.cleared,
    );
    expect(snapshot.camp!.todaySteps,
        [FightWeekStep.lowFibre, FightWeekStep.lowerCarbs]);
    final json = snapshot.toJson()['camp'] as Map<String, Object?>;
    expect(json['phase'], 'fightWeek');
    expect(json['fightWeekCut'], 'lowFibreAndCarbs');
    expect(json['todaySteps'], ['lowFibre', 'lowerCarbs']);
  });

  test('the refuel step reaches the AI only when refuel guidance is on', () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 1),
      weighInDate: today,
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
    )!;
    // Weigh-in day, 74.0 kg trend: under 1% to lose, food only.
    DailySnapshot onWeighInDay({bool? refuelGuidance}) => DailySnapshot.build(
          today: today,
          training: training,
          plannedSessionsPerWeek: 4,
          goal: goal,
          nutritionDays: nutritionDays,
          weights: [
            WeightPoint(addDays(today, -1), 74.2),
            WeightPoint(today, 73.8),
          ],
          camp: camp,
          ageYears: 30,
          screening: CampScreening.cleared,
          refuelGuidance: refuelGuidance ?? false,
        );

    final off = onWeighInDay();
    expect(off.camp!.fightWeekCut, FightWeekCut.lowFibre);
    expect(off.camp!.todaySteps, [FightWeekStep.weighIn]);
    expect((off.toJson()['camp'] as Map)['todaySteps'], ['weighIn']);

    final on = onWeighInDay(refuelGuidance: true);
    expect(on.camp!.todaySteps, [FightWeekStep.weighIn, FightWeekStep.refuel]);
    expect((on.toJson()['camp'] as Map)['todaySteps'], ['weighIn', 'refuel']);
  });

  test('no fight-week plan for a minor', () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 3),
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
    )!;
    final snapshot = DailySnapshot.build(
      today: today,
      training: training,
      plannedSessionsPerWeek: 4,
      goal: goal,
      nutritionDays: nutritionDays,
      weights: [WeightPoint(today, 75)],
      camp: camp,
      ageYears: 17,
    );
    expect(snapshot.camp!.fightWeekCut, isNull);
    expect(snapshot.camp!.todaySteps, isEmpty);
    expect((snapshot.toJson()['camp'] as Map)['todaySteps'], isEmpty);
  });

  test('AI snapshot has no camp prescription without confirmed screening', () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 4),
      weighInDate: addDays(today, 3),
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
    )!;
    final snapshot = DailySnapshot.build(
      today: today,
      training: training,
      plannedSessionsPerWeek: 4,
      goal: goal,
      nutritionDays: nutritionDays,
      weights: [WeightPoint(today, 75)],
      camp: camp,
    );
    final facts = snapshot.toJson()['camp'] as Map<String, Object?>;
    expect(facts['weightPathStatus'], 'needsScreening');
    expect(facts['fightWeekCut'], isNull);
    expect(facts['todaySteps'], isEmpty);
  });

  test('without a recent weigh-in the path asks for data', () {
    final camp = FightCamp.tryCreate(
      fightDate: addDays(today, 40),
      weightLimitKg: 73.5,
      category: CompetitionCategory.professional,
    )!;
    final snapshot = build(
      camp: camp,
      weights: [WeightPoint(addDays(today, -10), 80)],
    );
    expect(snapshot.camp!.weightPath.status, WeightPathStatus.needsMoreData);
  });

  test('facts for the AI are numbers and fixed names only', () {
    final json = build().toJson();
    expect(json['date'], '2026-10-01');
    expect(json['training'], containsPair('averageRpeLast7Days', 7.5));
    expect(json['nutrition'], containsPair('remainingCalories', 1080));
    expect(json['weight'], containsPair('trendKg', null));
    expect(json['camp'], isNull);
  });
}
