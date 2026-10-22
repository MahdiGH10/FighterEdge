import '../calculators/weekly_check_in.dart';
import '../models/nutrition_enums.dart';
import '../policies/energy_availability_proxy.dart';
import '../policies/nutrition_policy_v2.dart';
import '../policies/weight_rate_policy.dart';
import 'calendar_day.dart';
import 'data_tier.dart';
import 'safety_reask.dart';
import 'weight_slope.dart';

/// What the check-in recommends. It only ever recommends: nothing changes
/// until the user taps Apply (Fuel V2 spec, rule 2).
enum CheckInOutcome {
  /// No change. The reason says why.
  hold,

  /// One calorie step, up or down, with a reason.
  propose,

  /// No number change at all. Supportive "talk to a professional" copy. Never
  /// a bigger cut, never a number of any kind.
  referral,

  /// An optional week at estimated maintenance, for training quality and
  /// hunger. Not a metabolic reset.
  offerMaintenanceWeek,
}

/// The user's own answer to "how complete was your logging?".
enum LoggingSelfReport { all, most, some, none }

/// The week's inputs. All energy is kcal per day, as a weekly average.
class AdaptiveCheckInInput {
  const AdaptiveCheckInInput({
    required this.today,
    required this.goal,
    required this.currentTargetKcal,
    required this.minimumKcal,
    required this.currentWeightKg,
    required this.plannedWeeklyChangePercent,
    required this.restingEnergyKcal,
    required this.tier,
    required this.slope,
    required this.lastSafetyScreenDay,
    this.maximumKcal,
    this.maintenanceKcal,
    this.averageSessionKcalPerDay = 0,
    this.inFightWeek = false,
    this.inFightCamp = false,
    this.lastTargetChangeDay,
    this.previousObservedWeeklyPercent,
    this.loggingSelfReport,
    this.continuousDeficitWeeks = 0,
    this.maintenanceOfferRecentlyDeclined = false,
    this.lossGoalStartedOn,
  });

  /// The last closed day: the check-in is computed as of the end of it.
  final CalendarDay today;
  final NutritionGoal goal;

  /// The weekly-average target the user is held to.
  final double currentTargetKcal;

  /// `NutritionTargetV2.minimumDailyKcal`.
  final double minimumKcal;

  /// The highest the target may go; null for no ceiling. While losing fat
  /// this is estimated maintenance.
  final double? maximumKcal;

  /// Estimated maintenance, for an optional maintenance week; null when
  /// unknown (then none is offered).
  final double? maintenanceKcal;
  final double currentWeightKg;

  /// The pace the user chose, a positive percent of body weight per week
  /// (zero for maintenance). The goal gives the direction. A loss above the
  /// policy cap is clamped to the cap before the check-in uses it.
  final double plannedWeeklyChangePercent;

  /// Estimated resting energy (`NutritionTargetV2.estimatedRmrKcal`).
  final double restingEnergyKcal;

  /// Average planned session energy per day, for the energy-availability
  /// floor. Zero for no planned training.
  final double averageSessionKcalPerDay;

  final DataTierAssessment tier;

  /// `WeightSlopeCalculator.best`.
  final WeightSlope slope;
  final bool inFightWeek;

  /// Inside a fight-camp path: the loss cap is the camp's 1%, not 0.75%.
  final bool inFightCamp;

  /// The day the last target change was applied; null when none.
  final CalendarDay? lastTargetChangeDay;

  /// The observed weekly change, in percent of body weight, at the previous
  /// check-in (negative is losing); null when there was none.
  final double? previousObservedWeeklyPercent;
  final LoggingSelfReport? loggingSelfReport;

  /// Weeks of continuous deficit with no maintenance week
  /// (`TargetHistory.continuousDeficitWeeks`).
  final int continuousDeficitWeeks;

  /// An optional maintenance week was offered and declined recently
  /// (`TargetHistory.maintenanceOfferDeclinedWithin`): no nagging.
  final bool maintenanceOfferRecentlyDeclined;

  /// When the safety questions were last answered; null when never.
  final CalendarDay? lastSafetyScreenDay;

  /// When the current loss goal started, if it did after the last answer.
  final CalendarDay? lossGoalStartedOn;
}

