import '../calculators/weekly_check_in.dart';
import '../models/nutrition_enums.dart';
import '../policies/energy_availability_proxy.dart';
import '../policies/nutrition_policy.dart';
import '../policies/nutrition_policy_v2.dart';
import '../policies/weight_rate_policy.dart';
import 'calendar_day.dart';
import 'data_tier.dart';
import 'fuel_log_day.dart';
import 'safety_reask.dart';
import 'weight_slope.dart';

/// What the check-in recommends. It only ever recommends: nothing changes
/// until the user taps Apply (Fuel V2 spec, rule 2).
enum CheckInOutcome {
  /// Under 18 or no known age. No target, no proposal, nothing to show.
  notEligible,

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
    required this.ageYears,
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
    this.clinicalReviewNeeded = false,
    this.inFightWeek = false,
    this.inFightCamp = false,
    this.lastTargetChangeDay,
    this.previousObservedWeeklyPercent,
    this.loggingSelfReport,
    this.continuousDeficitWeeks = 0,
    this.maintenanceOfferRecentlyDeclined = false,
    this.lossGoalStartedOn,
  });

  /// The check-in day. Data windows end the day before (the last closed day).
  final CalendarDay today;

  /// Whole years; null when unknown. Under 18 or null gives
  /// [CheckInOutcome.notEligible].
  final int? ageYears;
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
  /// (zero for maintenance). The goal gives the direction. It is clamped by
  /// `WeightRatePolicy` (0.75% outside a camp) before the check-in uses it.
  final double plannedWeeklyChangePercent;

  /// Estimated resting energy (`NutritionTargetV2.estimatedRmrKcal`).
  final double restingEnergyKcal;

  /// Average planned session energy per day, for the energy-availability
  /// floor. Zero for no planned training.
  final double averageSessionKcalPerDay;

  /// A self-declared clinical flag is set (`NutritionSafetyPolicy` said
  /// `needsProfessionalReview`).
  final bool clinicalReviewNeeded;

  final DataTierAssessment tier;

  /// `WeightSlopeCalculator.best`.
  final WeightSlope slope;
  final bool inFightWeek;

  /// Inside a fight-camp path: the loss cap is the camp's 1%, not 0.75%.
  final bool inFightCamp;

  /// The day the last target change took effect; null when none.
  final CalendarDay? lastTargetChangeDay;

  /// The observed weekly change, in percent of body weight, at the previous
  /// check-in (negative is losing); null when there was none.
  final double? previousObservedWeeklyPercent;
  final LoggingSelfReport? loggingSelfReport;

  /// Weeks of continuous deficit with no maintenance week
  /// (`TargetHistory.continuousDeficitWeeks`).
  final int continuousDeficitWeeks;

  /// An optional maintenance week was offered and the user chose Keep
  /// recently (`TargetHistory.maintenanceOfferDeclinedWithin`): no nagging.
  final bool maintenanceOfferRecentlyDeclined;

  /// When the safety questions were last answered; null when never.
  final CalendarDay? lastSafetyScreenDay;

  /// When the current loss goal started.
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

  /// Signed kcal per day; 0 unless [isProposal].
  final int deltaKcal;

  /// The target after the change; the current target unless [isProposal].
  final int proposedTargetKcal;

  /// At least one code, always. The first is the headline.
  final List<CheckInReason> reasons;
  final DataTier tier;

  /// The lowest weekly-average target allowed:
  /// `max(minimum day, resting + 0.5 x session energy)`.
  final int floorKcal;

  /// The 8-week safety questions are due. The UI asks them.
  final bool safetyReaskDue;

  /// kg per week, signed (negative is losing). Null when no slope was usable.
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

  /// A neutral copy key for the outcome, such as `fuel.checkIn.hold.onPace`.
  /// The UI maps keys to words; the domain never holds a user-facing string.
  String get copyKey => '$copyKeyPrefix.${outcome.name}.${reasons.first.name}';

  /// One key per reason, same format.
  List<String> get copyKeys => [
        for (final r in reasons) '$copyKeyPrefix.${outcome.name}.${r.name}',
      ];

  static const String copyKeyPrefix = 'fuel.checkIn';
}

