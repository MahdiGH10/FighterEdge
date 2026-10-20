import '../../edge_fuel/domain/calculators/weekly_fuel_calculator.dart';

/// Why the review recommends what it does. The screen turns each code into
/// one sentence; the domain only emits the code.
enum ReviewReason {
  /// A planned session was not done and today is free for it.
  sessionMissed,

  /// Food and weight are where they should be.
  onPath,

  /// No usable calorie target to adjust.
  noTarget,

  /// Fewer logged days than [WeeklyReviewCalculator.minLoggedDays]: the log
  /// is the only evidence, and a few days say too little.
  needMoreLogs,

  /// Intake was not close to the target, so the target is not what was
  /// tested. Changing it would be guessing.
  intakeOffTarget,

  /// No weight path to compare the scale with, or too few weigh-ins.
  noWeightPath,

  /// Weight is above the path while food was on target: eat a little less.
  weightAbovePath,

  /// Weight is below the path while food was on target: eat a little more.
  weightBelowPath,

  /// Eating less would go under the resting energy estimate.
  atFloor,
}

enum RecommendationKind { hold, adjustCalories, moveSession }

/// The single suggestion a review ends in. It only recommends: the athlete
/// accepts it or keeps the current plan.
class ReviewRecommendation {
  const ReviewRecommendation._(
    this.kind,
    this.reason, {
    this.calorieDelta = 0,
    this.sessionId,
  });

  /// Change nothing.
  const ReviewRecommendation.hold(ReviewReason reason)
      : this._(RecommendationKind.hold, reason);

  /// Change the daily calorie target by [delta] (positive or negative).
  const ReviewRecommendation.adjustCalories(int delta, ReviewReason reason)
      : this._(RecommendationKind.adjustCalories, reason, calorieDelta: delta);

  /// Move the missed session [id] to today.
  const ReviewRecommendation.moveSession(String id)
      : this._(RecommendationKind.moveSession, ReviewReason.sessionMissed,
            sessionId: id);

  final RecommendationKind kind;
  final ReviewReason reason;
  final int calorieDelta;
  final String? sessionId;

  @override
  bool operator ==(Object other) =>
      other is ReviewRecommendation &&
      other.kind == kind &&
      other.reason == reason &&
      other.calorieDelta == calorieDelta &&
      other.sessionId == sessionId;

  @override
  int get hashCode => Object.hash(kind, reason, calorieDelta, sessionId);

  @override
  String toString() =>
      'ReviewRecommendation($kind, $reason, $calorieDelta, $sessionId)';
}

/// Sessions done against planned, from `WeeklyAdherence`. Rest days and
/// recovery sessions are never in these numbers.
class ReviewTraining {
  const ReviewTraining({
    required this.planned,
    required this.completed,
    required this.target,
    this.missed = 0,
    this.skipped = 0,
    this.movableSessionId,
  });

  final int planned;
  final int completed;

  /// Sessions that make the week count (see `WeeklyTarget`).
  final int target;
  final int missed;
  final int skipped;

  /// A missed session that could move to today, or null.
  final String? movableSessionId;

  bool get targetMet => planned == 0 || completed >= target;
}

/// The week's food against the calorie and protein targets.
class ReviewNutrition {
  const ReviewNutrition({
    this.targetCalories,
    this.targetProteinGrams,
    this.loggedDays = 0,
    this.onTargetDays = 0,
    this.proteinHitDays = 0,
    this.averageCalories,
    this.restingEnergyKcal,
  });

  /// Built from the fuel card's own weekly summary, so the review and the
  /// card can never disagree.
  factory ReviewNutrition.fromSummary(
    WeeklyFuelSummary summary, {
    int? restingEnergyKcal,
  }) =>
      ReviewNutrition(
        targetCalories:
            summary.targetCalories > 0 ? summary.targetCalories : null,
        targetProteinGrams:
            summary.targetProtein > 0 ? summary.targetProtein : null,
        loggedDays: summary.loggedDays,
        onTargetDays: summary.onTargetDays,
        proteinHitDays: summary.proteinHitDays,
        averageCalories: summary.averageCalories,
        restingEnergyKcal: restingEnergyKcal,
      );

  final int? targetCalories;
  final int? targetProteinGrams;
  final int loggedDays;
  final int onTargetDays;
  final int proteinHitDays;

  /// Over logged days only.
  final int? averageCalories;