/// The check-in outcome with the numbers behind it, so a screen can say why in
/// one line. Copy lives in the UI; this holds codes and keys only.
class AdaptiveCheckInDecision {
  const AdaptiveCheckInDecision({
    required this.outcome,
    required this.deltaKcal,
    required this.proposedTargetKcal,
    required this.reasons,
    required this.tier,
    required this.floorKcal,
    required this.safetyReaskDue,
    this.observedKgPerWeek,
    this.plannedKgPerWeek,
    this.errorKgPerWeek,
    this.correctionKcalPerDay,
    this.stepKcal,
    this.deadBandKgPerWeek,
    this.maintenanceWeekDays,
  });

  final CheckInOutcome outcome;

  /// Signed kcal per day; 0 for a hold or a referral.
  final int deltaKcal;

  /// The target after the change; the current target for a hold or referral.
  final int proposedTargetKcal;

  /// At least one code, always.
  final List<CheckInReason> reasons;
  final DataTier tier;

  /// The lowest weekly-average target allowed:
  /// `max(minimum, resting + 0.5 x session energy)`.
  final int floorKcal;

  /// The 8-week safety questions are due. The UI asks them.
  final bool safetyReaskDue;

  /// kg per week, signed (negative is losing). Null when no slope was used.
  final double? observedKgPerWeek;
  final double? plannedKgPerWeek;

  /// `observed - planned`; positive means heavier than the plan.
  final double? errorKgPerWeek;

  /// `-1,100 x error`, before damping and clamping.
  final double? correctionKcalPerDay;

  /// `clamp(round10(0.5 x |correction|), 100, 200)`.
  final int? stepKcal;

  /// The error band inside which the plan counts as on pace.
  final double? deadBandKgPerWeek;

  /// 7 for [CheckInOutcome.offerMaintenanceWeek], otherwise null.
  final int? maintenanceWeekDays;

  /// A change the user may Apply: a calorie step or a maintenance week.
  bool get isProposal =>
      outcome == CheckInOutcome.propose ||
      outcome == CheckInOutcome.offerMaintenanceWeek;

  bool get isReferral => outcome == CheckInOutcome.referral;

  /// A neutral copy key for the outcome, such as
  /// `fuel.checkIn.hold.onPace`. The UI maps keys to words; the domain never
  /// holds a user-facing string.
  String get copyKey => '$copyKeyPrefix.${outcome.name}.${reasons.first.name}';

  /// One key per reason, same format.
  List<String> get copyKeys => [
        for (final r in reasons) '$copyKeyPrefix.${outcome.name}.${r.name}',
      ];

  static const String copyKeyPrefix = 'fuel.checkIn';
}

/// The deterministic weekly decision (Fuel V2 slice N1). Pure: no clock, no
/// storage, no UI. All thresholds are implementation defaults pending
/// dietitian sign-off (see [signOffPending]).
///
/// ```text
/// planned    = signed rate x weight / 100              (kg/week)
/// observed   = OLS slope over 21 days x 7              (kg/week)
/// error      = observed - planned                      (positive: too heavy)
/// correction = -1,100 x error                          (kcal/day)
/// step       = clamp(round10(0.5 x |correction|), 100, 200)
/// ```
///
/// Order of rules (first match wins), each ending in a reason code:
///
/// 1. invalid input; fight week (the camp plan owns the numbers);
/// 2. SAFETY: logged intake under resting energy two weeks running, or a loss
///    above 1% of body weight a week two check-ins running, gives a
///    [CheckInOutcome.referral]: no number changes, never a bigger cut;
/// 3. one change a week;
/// 4. 10 or more weeks of continuous deficit: optional maintenance week;
/// 5. data gates: Tier 0, partial logging, no usable slope, implausible
///    change, a loss above 1% (hold), intake off target;
/// 6. inside the error band: on pace;
/// 7. otherwise one damped, clamped step; a cut never goes below the floor
///    and never happens while the safety questions are overdue; at the floor
///    the next step is a maintenance week, not a lower number.
class AdaptiveWeeklyCheckIn {
  const AdaptiveWeeklyCheckIn._();

  /// Every number below is a placeholder until a sports dietitian reviews it.
  static const bool signOffPending = true;

  static const double kcalPerKgPerWeekPerDay = WeightRatePolicy.kcalPerKg / 7;
  static const double correctionDamping = 0.5;
  static const int minStepKcal = 100;
  static const int maxStepKcal = 200;

