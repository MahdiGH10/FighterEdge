import '../models/nutrition_enums.dart';

/// Why the weekly check-in decided what it did. Stable codes: the UI maps
/// them to copy, and an AI may only explain them, never change them.
enum CheckInReason {
  // ---- hold ----
  /// Fight week: the camp and fight-week plan own the numbers.
  fightWeek,

  /// A target change was already accepted in the last 7 days. One step a week.
  recentChange,

  /// Fewer than [WeeklyCheckIn.minDaysLogged] days logged.
  insufficientLogging,

  /// Fewer than [WeeklyCheckIn.minWeighIns] weigh-ins this week, or no trend.
  insufficientWeighIns,

  /// Average intake was not within [WeeklyCheckIn.adherenceTolerance] of the
  /// target, so the plan has not been tested. Eat to the plan first.
  intakeOffTarget,

  /// The weekly weight change is too large to be real tissue change
  /// (water, a missed log or a scale error); no decision is made from it.
  implausibleWeightChange,

  /// The trend is within the pace band.
  onPace,

  /// A step down was due but the target is already at the lowest allowed.
  atCalorieFloor,

  /// A step up was due but the target is already at the highest allowed.
  atCalorieCeiling,

  /// Inputs were missing, not finite or out of range.
  invalidInput,

  // ---- proposals ----
  /// Moving slower than planned while eating to plan.
  slowerThanPlanned,

  /// Moving faster than planned while eating to plan.
  fasterThanPlanned,

  /// Maintenance goal: weight is trending up while eating to plan.
  maintenanceDriftUp,

  /// Maintenance goal: weight is trending down while eating to plan.
  maintenanceDriftDown,
}

enum CheckInAction { hold, increase, decrease }

/// The week's numbers, already summarised by the caller. All energy values are
/// kcal per day, averaged over the week.
class WeeklyCheckInInput {
  const WeeklyCheckInInput({
    required this.goal,
    required this.currentTargetKcal,
    required this.minimumKcal,
    required this.currentWeightKg,
    required this.plannedWeeklyChangePercent,
    required this.daysLogged,
    required this.averageIntakeKcal,
    required this.weeklyWeightChangeKg,
    required this.weighInsThisWeek,
    this.maximumKcal,
    this.inFightWeek = false,
    this.targetChangedInLast7Days = false,
  });

  final NutritionGoal goal;

  /// The weekly average target the user is held to.
  final double currentTargetKcal;

  /// The lowest the target may go: `NutritionTargetV2.minimumDailyKcal`.
  final double minimumKcal;

  /// The highest it may go, e.g. estimated maintenance while losing fat.
  /// Null for no ceiling.
  final double? maximumKcal;
  final double currentWeightKg;

  /// The pace the user chose, as a positive percent of body weight per week
  /// (zero for maintenance). The goal gives the direction.
  final double plannedWeeklyChangePercent;

  /// Days this week with food logged, 0 to 7.
  final int daysLogged;

  /// Mean intake over the logged days; null when nothing was logged.
  final double? averageIntakeKcal;

  /// Smoothed weight trend change over the week, in kg (negative is losing):
  /// `WeightTrend.weeklyChangeKg`. Null when there is no trend yet.
  final double? weeklyWeightChangeKg;
  final int weighInsThisWeek;
  final bool inFightWeek;
  final bool targetChangedInLast7Days;
}

/// The check-in outcome. It only ever recommends: nothing changes until the
/// user accepts.
class WeeklyCheckInDecision {
  const WeeklyCheckInDecision({
    required this.action,
    required this.proposedDeltaKcal,
    required this.proposedTargetKcal,
    required this.reasons,
    this.observedChangePercent,
  });

  final CheckInAction action;

  /// Signed kcal per day; 0 for a hold.
  final int proposedDeltaKcal;

  /// The target after the change; equals the current target for a hold.
  final int proposedTargetKcal;
  final List<CheckInReason> reasons;

  /// The observed weekly change as a signed percent of body weight, when a
  /// trend was usable.
  final double? observedChangePercent;

  bool get isProposal => action != CheckInAction.hold;
}

/// The deterministic weekly decision table from
/// `docs/NUTRITION_COMPETITOR_RESEARCH.md` section 13. Pure: no clock, no
/// storage. Thresholds are implementation defaults pending dietitian review.
class WeeklyCheckIn {
  const WeeklyCheckIn._();

  /// "Most" days: fewer than this and the week says too little.
  static const int minDaysLogged = 5;
  static const int minWeighIns = 3;

  /// Intake within this share of the target counts as eating to the plan.
  static const double adherenceTolerance = 0.10;

  /// On pace: within 25% of the planned rate, but never tighter than
  /// [minToleranceBodyWeightPercent] (scale noise).
  static const double paceToleranceFraction = 0.25;
  static const double minToleranceBodyWeightPercent = 0.15;

  /// "Faster than planned" means beyond 150% of the planned rate.
  static const double fasterThanPlannedFactor = 1.5;

  /// A weekly trend change beyond this share of body weight is not tissue.
  static const double implausibleChangePercent = 2.0;

  static const int smallStepKcal = 100;
  static const int largeStepKcal = 150;

