import 'calendar.dart';
import 'camp_screening.dart';
import 'fight_camp.dart';
import 'weight_cut_policy.dart';
import 'weight_path.dart';
import 'weight_trend.dart';

/// How much of the fight-week loss the plan asks food to do.
enum FightWeekCut {
  /// Nothing left to lose: eat to the camp targets until the weigh-in.
  none,

  /// Low fibre alone covers it (up to
  /// [WeightCutPolicy.lowFibreAcuteFraction]).
  lowFibre,

  /// Low fibre and fewer carbohydrates (up to
  /// [WeightCutPolicy.dietOnlyAcuteFraction]). When the path needs
  /// supervision, the rest is the coach's to plan, not the app's.
  lowFibreAndCarbs,

  /// No food plan: no weight to plan from, or the path is not safe.
  notPlanned,
}

/// What a day around the weigh-in asks of the athlete, in the order it
/// happens.
enum FightWeekStep {
  /// The camp targets, unchanged.
  eatToPlan,

  /// Under [WeightCutPolicy.lowFibreMaxGramsPerDay] g of fibre.
  lowFibre,

  /// Fewer carbohydrates, so glycogen and the water it holds come down.
  lowerCarbs,

  weighIn,

  /// Rehydrate, then refuel ([RefuelTargets]).
  refuel,

  fight,
}

/// One calendar day from the start of fight week to fight day.
class FightWeekDay {
  const FightWeekDay({
    required this.date,
    required this.daysToWeighIn,
    required this.daysToFight,
    required this.steps,
  });

  final DateTime date;

  /// Negative after the weigh-in.
  final int daysToWeighIn;
  final int daysToFight;

  /// Empty before the weigh-in when the cut is [FightWeekCut.notPlanned].
  final List<FightWeekStep> steps;

  bool get isWeighIn => daysToWeighIn == 0;
  bool get isFight => daysToFight == 0;
}

/// What to take in between the weigh-in and the fight (points 12–14).
class RefuelTargets {
  const RefuelTargets._({this.totalCarbMinGrams, this.totalCarbMaxGrams});

  /// Carbohydrate totals for the time between weigh-in and fight, rounded
  /// to 10 g and worked out at the weight limit, the weight the athlete
  /// weighs in at. Null for a same-day weigh-in: the gap may be too short
  /// to eat that much at [maxCarbGramsPerHour].
  final int? totalCarbMinGrams;
  final int? totalCarbMaxGrams;

  double get minLitresPerHour => WeightCutPolicy.refuelMinLitresPerHour;
  double get maxLitresPerHour => WeightCutPolicy.refuelMaxLitresPerHour;
  int get maxCarbGramsPerHour => WeightCutPolicy.refuelMaxCarbGramsPerHour;

  static RefuelTargets forCamp(FightCamp camp) {
    if (daysBetween(camp.weighInDate, camp.fightDate) == 0) {
      return const RefuelTargets._();
    }
    int grams(double perKg) => (camp.weightLimitKg * perKg / 10).round() * 10;
    return RefuelTargets._(
      totalCarbMinGrams: grams(WeightCutPolicy.refuelMinCarbGramsPerKg),
      totalCarbMaxGrams: grams(WeightCutPolicy.refuelMaxCarbGramsPerKg),
    );
  }
}

/// Fight week, day by day: food-only steps before the weigh-in, the refuel
/// after it. Water is never restricted; a cut that needs it is flagged by
/// the weight path and left to a coach (point 10).
class FightWeekPlan {
  const FightWeekPlan._({
    required this.path,
    required this.cut,
    required this.acuteLossKg,
    required this.days,
    required this.refuel,
  });

  /// The path the plan was made from: on the first day of fight week once
  /// it has started (see [plan]).
  final WeightPath path;
  final FightWeekCut cut;

  WeightPathStatus get status => path.status;

  /// The loss fight week is planned for, kg.
  final double acuteLossKg;

  /// From the first day of fight week to fight day, one per calendar day.
  final List<FightWeekDay> days;

  /// Omitted whenever inputs or screening need review, or the path is unsafe.
  final RefuelTargets? refuel;

  /// The first day eating changes, or null when it never does.
  DateTime? get cutStart => days
      .where((d) => d.steps.contains(FightWeekStep.lowFibre))
      .firstOrNull
      ?.date;