/// The deterministic weekly decision (Fuel V2 slice N1). Pure: no clock, no
/// storage, no UI. All thresholds are implementation defaults.
/// DIETITIAN SIGN-OFF PENDING (see [signOffPending]).
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
/// 1. under 18 or unknown age: not eligible, nothing at all;
/// 2. invalid input;
/// 3. SAFETY, a [CheckInOutcome.referral] with every reason that applies: a
///    clinical flag; logged intake under resting energy two weeks running; a
///    trend loss above 1% of body weight a week two check-ins running. No
///    number changes, never a bigger cut. Safety beats fight week;
/// 4. fight week (the camp plan owns the numbers);
/// 5. a target below today's floor is lifted back to it;
/// 6. one change a week;
/// 7. 10 or more weeks of continuous deficit: optional maintenance week;
/// 8. data gates: Tier 0, partial logging, no usable slope, implausible
///    change, intake off target;
/// 9. inside the error band: on pace;
/// 10. otherwise one damped, clamped step. A cut never goes below the floor
///    and never happens while the safety questions are due; at the floor the
///    next step is a maintenance week, not a lower number.
///
/// A single check-in with a loss above 1% adds [CheckInReason.lossAboveCap]
/// to whatever it gets. It can never end in a step down: losing that fast
/// puts the error below zero, which always asks for more food.
class AdaptiveWeeklyCheckIn {
  const AdaptiveWeeklyCheckIn._();

  /// Every number below is a placeholder until a sports dietitian reviews it.
  static const bool signOffPending = true;

  /// kcal per day for 1 kg per week: 7,700 / 7 = 1,100.
  static const double kcalPerKgPerWeekPerDay = WeightRatePolicy.kcalPerKg / 7;
  static const double correctionDamping = 0.5;
  static const int minStepKcal = 100;
  static const int maxStepKcal = 200;

  /// Error band: at least this share of the planned rate, at least this many
  /// kg a week, and never narrower than the measured noise band.
  static const double deadBandPlannedFraction = 0.25;
  static const double deadBandMinKgPerWeek = 0.1;

  /// Shared with the 7-day check-in.
  static const double adherenceTolerance = WeeklyCheckIn.adherenceTolerance;
  static const double implausibleChangePercent =
      WeeklyCheckIn.implausibleChangePercent;

  /// Loss faster than this share of body weight a week is a safety signal.
  static const double veryFastLossPercent = 1.0;

  /// Counted days a week needs for the low-intake rule to read it.
  static const int lowIntakeMinDaysPerWeek = 5;

  /// Weeks of continuous deficit after which a maintenance week is offered.
  static const int deficitWeeksBeforeMaintenanceOffer = 10;

  /// A target changed within this many days is not changed again.
  static const int minDaysBetweenChanges = 7;

  static const int maintenanceWeekDays = 7;

  /// True when [ageYears] may have targets at all.
  static bool isEligibleAge(int? ageYears) =>
      ageYears != null && ageYears >= NutritionPolicy.minimumAgeYears;

  /// `clamp(round10(0.5 x |correction|), 100, 200)`.
  static int stepFor(double correctionKcal) {
    final half = correctionDamping * correctionKcal.abs();
    final rounded = NutritionPolicyV2.roundToTen(half);
    if (rounded < minStepKcal) return minStepKcal;
    if (rounded > maxStepKcal) return maxStepKcal;
    return rounded;
  }

  /// Signed planned weekly change as a percent of body weight (negative is
  /// losing), after `WeightRatePolicy`'s caps: 0.75% (and 1 kg) a week for a
  /// loss outside a camp, 1% inside one, 0.5% for a gain.
  static double signedPlannedPercent({
    required NutritionGoal goal,
    required double weightKg,
    required double requestedPercent,
    bool inFightCamp = false,
  }) {
    final rate = WeightRatePolicy.apply(
      goal: goal,
      weightKg: weightKg,
      requestedPercent: requestedPercent,
      inFightCamp: inFightCamp,
    ).percentPerWeek;
    return switch (goal) {
      NutritionGoal.maintain => 0.0,
      NutritionGoal.gainMuscle => rate,
      NutritionGoal.loseFat => -rate,
    };
  }

