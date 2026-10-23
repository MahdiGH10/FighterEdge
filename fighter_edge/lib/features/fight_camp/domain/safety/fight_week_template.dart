import '../calendar.dart';
import '../fight_camp.dart';
import '../fight_week_plan.dart';
import '../weight_cut_policy.dart';
import '../weight_path.dart';
import 'cut_safety_screen.dart';
import 'fighter_safety_flags.dart';
import 'refuel_timeline.dart';

enum TemplateDayKind { fightWeek, weighIn, refuel, fight, postFight }

enum TemplateTraining {
  lastHardSession,
  hardThenTaper,
  moderate,
  lightTechnique,
  light,
  veryLight,
  restOrShakeout,
  none,
  perEvent,
  rest,
}

enum TemplateFood {
  /// The camp targets, unchanged.
  eatAsCamp,

  /// Try the foods planned for after the weigh-in.
  practiseRefuelFoods,

  steadyProtein,

  /// From the fight-week plan ([FightWeekStep.lowFibre]).
  lowerFibre,

  /// From the fight-week plan ([FightWeekStep.lowerCarbs]).
  lowerCarbs,

  smallFrequentMeals,
  avoidNewFoods,
  familiarFoods,

  /// Eat every planned meal.
  regularMeals,

  /// See the [RefuelTimeline].
  followRefuelTimeline,

  /// See [RefuelWindow.fightDay].
  fightDayFuel,

  returnToMaintenance,
  highProtein,
  noDeficit,
}

enum TemplateHydration {
  /// Drink to thirst, as normal. The app never gives restriction advice.
  drinkToThirst,

  /// After the scale: the refuel timeline.
  refuelAfterScale,
}

enum TemplateCheck {
  trendVsEntryWeight,
  confirmWeighInRules,
  sleepAndMood,
  reviewPathStatus,
  confirmVenueAndScale,

  /// Still more than the food-only share above the limit: stop and talk to
  /// a professional ([CutSafetyReason.overLimitNearWeighIn]).
  overLimitReferral,

  packingList,

  /// Over the limit the day before: options are a supervised cut, a
  /// different class or withdrawing. Never tips.
  weightOptions,

  logWeighInWeight,
  logWeightRegain,
  reportSymptoms,
  medicalCheckIfInjured,
}

/// Caveats the card always shows.
enum TemplateCaveat {
  generalInformationForHealthyAdults,
  notAWeightLossPlan,
  overLimitTalkToCoachOrDietitian,
  notMedicalAdvice,
}

class FightWeekTemplateDay {
  const FightWeekTemplateDay({
    required this.kind,
    required this.date,
    required this.daysToWeighIn,
    required this.daysToFight,
    required this.training,
    required this.food,
    required this.hydration,
    required this.checks,
  });

  final TemplateDayKind kind;

  /// For [TemplateDayKind.postFight], the first day of the week after.
  final DateTime date;

  /// 7 on D-7, 0 on the weigh-in, negative after it.
  final int daysToWeighIn;
  final int daysToFight;

  final TemplateTraining training;
  final List<TemplateFood> food;
  final TemplateHydration hydration;
  final List<TemplateCheck> checks;

  bool get isWeighInDay => daysToWeighIn == 0;
  bool get isFightDay => daysToFight == 0;
}

/// The fight-week information template, D-7 to fight day and the week
/// after (Fuel V2 N4; combat research §8). Information, not a prescription:
/// the only food changes come from [FightWeekPlan], water is never
/// restricted, and amounts live on the [RefuelTimeline] behind their own
/// flag.
///
/// Shown only to adults who are cleared by the [CutSafetyScreen] and are on
/// track or at weight, and only with [FighterSafetyFlags.fightWeekTemplate]
/// on (rule 8).
///
/// Pure Dart: no clock, no platform, no network.
// dietitian sign-off pending: day contents, checks and caveats.
class FightWeekTemplate {
  const FightWeekTemplate._({
    required this.cut,
    required this.days,
    required this.refuel,
  });

  final FightWeekCut cut;

  /// D-7 to fight day, one a calendar day, then one post-fight entry.
  final List<FightWeekTemplateDay> days;

  final RefuelTimeline refuel;

  static const List<TemplateCaveat> caveats = TemplateCaveat.values;

  /// The day for [today], or null outside the template's dates. Any day in
  /// the week after the fight returns the post-fight entry.
  FightWeekTemplateDay? dayOn(DateTime today) {
    final index = daysBetween(days.first.date, today);
    if (index < 0) return null;
    if (index < days.length - 1) return days[index];
    final post = days.last;
    final intoPost = daysBetween(post.date, today);
    return intoPost >= 0 && intoPost < FightCamp.postFightDays ? post : null;
  }

  static const Set<WeightPathStatus> eligibleStatuses = {
    WeightPathStatus.onTrack,
    WeightPathStatus.atWeight,
  };

