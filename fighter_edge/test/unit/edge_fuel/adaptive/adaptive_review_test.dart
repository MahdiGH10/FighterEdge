import 'package:flutter_test/flutter_test.dart';

import 'package:fighter_edge/features/edge_fuel/domain/adaptive/adaptive_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/adaptive_review.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/calendar_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/data_tier.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/fuel_log_day.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/target_history.dart';
import 'package:fighter_edge/features/edge_fuel/domain/adaptive/weigh_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/nutrition_target_calculator_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/calculators/weekly_check_in.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_enums.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_profile.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/nutrition_target_v2.dart';
import 'package:fighter_edge/features/edge_fuel/domain/models/planned_fuel_session.dart';

final _today = CalendarDay(2026, 10, 22);
final _planStart = _today.plusDays(-28);

NutritionTargetV2 _formula({
  NutritionTargetStatus status = NutritionTargetStatus.success,
}) =>
    NutritionTargetV2(
      status: status,
      calculatedAt: DateTime(2026, 10, 22),
      estimatedRmrKcal: status == NutritionTargetStatus.success ? 1700 : null,
      maintenanceKcal: 2640,
      sessionEnergyKcalPerWeek: 1400,
      weeklyAverageCalories: 2200,
      minimumDailyKcal: 1700,
    );

List<FuelLogDay> _logs(double kcal, {int days = 28}) => [
      for (var d = 1; d <= days; d++)
        FuelLogDay(
          day: _today.plusDays(-d),
          intakeKcal: kcal,
          completeness: LoggingCompleteness.complete,
        ),
    ];

List<WeighIn> _flat({int days = 28, double kgPerWeek = 0}) => [
      for (var d = 1; d <= days; d++)
        WeighIn(day: _today.plusDays(-d), kg: 80 - kgPerWeek / 7 * d),
    ];

TargetHistory _history() => TargetHistoryReducer.reduce(
      TargetHistory.empty,
      PlanStarted(
        _planStart,
        goal: NutritionGoal.loseFat,
        targetKcal: 2200,
        policyVersion: 2,
      ),
    );

AdaptiveReviewInput _in({
  int? age = 30,
  NutritionTargetV2? formula,
  TargetHistory? history,
  List<FuelLogDay>? logs,
  List<WeighIn>? weighIns,
  NutritionGoal goal = NutritionGoal.loseFat,
}) =>
    AdaptiveReviewInput(
      today: _today,
      ageYears: age,
      goal: goal,
      plannedWeeklyChangePercent: 0.5,
      currentWeightKg: 80,
      formula: formula ?? _formula(),
      history: history ?? _history(),
      logDays: logs ?? _logs(2200),
      weighIns: weighIns ?? _flat(),
      lastSafetyScreenDay: _today.plusDays(-10),
    );