  /// Error band: at least this share of the planned rate, at least this many
  /// kg a week, and never narrower than the measured noise band.
  static const double deadBandPlannedFraction = 0.25;
  static const double deadBandMinKgPerWeek = 0.1;

  /// Average logged intake and the target must be this close for the week to
  /// say anything about the plan.
  static const double adherenceTolerance = 0.10;

  /// A weekly change beyond this share of body weight is not tissue.
  static const double implausibleChangePercent = 2.0;

  /// Loss faster than this share of body weight a week is a safety signal.
  static const double veryFastLossPercent = 1.0;

  /// Days a logged week needs to count as "enough" in the safety rule.
  static const int lowIntakeMinDaysPerWeek = 5;

  /// Weeks of continuous deficit after which a maintenance week is offered.
  static const int deficitWeeksBeforeMaintenanceOffer = 10;

  /// A target changed within this many days is not changed again.
  static const int minDaysBetweenChanges = 7;

  static const int maintenanceWeekDays = 7;

  static AdaptiveCheckInDecision decide(AdaptiveCheckInInput i) {
    final valid = _valid(i);
    final current = valid ? i.currentTargetKcal.round() : 0;
    final eaFloor = valid
        ? EnergyAvailabilityProxy.floorKcal(
            restingEnergyKcal: i.restingEnergyKcal,
            averageSessionKcalPerDay: i.averageSessionKcalPerDay,
          )
        : 0;
    final floor = valid
        ? (NutritionPolicyV2.ceilToTen(i.minimumKcal) > eaFloor
            ? NutritionPolicyV2.ceilToTen(i.minimumKcal)
            : eaFloor)
        : 0;
    final reaskDue = valid &&
        SafetyReask.isDue(
          lastAnsweredOn: i.lastSafetyScreenDay,
          today: i.today,
          lossGoalStartedOn: i.lossGoalStartedOn,
        );

    final observedKg = valid ? i.slope.slopeKgPerWeek : null;
    final observedPercent =
        observedKg == null ? null : observedKg / i.currentWeightKg * 100;

    AdaptiveCheckInDecision make(
      CheckInOutcome outcome,
      List<CheckInReason> reasons, {
      int? target,
      double? planned,
      double? error,
      double? correction,
      int? step,
      double? band,
      int? weekDays,
    }) =>
        AdaptiveCheckInDecision(
          outcome: outcome,
          deltaKcal: (target ?? current) - current,
          proposedTargetKcal: target ?? current,
          reasons: reasons,
          tier: i.tier.tier,
          floorKcal: floor,
          safetyReaskDue: reaskDue,
          observedKgPerWeek: observedKg,
          plannedKgPerWeek: planned,
          errorKgPerWeek: error,
          correctionKcalPerDay: correction,
          stepKcal: step,
          deadBandKgPerWeek: band,
          maintenanceWeekDays: weekDays,
        );
    AdaptiveCheckInDecision hold(CheckInReason reason) =>
        make(CheckInOutcome.hold, [reason]);

    // 1. Invalid input and fight week.
    if (!valid) return hold(CheckInReason.invalidInput);
    if (i.inFightWeek) return hold(CheckInReason.fightWeek);

    // 2. Safety escalation: a referral, never a number.
    if (_lowIntakeTwoWeeks(i)) {
      return make(CheckInOutcome.referral, [CheckInReason.lowIntakeSafety]);
    }
    final fastLoss =
        observedPercent != null && observedPercent < -veryFastLossPercent;
    final previous = i.previousObservedWeeklyPercent;
    if (fastLoss && previous != null && previous < -veryFastLossPercent) {
      return make(CheckInOutcome.referral, [CheckInReason.lossAboveCap]);
    }

    // 3. One change a week.
    final last = i.lastTargetChangeDay;
    if (last != null && last.daysUntil(i.today) < minDaysBetweenChanges) {
      return hold(CheckInReason.recentChange);
    }

    // 4. Long deficit: an optional maintenance week.
    if (i.goal == NutritionGoal.loseFat &&
        !i.inFightCamp &&
        i.continuousDeficitWeeks >= deficitWeeksBeforeMaintenanceOffer &&
        !i.maintenanceOfferRecentlyDeclined) {
      final week = _maintenanceWeekTarget(i, current);
      if (week != null) {
        return make(
          CheckInOutcome.offerMaintenanceWeek,
          [CheckInReason.deficitDurationReached],
          target: week,
          weekDays: maintenanceWeekDays,
        );
      }
    }

    // 5. Data gates.
    if (!i.tier.mayPropose) {
      final reasons = i.tier.reasons.isEmpty
          ? const [CheckInReason.programTooNew]
          : i.tier.reasons;
      return make(CheckInOutcome.hold, reasons);
    }
    final report = i.loggingSelfReport;
    if (i.tier.thisWeek.partialDays > 0 ||
        report == LoggingSelfReport.some ||
        report == LoggingSelfReport.none) {
      return hold(CheckInReason.partialLoggingFlagged);
    }
    if (!i.slope.isUsable || observedKg == null || observedPercent == null) {
      return hold(CheckInReason.insufficientWeighIns);
    }
    if (observedPercent.abs() > implausibleChangePercent) {
      return hold(CheckInReason.implausibleWeightChange);
    }
    if (fastLoss) return hold(CheckInReason.lossAboveCap);
    final intake = i.tier.thisWeek.averageIntakeKcal;
    if (intake == null) return hold(CheckInReason.insufficientLogging);
    if ((intake - i.currentTargetKcal).abs() / i.currentTargetKcal >
        adherenceTolerance) {
      return hold(CheckInReason.intakeOffTarget);
    }

    // 6. Plan against slope.
    final plannedPercent = _plannedPercent(i);
    final planned = plannedPercent * i.currentWeightKg / 100;
    final error = observedKg - planned;
    final band = _max(
      _max(deadBandPlannedFraction * planned.abs(),
          i.slope.noiseBandKgPerWeek ?? 0),
      deadBandMinKgPerWeek,
    );
    AdaptiveCheckInDecision withNumbers(
      CheckInOutcome outcome,
      List<CheckInReason> reasons, {
      int? target,
      double? correction,
      int? step,
      int? weekDays,
    }) =>
        make(
          outcome,
          reasons,
          target: target,
          planned: planned,
          error: error,
          correction: correction,
          step: step,
          band: band,
          weekDays: weekDays,
        );
    if (error.abs() <= band) {
      return withNumbers(CheckInOutcome.hold, [CheckInReason.onPace]);
    }

    // 7. One damped, clamped step.
    final correction = -kcalPerKgPerWeekPerDay * error;
    final step = _stepFor(correction);
    final wantsLess = correction < 0;
    final reason = _reasonFor(i.goal, wantsLess);

    if (wantsLess) {
      if (reaskDue) {
        return withNumbers(
          CheckInOutcome.hold,
          [CheckInReason.safetyReaskDue],
          correction: correction,
          step: step,
        );
      }
      final bounded = _max((current - step).toDouble(), floor.toDouble());
      var target = NutritionPolicyV2.ceilToTen(bounded);
      if (target > current) target = current;
      if (current - target < minStepKcal) {
        final week = i.goal == NutritionGoal.loseFat && !i.inFightCamp
            ? _maintenanceWeekTarget(i, current)
            : null;
        if (week != null && !i.maintenanceOfferRecentlyDeclined) {
          return withNumbers(
            CheckInOutcome.offerMaintenanceWeek,
            [CheckInReason.plateauAtFloor],
            target: week,
            correction: correction,
            step: step,
            weekDays: maintenanceWeekDays,
          );
        }
        return withNumbers(
          CheckInOutcome.hold,
          [
            eaFloor > NutritionPolicyV2.ceilToTen(i.minimumKcal)
                ? CheckInReason.atEnergyAvailabilityFloor
                : CheckInReason.atCalorieFloor,
          ],
          correction: correction,
          step: step,
        );
      }
      return withNumbers(
        CheckInOutcome.propose,
        [reason],
        target: target,
        correction: correction,
        step: step,
      );
    }

    final ceiling = i.maximumKcal;
    final wanted = (current + step).toDouble();
    final bounded = ceiling != null && wanted > ceiling ? ceiling : wanted;
    var target = (bounded / 10).floor() * 10;
    if (target < current) target = current;
    if (target - current < minStepKcal) {
      return withNumbers(
        CheckInOutcome.hold,
        [CheckInReason.atCalorieCeiling],
        correction: correction,
        step: step,
      );
    }
    return withNumbers(
      CheckInOutcome.propose,
      [reason],
      target: target,
      correction: correction,
      step: step,
    );
  }