  static AdaptiveCheckInDecision decide(AdaptiveCheckInInput i) {
    // 1. Age: no targets at all.
    if (!isEligibleAge(i.ageYears)) {
      return const AdaptiveCheckInDecision(
        outcome: CheckInOutcome.notEligible,
        deltaKcal: 0,
        proposedTargetKcal: 0,
        reasons: [CheckInReason.ageNotEligible],
        tier: DataTier.tier0,
        floorKcal: 0,
        safetyReaskDue: false,
      );
    }

    final valid = _valid(i);
    final current = valid ? i.currentTargetKcal.round() : 0;
    final minimum = valid ? NutritionPolicyV2.ceilToTen(i.minimumKcal) : 0;
    final eaFloor = valid
        ? EnergyAvailabilityProxy.floorKcal(
            restingEnergyKcal: i.restingEnergyKcal,
            averageSessionKcalPerDay: i.averageSessionKcalPerDay,
          )
        : 0;
    final floor = minimum > eaFloor ? minimum : eaFloor;
    final floorReason = eaFloor > minimum
        ? CheckInReason.atEnergyAvailabilityFloor
        : CheckInReason.atCalorieFloor;
    final reaskDue = valid &&
        SafetyReask.isDue(
          lastAnsweredOn: i.lastSafetyScreenDay,
          today: i.today,
          lossGoalStartedOn: i.lossGoalStartedOn,
        );

    final observedKg =
        valid && i.slope.isUsable ? i.slope.slopeKgPerWeek : null;
    final observedPercent =
        observedKg == null ? null : observedKg / i.currentWeightKg * 100;
    final fastLoss =
        observedPercent != null && observedPercent < -veryFastLossPercent;

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
          reasons: List.unmodifiable(reasons),
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
    // A hold that carries the one-week fast-loss signal when there is one.
    AdaptiveCheckInDecision hold(List<CheckInReason> reasons) => make(
          CheckInOutcome.hold,
          [...reasons, if (fastLoss) CheckInReason.lossAboveCap],
        );

    // 2. Invalid input.
    if (!valid) return make(CheckInOutcome.hold, [CheckInReason.invalidInput]);

    // 3. Safety escalation: a referral, never a number.
    final previous = i.previousObservedWeeklyPercent;
    final referral = <CheckInReason>[
      if (i.clinicalReviewNeeded) CheckInReason.clinicalReviewFlagged,
      if (_lowIntakeTwoWeeks(i)) CheckInReason.lowIntakeSafety,
      if (fastLoss && previous != null && previous < -veryFastLossPercent)
        CheckInReason.lossAboveCap,
    ];
    if (referral.isNotEmpty) return make(CheckInOutcome.referral, referral);

    // 4. Fight week.
    if (i.inFightWeek) return hold(const [CheckInReason.fightWeek]);

    // 5. Never below the floor: lift a target that sits under it.
    if (current < floor) {
      return make(
        CheckInOutcome.propose,
        [CheckInReason.targetBelowFloor, floorReason],
        target: floor,
      );
    }

    // 6. One change a week.
    final last = i.lastTargetChangeDay;
    if (last != null && last.daysUntil(i.today) < minDaysBetweenChanges) {
      return hold(const [CheckInReason.recentChange]);
    }

    // 7. Long deficit: an optional maintenance week.
    final mayOfferMaintenanceWeek = i.goal == NutritionGoal.loseFat &&
        !i.inFightCamp &&
        !i.maintenanceOfferRecentlyDeclined;
    final maintenanceWeek =
        mayOfferMaintenanceWeek ? _maintenanceWeekTarget(i, current) : null;
    if (maintenanceWeek != null &&
        i.continuousDeficitWeeks >= deficitWeeksBeforeMaintenanceOffer) {
      return make(
        CheckInOutcome.offerMaintenanceWeek,
        [CheckInReason.deficitDurationReached],
        target: maintenanceWeek,
        weekDays: maintenanceWeekDays,
      );
    }

    // 8. Data gates.
    if (!i.tier.mayPropose) {
      return hold(
        i.tier.reasons.isEmpty
            ? const [CheckInReason.programTooNew]
            : i.tier.reasons,
      );
    }
    final report = i.loggingSelfReport;
    if (i.tier.thisWeek.partialDays > 0 ||
        report == LoggingSelfReport.some ||
        report == LoggingSelfReport.none) {
      return hold(const [CheckInReason.partialLoggingFlagged]);
    }
    if (observedKg == null || observedPercent == null) {
      return hold(const [CheckInReason.insufficientWeighIns]);
    }
    if (observedPercent.abs() > implausibleChangePercent) {
      return hold(const [CheckInReason.implausibleWeightChange]);
    }
    final intake = i.tier.thisWeek.averageIntakeKcal;
    if (intake == null) return hold(const [CheckInReason.insufficientLogging]);
    if ((intake - i.currentTargetKcal).abs() / i.currentTargetKcal >
        adherenceTolerance) {
      return hold(const [CheckInReason.intakeOffTarget]);
    }

    // 9. Plan against slope.
    final plannedPercent = signedPlannedPercent(
      goal: i.goal,
      weightKg: i.currentWeightKg,
      requestedPercent: i.plannedWeeklyChangePercent,
      inFightCamp: i.inFightCamp,
    );
    final planned = plannedPercent * i.currentWeightKg / 100;
    final error = observedKg - planned;
    final noise = i.slope.noiseBandKgPerWeek ?? 0;
    var band = deadBandPlannedFraction * planned.abs();
    if (noise > band) band = noise;
    if (deadBandMinKgPerWeek > band) band = deadBandMinKgPerWeek;
    final correction = -kcalPerKgPerWeekPerDay * error;
    final step = stepFor(correction);
    AdaptiveCheckInDecision withNumbers(
      CheckInOutcome outcome,
      CheckInReason reason, {
      int? target,
      int? weekDays,
    }) =>
        make(
          outcome,
          [reason, if (fastLoss) CheckInReason.lossAboveCap],
          target: target,
          planned: planned,
          error: error,
          correction: correction,
          step: step,
          band: band,
          weekDays: weekDays,
        );
    if (error.abs() <= band) {
      return withNumbers(CheckInOutcome.hold, CheckInReason.onPace);
    }

    // 10. One damped, clamped step.
    final wantsLess = correction < 0;
    final reason = _reasonFor(i.goal, wantsLess);

    if (wantsLess) {
      if (reaskDue) {
        return withNumbers(CheckInOutcome.hold, CheckInReason.safetyReaskDue);
      }
      // Round away from the current target so a full step stays a full
      // step; the floor is already on a ten.
      var target = _floorToTen((current - step).toDouble());
      if (target < floor) target = floor;
      if (current - target < minStepKcal) {
        if (maintenanceWeek != null) {
          return withNumbers(
            CheckInOutcome.offerMaintenanceWeek,
            CheckInReason.plateauAtFloor,
            target: maintenanceWeek,
            weekDays: maintenanceWeekDays,
          );
        }
        return withNumbers(CheckInOutcome.hold, floorReason);
      }
      return withNumbers(CheckInOutcome.propose, reason, target: target);
    }

    final ceiling = i.maximumKcal;
    var target = NutritionPolicyV2.ceilToTen((current + step).toDouble());
    if (ceiling != null && target > ceiling) target = _floorToTen(ceiling);
    if (target - current < minStepKcal) {
      return withNumbers(CheckInOutcome.hold, CheckInReason.atCalorieCeiling);
    }
    return withNumbers(CheckInOutcome.propose, reason, target: target);
  }