void main() {
  test('under 18 or unknown age: no targets, no proposals', () {
    for (final age in [null, 15]) {
      final r = AdaptiveTargets.review(_in(age: age));
      expect(r.decision.outcome, CheckInOutcome.notEligible);
      expect(r.decision.reasons, [CheckInReason.ageNotEligible]);
      expect(r.currentTargetKcal, isNull);
      expect(r.tier, isNull);
      expect(r.isStartingEstimate, isTrue);
    }
  });

  test('a clinical flag on the formula is a referral', () {
    final r = AdaptiveTargets.review(_in(
      formula: _formula(status: NutritionTargetStatus.needsProfessionalReview),
    ));
    expect(r.decision.outcome, CheckInOutcome.referral);
    expect(r.decision.reasons, [CheckInReason.clinicalReviewFlagged]);
  });

  test('a refused or broken formula holds with invalid input', () {
    final r = AdaptiveTargets.review(
      _in(formula: _formula(status: NutritionTargetStatus.unsupported)),
    );
    expect(r.decision.outcome, CheckInOutcome.hold);
    expect(r.decision.reasons, [CheckInReason.invalidInput]);
  });

  test('no history yet: the formula is a starting estimate', () {
    final r = AdaptiveTargets.review(_in(history: TargetHistory.empty));
    expect(r.currentTargetKcal, 2200);
    expect(r.tier!.tier, DataTier.tier0);
    expect(r.isStartingEstimate, isTrue);
    expect(r.decision.reasons, [CheckInReason.programTooNew]);
  });

  test('four steady weeks, no loss: one step down, then Apply', () {
    final r = AdaptiveTargets.review(_in());
    expect(r.tier!.tier, DataTier.tier2);
    expect(r.isStartingEstimate, isFalse);
    expect(r.slope.isUsable, isTrue);
    expect(r.observedWeeklyPercent, closeTo(0, 1e-9));
    // Flat weight on 2,200 a day: expenditure is about 2,200.
    expect(r.observedExpenditureKcal, closeTo(2200, 1e-6));
    expect(r.decision.outcome, CheckInOutcome.propose);
    expect(r.decision.reasons, [CheckInReason.slowerThanPlanned]);
    // Floor: max(1,700, 1,700 + 0.5 x 200) = 1,800.
    expect(r.decision.floorKcal, 1800);
    expect(r.decision.proposedTargetKcal, 2000);

    var h = TargetHistoryReducer.reduce(_history(), r.toEvent(_today));
    expect(h.pending!.proposal!.toKcal, 2000);
    h = TargetHistoryReducer.reduce(
      h,
      ProposalAnswered(_today, ProposalResponse.apply),
    );
    expect(h.targetOn(_today), 2000);

    // Asked again the same week: one change a week.
    final next = AdaptiveTargets.review(_in(history: h, logs: _logs(2000)));
    expect(next.decision.reasons, [CheckInReason.recentChange]);
  });

  test('losing on plan holds on pace', () {
    final r = AdaptiveTargets.review(_in(weighIns: _flat(kgPerWeek: -0.4)));
    expect(r.decision.reasons, [CheckInReason.onPace]);
    expect(r.observedWeeklyPercent, closeTo(-0.5, 1e-9));
  });

  test(
      'a maintenance goal has no ceiling and no observed expenditure '
      'below Tier 2', () {
    final r = AdaptiveTargets.review(_in(
      goal: NutritionGoal.maintain,
      logs: _logs(2200, days: 14),
      history: TargetHistoryReducer.reduce(
        TargetHistory.empty,
        PlanStarted(
          _today.plusDays(-14),
          goal: NutritionGoal.maintain,
          targetKcal: 2200,
          policyVersion: 2,
        ),
      ),
      weighIns: _flat(kgPerWeek: -0.4),
    ));
    expect(r.tier!.tier, DataTier.tier1);
    expect(r.observedExpenditureKcal, isNull);
    expect(r.decision.reasons, [CheckInReason.maintenanceDriftDown]);
  });

  test('works on a real policy-v2 formula', () {
    const profile = NutritionProfile(
      goal: NutritionGoal.loseFat,
      ageYears: 28,
      heightCm: 178,
      currentWeightKg: 80,
      targetWeightKg: 74,
      goalPace: GoalPace.standard,
      equationProfile: EquationProfile.higherOffset,
      activityLevel: ActivityLevel.moderate,
    );
    final formula = NutritionTargetCalculatorV2.calculate(
      profile,
      plannedWeek: const [
        PlannedFuelSession(
          dayIndex: 0,
          discipline: FuelDiscipline.boxing,
          intensity: FuelIntensity.moderate,
          durationMinutes: 60,
        ),
      ],
      now: DateTime(2026, 10, 22),
      enablePendingEnergyAvailabilityFloor: true,
    );
    expect(formula.isSuccess, isTrue);
    final target = formula.weeklyAverageCalories!;
    final r = AdaptiveTargets.review(AdaptiveReviewInput(
      today: _today,
      ageYears: profile.ageYears,
      goal: profile.goal,
      plannedWeeklyChangePercent: 0.5,
      currentWeightKg: 80,
      formula: formula,
      history: TargetHistory.empty,
      logDays: _logs(target.toDouble()),
      weighIns: _flat(),
    ));
    expect(r.currentTargetKcal, target);
    expect(r.decision.floorKcal,
        greaterThanOrEqualTo(formula.energyAvailabilityFloorKcal!));
    expect(r.decision.safetyReaskDue, isTrue);
  });
}
