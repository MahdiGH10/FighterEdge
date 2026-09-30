import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/corner_brief/domain/corner_brief.dart';
import 'package:fighter_edge/features/daily_snapshot/domain/daily_snapshot.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/food_log_entry.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target.dart';
import 'package:fighter_edge/features/fight_camp/domain/calendar.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_camp.dart';
import 'package:fighter_edge/features/fight_camp/domain/fight_week_plan.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_cut_policy.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_path.dart';
import 'package:fighter_edge/features/fight_camp/domain/weight_trend.dart';

final _today = DateTime(2026, 10, 1, 12);

final _target = NutritionTarget(
  status: NutritionTargetStatus.success,
  policyVersion: 1,
  calculatedAt: DateTime(2026, 1, 1),
  targetCalories: 2400,
  proteinGrams: 180,
  carbGrams: 280,
  fatGrams: 70,
);

DailySnapshot _snapshot({
  SessionKind? plannedToday,
  bool plannedTodayDone = false,
  FightCamp? camp,
  List<WeightPoint> weights = const [],
}) =>
    DailySnapshot.build(
      today: _today,
      training: const [],
      plannedSessionsPerWeek: 4,
      plannedToday: plannedToday,
      plannedTodayDone: plannedTodayDone,
      goal: null,
      nutritionDays: const [],
      weights: weights,
      camp: camp,
    );

NutritionDay _day({
  int calories = 0,
  int protein = 0,
  int carbs = 0,
  int fats = 0,
  bool consumed = true,
}) {
  final entry = FoodLogEntry(
    id: 'entry',
    name: 'Fixture meal',
    notes: 'fixture',
    calories: calories,
    proteinGrams: protein,
    carbGrams: carbs,
    fatGrams: fats,
    consumed: consumed,
    loggedAt: _today,
  );
  return NutritionDay(
    localDate: '2026-10-01',
    timeZone: 'UTC',
    entries: [entry],
    totals: FoodLogTotals.fromEntries([entry]),
    createdAt: _today,
    updatedAt: _today,
  );
}

// Protein is the gap: 100 of 180 g left.
NutritionDay _proteinGap() =>
    _day(calories: 1200, protein: 80, carbs: 200, fats: 40);

// Carbs are the gap: 180 of 280 g left, protein and calories nearly there.
NutritionDay _carbGap() =>
    _day(calories: 1900, protein: 170, carbs: 100, fats: 60);

// Calories are the gap only.
NutritionDay _calorieGap() =>
    _day(calories: 1500, protein: 170, carbs: 250, fats: 30);

NutritionDay _onTrackDay() =>
    _day(calories: 2300, protein: 175, carbs: 270, fats: 68);

void main() {
  group('CornerBriefCalculator', () {
    test('asks for a target before anything else', () {
      final line = CornerBriefCalculator.line(
        today: _snapshot(),
        target: null,
        day: null,
      );
      expect(line, const CornerLine(CornerCue.setUpFuel));
    });

    test('asks for a first meal when nothing eaten is logged', () {
      expect(
        CornerBriefCalculator.line(
          today: _snapshot(),
          target: _target,
          day: null,
        ),
        const CornerLine(CornerCue.firstMeal),
      );
      expect(
        CornerBriefCalculator.line(
          today: _snapshot(),
          target: _target,
          day: _day(calories: 500, consumed: false),
        ),
        const CornerLine(CornerCue.firstMeal),
      );
    });

    test('names the protein gap with the grams left', () {
      final line = CornerBriefCalculator.line(
        today: _snapshot(),
        target: _target,
        day: _proteinGap(),
      );
      expect(line, const CornerLine(CornerCue.protein, amount: 100));
    });

    test('asks for carbs before a session that is still to come', () {
      final line = CornerBriefCalculator.line(
        today: _snapshot(plannedToday: SessionKind.wrestling),
        target: _target,
        day: _carbGap(),
      );
      expect(line.cue, CornerCue.carbsBeforeTraining);
      expect(line.amount, 180);
    });

    test('a finished or missing session means plain carbs', () {
      for (final today in [
        _snapshot(),
        _snapshot(plannedToday: SessionKind.wrestling, plannedTodayDone: true),
      ]) {
        final line = CornerBriefCalculator.line(
          today: today,
          target: _target,
          day: _carbGap(),
        );
        expect(line.cue, CornerCue.carbs);
        expect(line.amount, 180);
      }
    });

    test('names the calorie gap', () {
      final line = CornerBriefCalculator.line(
        today: _snapshot(),
        target: _target,
        day: _calorieGap(),
      );
      expect(line.cue, CornerCue.calories);
      expect(line.amount, 900);
    });

    test('is on track close to every target', () {
      final line = CornerBriefCalculator.line(
        today: _snapshot(),
        target: _target,
        day: _onTrackDay(),
      );
      expect(line, const CornerLine(CornerCue.onTrack));
    });

    test('does not call a fight-week lower-carb day a carb gap', () {
      final camp = FightCamp.tryCreate(
        fightDate: addDays(_today, 4),
        weighInDate: addDays(_today, 3),
        weightLimitKg: 73.5,
        category: CompetitionCategory.professional,
      )!;
      final snapshot = _snapshot(camp: camp, weights: [
        WeightPoint(addDays(_today, -5), 75.2),
        WeightPoint(addDays(_today, -4), 74.8),
      ]);
      expect(snapshot.camp!.todaySteps, contains(FightWeekStep.lowerCarbs));
      final line = CornerBriefCalculator.line(
        today: snapshot,
        target: _target,
        day: _carbGap(),
      );
      expect(line, const CornerLine(CornerCue.onTrack));
    });

    test('sends the athlete to a professional before any food cue', () {
      final camp = FightCamp.tryCreate(
        fightDate: addDays(_today, 5),
        weighInDate: addDays(_today, 4),
        weightLimitKg: 73.5,
        category: CompetitionCategory.professional,
      )!;
      final snapshot = _snapshot(
        camp: camp,
        weights: [WeightPoint(_today, 82)],
      );
      expect(
        snapshot.camp!.weightPath.status,
        anyOf(WeightPathStatus.needsSupervision, WeightPathStatus.notSafe),
      );
      final line = CornerBriefCalculator.line(
        today: snapshot,
        target: _target,
        day: _proteinGap(),
      );
      expect(line, const CornerLine(CornerCue.seeProfessional));
    });
  });

  group('cornerBriefBasis', () {
    test('is stable for the same day and log', () {
      final a = cornerBriefBasis(_snapshot(), _proteinGap());
      final b = cornerBriefBasis(_snapshot(), _proteinGap());
      expect(a, b);
    });

    test('changes when something is logged, or a session is planned', () {
      final base = cornerBriefBasis(_snapshot(), _proteinGap());
      expect(cornerBriefBasis(_snapshot(), _carbGap()), isNot(base));
      expect(cornerBriefBasis(_snapshot(), null), isNot(base));
      expect(
        cornerBriefBasis(
            _snapshot(plannedToday: SessionKind.bjj), _proteinGap()),
        isNot(base),
      );
      expect(
        cornerBriefBasis(
          _snapshot(plannedToday: SessionKind.bjj, plannedTodayDone: true),
          _proteinGap(),
        ),
        isNot(cornerBriefBasis(
            _snapshot(plannedToday: SessionKind.bjj), _proteinGap())),
      );
    });
  });
}