  /// `clamp(round10(0.5 x |correction|), 100, 200)`.
  static int _stepFor(double correctionKcal) {
    final half = correctionDamping * correctionKcal.abs();
    final rounded = NutritionPolicyV2.roundToTen(half);
    return rounded < minStepKcal
        ? minStepKcal
        : (rounded > maxStepKcal ? maxStepKcal : rounded);
  }

  /// Signed planned weekly change as a percent of body weight (negative is
  /// losing). Loss is clamped to the policy cap.
  static double _plannedPercent(AdaptiveCheckInInput i) {
    switch (i.goal) {
      case NutritionGoal.maintain:
        return 0;
      case NutritionGoal.gainMuscle:
        return i.plannedWeeklyChangePercent;
      case NutritionGoal.loseFat:
        final cap = i.inFightCamp
            ? WeightRatePolicy.maxCampLossPercentPerWeek
            : WeightRatePolicy.maxLossPercentPerWeek;
        final pct = i.plannedWeeklyChangePercent;
        return -(pct > cap ? cap : pct);
    }
  }

  static CheckInReason _reasonFor(NutritionGoal goal, bool wantsLess) {
    switch (goal) {
      case NutritionGoal.maintain:
        return wantsLess
            ? CheckInReason.maintenanceDriftUp
            : CheckInReason.maintenanceDriftDown;
      case NutritionGoal.loseFat:
        // Too heavy wants less; too light (faster than planned) wants more.
        return wantsLess
            ? CheckInReason.slowerThanPlanned
            : CheckInReason.fasterThanPlanned;
      case NutritionGoal.gainMuscle:
        return wantsLess
            ? CheckInReason.fasterThanPlanned
            : CheckInReason.slowerThanPlanned;
    }
  }