  static WeeklyCheckInDecision decide(WeeklyCheckInInput input) {
    WeeklyCheckInDecision hold(List<CheckInReason> reasons, [double? seen]) =>
        WeeklyCheckInDecision(
          action: CheckInAction.hold,
          proposedDeltaKcal: 0,
          proposedTargetKcal: _asKcal(input.currentTargetKcal),
          reasons: reasons,
          observedChangePercent: seen,
        );

    if (!_valid(input)) return hold(const [CheckInReason.invalidInput]);
    if (input.inFightWeek) return hold(const [CheckInReason.fightWeek]);
    if (input.targetChangedInLast7Days) {
      return hold(const [CheckInReason.recentChange]);
    }

    final holds = <CheckInReason>[
      if (input.daysLogged < minDaysLogged) CheckInReason.insufficientLogging,
      if (input.weighInsThisWeek < minWeighIns ||
          input.weeklyWeightChangeKg == null)
        CheckInReason.insufficientWeighIns,
    ];
    if (holds.isNotEmpty) return hold(holds);

    final intake = input.averageIntakeKcal!;
    final target = input.currentTargetKcal;
    if ((intake - target).abs() / target > adherenceTolerance) {
      return hold(const [CheckInReason.intakeOffTarget]);
    }

    final observed = input.weeklyWeightChangeKg! / input.currentWeightKg * 100;
    if (observed.abs() > implausibleChangePercent) {
      return hold(const [CheckInReason.implausibleWeightChange], observed);
    }

    final planned = switch (input.goal) {
      NutritionGoal.loseFat => -input.plannedWeeklyChangePercent,
      NutritionGoal.gainMuscle => input.plannedWeeklyChangePercent,
      NutritionGoal.maintain => 0.0,
    };
    final tolerance = _max(
      paceToleranceFraction * planned.abs(),
      minToleranceBodyWeightPercent,
    );
    // Positive: the weight is higher than the plan wants.
    final deviation = observed - planned;
    if (deviation.abs() <= tolerance) {
      return hold(const [CheckInReason.onPace], observed);
    }

    // Is the miss too slow, or past the "faster than planned" line?
    final tooHigh = deviation > 0;
    final bool slower;
    switch (input.goal) {
      case NutritionGoal.loseFat:
        slower = tooHigh;
      case NutritionGoal.gainMuscle:
        slower = !tooHigh;
      case NutritionGoal.maintain:
        slower = false;
    }
    if (input.goal != NutritionGoal.maintain && !slower) {
      // Faster: only act past 150% of the planned rate.
      if (observed.abs() <= planned.abs() * fasterThanPlannedFactor) {
        return hold(const [CheckInReason.onPace], observed);
      }
    }

    // Too high wants fewer kcal, too low wants more. The reason names the
    // plan-relative miss; for maintenance both directions are "too far".
    final wantsLess = tooHigh;
    final step =
        deviation.abs() > 2 * tolerance ? largeStepKcal : smallStepKcal;
    final reason = input.goal == NutritionGoal.maintain
        ? (wantsLess
            ? CheckInReason.maintenanceDriftUp
            : CheckInReason.maintenanceDriftDown)
        : (slower
            ? CheckInReason.slowerThanPlanned
            : CheckInReason.fasterThanPlanned);

    final double wanted = wantsLess ? target - step : target + step;
    final double bounded;
    if (wantsLess) {
      bounded = _max(wanted, input.minimumKcal);
    } else {
      final ceiling = input.maximumKcal;
      bounded = ceiling != null && wanted > ceiling ? ceiling : wanted;
    }
    final newTarget = _roundToTen(bounded, wantsLess);
    final delta = newTarget - _asKcal(target);
    if (delta.abs() < smallStepKcal) {
      return hold([
        wantsLess
            ? CheckInReason.atCalorieFloor
            : CheckInReason.atCalorieCeiling,
      ], observed);
    }
    return WeeklyCheckInDecision(
      action: wantsLess ? CheckInAction.decrease : CheckInAction.increase,
      proposedDeltaKcal: delta,
      proposedTargetKcal: newTarget,
      reasons: [reason],
      observedChangePercent: observed,
    );
  }

  static bool _valid(WeeklyCheckInInput i) {
    bool ok(double? v) => v != null && v.isFinite;
    if (!ok(i.currentTargetKcal) || i.currentTargetKcal <= 0) return false;
    if (!ok(i.minimumKcal) || i.minimumKcal <= 0) return false;
    if (!ok(i.currentWeightKg) || i.currentWeightKg <= 0) return false;
    if (!ok(i.plannedWeeklyChangePercent) || i.plannedWeeklyChangePercent < 0) {
      return false;
    }
    if (i.daysLogged < 0 || i.daysLogged > 7 || i.weighInsThisWeek < 0) {
      return false;
    }
    if (i.maximumKcal != null && !i.maximumKcal!.isFinite) return false;
    if (i.weeklyWeightChangeKg != null && !i.weeklyWeightChangeKg!.isFinite) {
      return false;
    }
    if (i.averageIntakeKcal != null &&
        (!i.averageIntakeKcal!.isFinite || i.averageIntakeKcal! < 0)) {
      return false;
    }
    // Enough days were logged but no intake figure came with them.
    if (i.daysLogged >= minDaysLogged && i.averageIntakeKcal == null) {
      return false;
    }
    return true;
  }

  static int _asKcal(double kcal) => kcal.isFinite ? kcal.round() : 0;

  static double _max(double a, double b) => a > b ? a : b;

  /// Tens, rounded toward the direction of travel's safe side: a step down
  /// never rounds below the bound, a step up never rounds above it.
  static int _roundToTen(double kcal, bool down) {
    final tens = kcal / 10;
    return (down ? tens.ceil() : tens.floor()) * 10;
  }
}