  static int _floorToTen(double kcal) => (kcal / 10).floor() * 10;

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
  /// weeks, with enough counted days in each to mean it. Partial days never
  /// count, so a half-logged week cannot raise this alarm.
  static bool _lowIntakeTwoWeeks(AdaptiveCheckInInput i) {
    bool low(LogWindow w) =>
        w.daysCounted >= lowIntakeMinDaysPerWeek &&
        w.averageIntakeKcal != null &&
        w.averageIntakeKcal! < i.restingEnergyKcal;
    return low(i.tier.thisWeek) && low(i.tier.lastWeek);
  }

  /// The maintenance-week target, or null when it would not be a real step up
  /// (unknown maintenance, or less than one step above the current target).
  static int? _maintenanceWeekTarget(AdaptiveCheckInInput i, int current) {
    final m = i.maintenanceKcal;
    if (m == null) return null;
    final target = _floorToTen(m);
    return target - current >= minStepKcal ? target : null;
  }

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
    if (i.maximumKcal != null && !pos(i.maximumKcal!)) return false;
    if (i.maintenanceKcal != null && !pos(i.maintenanceKcal!)) return false;
    final p = i.previousObservedWeeklyPercent;
    if (p != null && !p.isFinite) return false;
    if (i.continuousDeficitWeeks < 0) return false;
    final slope = i.slope.slopeKgPerDay;
    if (slope != null && !slope.isFinite) return false;
    final band = i.slope.noiseBandKgPerWeek;
    if (band != null && !band.isFinite) return false;
    for (final w in [i.tier.thisWeek, i.tier.lastWeek]) {
      final avg = w.averageIntakeKcal;
      if (avg != null && (!avg.isFinite || avg < 0)) return false;
    }
    return true;
  }
}