  /// Logged intake averaged below resting energy in each of the last two
  /// weeks, with enough counted days in each to mean it.
  static bool _lowIntakeTwoWeeks(AdaptiveCheckInInput i) {
    bool low(double? avg, int days) =>
        days >= lowIntakeMinDaysPerWeek &&
        avg != null &&
        avg < i.restingEnergyKcal;
    return low(i.tier.thisWeek.averageIntakeKcal, i.tier.thisWeek.daysCounted) &&
        low(i.tier.lastWeek.averageIntakeKcal, i.tier.lastWeek.daysCounted);
  }

  /// The maintenance-week target, or null when it would not be a real step up
  /// (unknown maintenance, or less than one step above the current target).
  static int? _maintenanceWeekTarget(AdaptiveCheckInInput i, int current) {
    final m = i.maintenanceKcal;
    if (m == null || !m.isFinite) return null;
    final target = (m / 10).floor() * 10;
    return target - current >= minStepKcal ? target : null;
  }

  static double _max(double a, double b) => a > b ? a : b;

  static bool _valid(AdaptiveCheckInInput i) {
    bool pos(double v) => v.isFinite && v > 0;
    if (!pos(i.currentTargetKcal) ||
        !pos(i.minimumKcal) ||
        !pos(i.currentWeightKg) ||
        !pos(i.restingEnergyKcal)) {
      return false;
    }
    if (!i.plannedWeeklyChangePercent.isFinite ||
        i.plannedWeeklyChangePercent < 0) {
      return false;
    }
    if (!i.averageSessionKcalPerDay.isFinite ||
        i.averageSessionKcalPerDay < 0) {
      return false;
    }
    if (i.maximumKcal != null && !i.maximumKcal!.isFinite) return false;
    if (i.maintenanceKcal != null && !i.maintenanceKcal!.isFinite) {
      return false;
    }
    final p = i.previousObservedWeeklyPercent;
    if (p != null && !p.isFinite) return false;
    if (i.continuousDeficitWeeks < 0) return false;
    final slope = i.slope.slopeKgPerDay;
    if (slope != null && !slope.isFinite) return false;
    final band = i.slope.noiseBandKgPerWeek;
    if (band != null && !band.isFinite) return false;
    final avg = i.tier.thisWeek.averageIntakeKcal;
    if (avg != null && !avg.isFinite) return false;
    return true;
  }
}