  /// Floor for any reduction.
  final int? restingEnergyKcal;

  /// Average intake over the target, or null without both.
  double? get intakeRatio {
    final average = averageCalories;
    final target = targetCalories;
    if (average == null || target == null || target <= 0) return null;
    return average / target;
  }
}

/// The scale against the path.
class ReviewWeight {
  const ReviewWeight({
    this.changeKg,
    this.expectedChangeKg,
    this.weighIns = 0,
  });

  /// Trend weight now minus the trend a week before. Negative is losing.
  final double? changeKg;

  /// Where the path says it should have moved this week (negative for a
  /// cut). Null when there is no path, or the path is not one the app plans.
  final double? expectedChangeKg;
  final int weighIns;

  /// Actual minus expected; positive means above the path.
  double? get gapKg {
    final actual = changeKg;
    final expected = expectedChangeKg;
    if (actual == null || expected == null) return null;
    return actual - expected;
  }
}

/// A week's review: the facts and the one recommendation they lead to.
class WeeklyReview {
  const WeeklyReview({
    required this.weekStart,
    required this.training,
    required this.nutrition,
    required this.weight,
    required this.recommendation,
  });

  final DateTime weekStart;
  final ReviewTraining training;
  final ReviewNutrition nutrition;
  final ReviewWeight weight;
  final ReviewRecommendation recommendation;
}

/// Builds a [WeeklyReview]. Deterministic and pure: the same facts always
/// give the same recommendation, and it never adjusts the nutrition policy,
/// only the target the policy already produced.
class WeeklyReviewCalculator {
  WeeklyReviewCalculator._();

  /// Fewer logged days than this say too little to act on.
  static const int minLoggedDays = 4;

  /// Weigh-ins needed to trust a trend.
  static const int minWeighIns = 2;

  /// Average intake this close to the target counts as following it.
  static const double intakeBand = WeeklyFuelCalculator.onTargetBand;

  /// A weekly gap smaller than this is scale noise.
  static const double toleranceKg = 0.25;

  /// A gap this large earns the bigger step.
  static const double largeGapKg = 0.5;

  /// The two calorie steps (kcal a day) a review may suggest.
  static const int smallStepKcal = 100;
  static const int largeStepKcal = 150;

  static WeeklyReview build({
    required DateTime weekStart,
    required ReviewTraining training,
    required ReviewNutrition nutrition,
    required ReviewWeight weight,
  }) =>
      WeeklyReview(
        weekStart: weekStart,
        training: training,
        nutrition: nutrition,
        weight: weight,
        recommendation: _recommend(training, nutrition, weight),
      );

  static ReviewRecommendation _recommend(
    ReviewTraining training,
    ReviewNutrition nutrition,
    ReviewWeight weight,
  ) {
    // A missed session first: it is the one thing the athlete can still fix
    // today, and only while the week missed its target.
    final movable = training.movableSessionId;
    if (!training.targetMet && movable != null) {
      return ReviewRecommendation.moveSession(movable);
    }

    final target = nutrition.targetCalories;
    if (target == null) {
      return const ReviewRecommendation.hold(ReviewReason.noTarget);
    }
    if (nutrition.loggedDays < minLoggedDays) {
      return const ReviewRecommendation.hold(ReviewReason.needMoreLogs);
    }
    final ratio = nutrition.intakeRatio;
    if (ratio == null || (ratio - 1).abs() > intakeBand) {
      return const ReviewRecommendation.hold(ReviewReason.intakeOffTarget);
    }
    final gap = weight.gapKg;
    if (gap == null || weight.weighIns < minWeighIns) {
      return const ReviewRecommendation.hold(ReviewReason.noWeightPath);
    }
    if (gap.abs() <= toleranceKg) {
      return const ReviewRecommendation.hold(ReviewReason.onPath);
    }
    final step = gap.abs() >= largeGapKg ? largeStepKcal : smallStepKcal;
    if (gap > 0) {
      final floor = nutrition.restingEnergyKcal;
      if (floor != null && target - step < floor) {
        return const ReviewRecommendation.hold(ReviewReason.atFloor);
      }
      return ReviewRecommendation.adjustCalories(
          -step, ReviewReason.weightAbovePath);
    }
    return ReviewRecommendation.adjustCalories(
        step, ReviewReason.weightBelowPath);
  }
}