  /// The day for [today], or null outside fight week.
  FightWeekDay? dayOn(DateTime today) {
    final index = daysBetween(days.first.date, today);
    return index >= 0 && index < days.length ? days[index] : null;
  }

  /// Plans fight week for [camp] as of [today].
  ///
  /// Before fight week this is the plan today's weight path leads to. From
  /// its first day, the plan is fixed by the trend weight on that day, so
  /// the steps do not change as weight comes off during the week; without a
  /// weigh-in in the week before, today's trend stands in. Null for
  /// athletes under [WeightCutPolicy.minimumAgeYears].
  static FightWeekPlan? plan({
    required FightCamp camp,
    required List<WeightPoint> weights,
    required DateTime today,
    int? ageYears,
    CampScreening screening = CampScreening.pending,
  }) {
    final start = camp.fightWeekStart;
    var at = daysBetween(today, start) <= 0 ? start : today;
    var trend = WeightTrend.from(weights, today: at).trendKg;
    if (trend == null && at != today) {
      at = today;
      trend = WeightTrend.from(weights, today: at).trendKg;
    }
    final path = WeightPathCalculator.calculate(
      currentWeightKg: trend,
      camp: camp,
      today: at,
      ageYears: ageYears,
      screening: screening,
    );
    return build(camp: camp, path: path);
  }

  /// The plan [path] leads to. Null when [path] is
  /// [WeightPathStatus.notSupported] or screening is unfinished/requires review.
  static FightWeekPlan? build({
    required FightCamp camp,
    required WeightPath path,
  }) {
    final cut = _cutFor(path);
    if (cut == null) return null;
    final lead = daysBetween(camp.weighInDate, camp.fightDate);
    const week = WeightCutPolicy.fightWeekDays;
    return FightWeekPlan._(
      path: path,
      cut: cut,
      acuteLossKg: cut == FightWeekCut.none ? 0 : path.acuteLossKg,
      days: [
        for (var i = 0; i <= week + lead; i++)
          FightWeekDay(
            date: addDays(camp.fightWeekStart, i),
            daysToWeighIn: week - i,
            daysToFight: week + lead - i,
            steps: _stepsFor(cut, week - i, week + lead - i),
          ),
      ],
      refuel:
          cut == FightWeekCut.notPlanned ? null : RefuelTargets.forCamp(camp),
    );
  }

  static FightWeekCut? _cutFor(WeightPath path) {
    const epsilon = 1e-9;
    switch (path.status) {
      case WeightPathStatus.notSupported:
      case WeightPathStatus.needsScreening:
      case WeightPathStatus.needsProfessionalReview:
        return null;
      case WeightPathStatus.needsMoreData:
      case WeightPathStatus.notSafe:
        return FightWeekCut.notPlanned;
      case WeightPathStatus.atWeight:
        return FightWeekCut.none;
      case WeightPathStatus.needsSupervision:
        return FightWeekCut.notPlanned;
      case WeightPathStatus.onTrack:
        final fraction = path.acuteLossFraction;
        if (fraction <= epsilon) return FightWeekCut.none;
        if (fraction <= WeightCutPolicy.lowFibreAcuteFraction + epsilon) {
          return FightWeekCut.lowFibre;
        }
        return FightWeekCut.lowFibreAndCarbs;
    }
  }

  static List<FightWeekStep> _stepsFor(
    FightWeekCut cut,
    int toWeighIn,
    int toFight,
  ) {
    if (toWeighIn > 0) {
      return switch (cut) {
        FightWeekCut.notPlanned => const [],
        FightWeekCut.none => const [FightWeekStep.eatToPlan],
        _ when toWeighIn > WeightCutPolicy.lowFibreDays => const [
            FightWeekStep.eatToPlan
          ],
        FightWeekCut.lowFibre => const [FightWeekStep.lowFibre],
        FightWeekCut.lowFibreAndCarbs => const [
            FightWeekStep.lowFibre,
            FightWeekStep.lowerCarbs,
          ],
      };
    }
    if (toWeighIn == 0) {
      return [
        FightWeekStep.weighIn,
        if (cut != FightWeekCut.notPlanned) FightWeekStep.refuel,
        if (toFight == 0) FightWeekStep.fight,
      ];
    }
    return toFight == 0
        ? const [FightWeekStep.fight]
        : cut == FightWeekCut.notPlanned
            ? const []
            : const [FightWeekStep.refuel];
  }
}