  /// Null unless the flag is on, [safety] is cleared, [ageYears] is a valid
  /// adult age and [path] is on track or at weight.
  ///
  /// [path] should be the one [FightWeekPlan.plan] fixes at the start of
  /// fight week. [hoursWeighInToFight] is passed to [RefuelTimeline.build].
  static FightWeekTemplate? build({
    required FightCamp camp,
    required WeightPath path,
    required CutSafetyDecision safety,
    required int? ageYears,
    int? hoursWeighInToFight,
    FighterSafetyFlags flags = FighterSafetyFlags.off,
  }) {
    if (!flags.fightWeekTemplate) return null;
    if (!safety.showCutTools) return null;
    if (!eligibleStatuses.contains(path.status)) return null;
    final plan = FightWeekPlan.build(camp: camp, path: path);
    final refuel = RefuelTimeline.build(
      camp: camp,
      ageYears: ageYears,
      hoursWeighInToFight: hoursWeighInToFight,
      flags: flags,
    );
    if (plan == null || refuel == null) return null;

    final days = <FightWeekTemplateDay>[
      for (final day in plan.days) _day(day),
      FightWeekTemplateDay(
        kind: TemplateDayKind.postFight,
        date: addDays(camp.fightDate, 1),
        daysToWeighIn: -daysBetween(camp.weighInDate, camp.fightDate) - 1,
        daysToFight: -1,
        training: TemplateTraining.rest,
        food: const [
          TemplateFood.returnToMaintenance,
          TemplateFood.highProtein,
          TemplateFood.noDeficit,
        ],
        hydration: TemplateHydration.drinkToThirst,
        checks: const [TemplateCheck.medicalCheckIfInjured],
      ),
    ];
    return FightWeekTemplate._(cut: plan.cut, days: days, refuel: refuel);
  }

  static FightWeekTemplateDay _day(FightWeekDay day) {
    final toWeighIn = day.daysToWeighIn;
    final planned = [
      for (final step in day.steps)
        if (step == FightWeekStep.eatToPlan)
          TemplateFood.eatAsCamp
        else if (step == FightWeekStep.lowFibre)
          TemplateFood.lowerFibre
        else if (step == FightWeekStep.lowerCarbs)
          TemplateFood.lowerCarbs,
    ];

    if (day.isFight) {
      return FightWeekTemplateDay(
        kind: TemplateDayKind.fight,
        date: day.date,
        daysToWeighIn: toWeighIn,
        daysToFight: 0,
        training: TemplateTraining.perEvent,
        food: [
          if (day.isWeighIn) TemplateFood.followRefuelTimeline,
          TemplateFood.fightDayFuel,
          TemplateFood.avoidNewFoods,
        ],
        hydration: day.isWeighIn
            ? TemplateHydration.refuelAfterScale
            : TemplateHydration.drinkToThirst,
        checks: [
          if (day.isWeighIn) TemplateCheck.logWeighInWeight,
          TemplateCheck.reportSymptoms,
        ],
      );
    }
    if (day.isWeighIn) {
      return FightWeekTemplateDay(
        kind: TemplateDayKind.weighIn,
        date: day.date,
        daysToWeighIn: 0,
        daysToFight: day.daysToFight,
        training: TemplateTraining.none,
        food: const [TemplateFood.followRefuelTimeline],
        hydration: TemplateHydration.refuelAfterScale,
        checks: const [TemplateCheck.logWeighInWeight],
      );
    }
    if (toWeighIn < 0) {
      return FightWeekTemplateDay(
        kind: TemplateDayKind.refuel,
        date: day.date,
        daysToWeighIn: toWeighIn,
        daysToFight: day.daysToFight,
        training: TemplateTraining.rest,
        food: const [
          TemplateFood.followRefuelTimeline,
          TemplateFood.smallFrequentMeals,
          TemplateFood.avoidNewFoods,
        ],
        hydration: TemplateHydration.drinkToThirst,
        checks: const [TemplateCheck.logWeightRegain],
      );
    }

    final (training, extraFood, checks) = switch (toWeighIn) {
      7 => (
          TemplateTraining.lastHardSession,
          const [TemplateFood.practiseRefuelFoods],
          const [
            TemplateCheck.trendVsEntryWeight,
            TemplateCheck.confirmWeighInRules,
          ],
        ),
      6 => (
          TemplateTraining.hardThenTaper,
          const [TemplateFood.steadyProtein],
          const [TemplateCheck.sleepAndMood],
        ),
      5 => (
          TemplateTraining.moderate,
          const [TemplateFood.steadyProtein],
          const [TemplateCheck.reviewPathStatus],
        ),
      4 => (
          TemplateTraining.lightTechnique,
          const [TemplateFood.steadyProtein],
          const [TemplateCheck.confirmVenueAndScale],
        ),
      3 => (
          TemplateTraining.light,
          const [TemplateFood.smallFrequentMeals, TemplateFood.steadyProtein],
          const [TemplateCheck.overLimitReferral],
        ),
      2 => (
          TemplateTraining.veryLight,
          const [TemplateFood.avoidNewFoods],
          const [TemplateCheck.reviewPathStatus, TemplateCheck.packingList],
        ),
      _ => (
          TemplateTraining.restOrShakeout,
          const [TemplateFood.familiarFoods, TemplateFood.regularMeals],
          const [TemplateCheck.weightOptions],
        ),
    };
    assert(toWeighIn >= 1 && toWeighIn <= WeightCutPolicy.fightWeekDays);
    return FightWeekTemplateDay(
      kind: TemplateDayKind.fightWeek,
      date: day.date,
      daysToWeighIn: toWeighIn,
      daysToFight: day.daysToFight,
      training: training,
      food: [...planned, ...extraFood],
      hydration: TemplateHydration.drinkToThirst,
      checks: checks,
    );
  }
}
