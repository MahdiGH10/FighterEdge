import '../calculators/weekly_check_in.dart';
import '../models/nutrition_enums.dart';
import '../models/nutrition_target_v2.dart';
import 'adaptive_check_in.dart';
import 'calendar_day.dart';
import 'data_tier.dart';
import 'fuel_log_day.dart';
import 'target_history.dart';
import 'weigh_in.dart';
import 'weight_slope.dart';

/// Everything the weekly review needs, as plain values. The caller reads the
/// stores and the clock; this file does neither.
class AdaptiveReviewInput {
  const AdaptiveReviewInput({
    required this.today,
    required this.ageYears,
    required this.goal,
    required this.plannedWeeklyChangePercent,
    required this.currentWeightKg,
    required this.formula,
    required this.history,
    required this.logDays,
    required this.weighIns,
    this.lastSafetyScreenDay,
    this.lossGoalStartedOn,
    this.loggingSelfReport,
    this.inFightWeek = false,
    this.inFightCamp = false,
  });

  /// The review day. Data runs to the day before, the last closed day.
  final CalendarDay today;

  /// Null when unknown.
  final int? ageYears;
  final NutritionGoal goal;

  /// Positive percent of body weight per week; the goal gives the direction.
  final double plannedWeeklyChangePercent;
  final double currentWeightKg;

  /// Today's policy-v2 formula result. It gives resting energy, maintenance,
  /// session energy and the floors; the history gives the target in force.
  final NutritionTargetV2 formula;
  final TargetHistory history;
  final List<FuelLogDay> logDays;
  final List<WeighIn> weighIns;
  final CalendarDay? lastSafetyScreenDay;
  final CalendarDay? lossGoalStartedOn;
  final LoggingSelfReport? loggingSelfReport;
  final bool inFightWeek;
  final bool inFightCamp;
}

/// One weekly review: the facts and the single decision. The weekly review
/// screen and the check-in are the same thing.
class AdaptiveReview {
  const AdaptiveReview({
    required this.decision,
    required this.slope,
    this.tier,
    this.currentTargetKcal,
    this.observedWeeklyPercent,
    this.observedExpenditureKcal,
  });

  final AdaptiveCheckInDecision decision;

  /// Null when there is no target at all (not eligible, no formula).
  final DataTierAssessment? tier;
  final WeightSlope slope;

  /// The target in force today; null when there is none.
  final int? currentTargetKcal;

  /// The trend, signed percent of body weight per week.
  final double? observedWeeklyPercent;

  /// Tier 2 only: mean counted intake over 21 days minus the trend's stored
  /// energy. Shown next to the formula maintenance; never applied by itself.
  final double? observedExpenditureKcal;

  /// Tier 0: the target is a formula starting estimate.
  bool get isStartingEstimate =>
      (tier?.tier ?? DataTier.tier0) == DataTier.tier0;

  /// The event to store once the review was shown.
  CheckInShown toEvent(CalendarDay day) => CheckInShown(
        day,
        decision: decision,
        observedWeeklyPercent: observedWeeklyPercent,
      );
}

/// The domain API for adaptive targets (Fuel V2 slice N1). Pure: no clock,
/// no storage, no UI. Wiring belongs to a later slice.
class AdaptiveTargets {
  const AdaptiveTargets._();

  static AdaptiveReview review(AdaptiveReviewInput i) {
    AdaptiveReview without(
      CheckInOutcome outcome,
      CheckInReason reason,
    ) =>
        AdaptiveReview(
          decision: AdaptiveCheckInDecision(
            outcome: outcome,
            deltaKcal: 0,
            proposedTargetKcal: 0,
            reasons: [reason],
            tier: DataTier.tier0,
            floorKcal: 0,
            safetyReaskDue: false,
          ),
          slope: const WeightSlope.none(),
        );

    if (!AdaptiveWeeklyCheckIn.isEligibleAge(i.ageYears)) {
      return without(CheckInOutcome.notEligible, CheckInReason.ageNotEligible);
    }
    final f = i.formula;
    if (f.status == NutritionTargetStatus.needsProfessionalReview) {
      return without(
        CheckInOutcome.referral,
        CheckInReason.clinicalReviewFlagged,
      );
    }
    final rmr = f.estimatedRmrKcal;
    final minimum = f.minimumDailyKcal;
    final current = i.history.targetOn(i.today) ?? f.weeklyAverageCalories;
    if (!f.isSuccess || rmr == null || minimum == null || current == null) {
      return without(CheckInOutcome.hold, CheckInReason.invalidInput);
    }

    final asOf = i.today.plusDays(-1);
    final planStart = i.history.planStartOn(i.today) ?? i.today;
    final tier = DataTierEvaluator.evaluate(
      asOf: asOf,
      targetStart: planStart,
      targetKcal: current.toDouble(),
      logDays: i.logDays,
      weighIns: i.weighIns,
    );
    final slope = WeightSlopeCalculator.best(i.weighIns, today: asOf);
    final maintenance = f.maintenanceKcal?.toDouble();

    final decision = AdaptiveWeeklyCheckIn.decide(
      AdaptiveCheckInInput(
        today: i.today,
        ageYears: i.ageYears,
        goal: i.goal,
        currentTargetKcal: current.toDouble(),
        minimumKcal: minimum.toDouble(),
        maximumKcal: i.goal == NutritionGoal.loseFat ? maintenance : null,
        maintenanceKcal: maintenance,
        currentWeightKg: i.currentWeightKg,
        plannedWeeklyChangePercent: i.plannedWeeklyChangePercent,
        restingEnergyKcal: rmr.toDouble(),
        averageSessionKcalPerDay: (f.sessionEnergyKcalPerWeek ?? 0) / 7,
        tier: tier,
        slope: slope,
        inFightWeek: i.inFightWeek,
        inFightCamp: i.inFightCamp,
        lastTargetChangeDay: i.history.lastChangeOn(i.today),
        previousObservedWeeklyPercent:
            i.history.previousObservedWeeklyPercent(i.today),
        loggingSelfReport: i.loggingSelfReport,
        continuousDeficitWeeks: i.history.continuousDeficitWeeks(i.today),
        maintenanceOfferRecentlyDeclined:
            i.history.maintenanceOfferDeclinedWithin(i.today),
        lastSafetyScreenDay: i.lastSafetyScreenDay,
        lossGoalStartedOn: i.lossGoalStartedOn,
      ),
    );

    final observed = decision.observedKgPerWeek;
    final weightOk = i.currentWeightKg.isFinite && i.currentWeightKg > 0;
    final mean21 = LoggingSummary.window(
      i.logDays,
      endDay: asOf,
      targetKcal: current.toDouble(),
      length: 21,
    ).averageIntakeKcal;
    return AdaptiveReview(
      decision: decision,
      tier: tier,
      slope: slope,
      currentTargetKcal: current,
      observedWeeklyPercent: observed == null || !weightOk
          ? null
          : observed / i.currentWeightKg * 100,
      observedExpenditureKcal: ObservedExpenditure.kcalPerDay(
        tier: tier.tier,
        meanIntakeKcal: mean21,
        slope: slope,
      ),
    );
  }
}
