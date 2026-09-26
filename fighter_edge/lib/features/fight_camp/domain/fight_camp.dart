import 'calendar.dart';
import 'weight_cut_policy.dart';

/// Where an athlete is relative to their next fight.
enum CampPhase {
  /// No fight close enough to plan around.
  offCamp,

  /// The weeks of preparation before fight week.
  camp,

  /// The last seven days before the weigh-in, and the weigh-in day itself.
  fightWeek,

  /// After the weigh-in day, up to and including fight day. Only exists
  /// when the weigh-in is on an earlier day than the fight.
  refuel,

  /// The week after the fight.
  postFight,
}

/// A fight on the calendar: the dates and the weight to make.
class FightCamp {
  const FightCamp._({
    required this.fightDate,
    required this.weighInDate,
    required this.weightLimitKg,
    required this.category,
    required this.campWeeks,
  });

  /// Returns null when the inputs cannot describe a real fight: a weigh-in
  /// after the fight or more than [maxWeighInLeadDays] before it, a limit
  /// outside the app's weigh-in range, or a camp length outside
  /// [minCampWeeks]–[maxCampWeeks].
  ///
  /// [weighInDate] defaults to [fightDate] (a same-day weigh-in).
  static FightCamp? tryCreate({
    required DateTime fightDate,
    DateTime? weighInDate,
    required double weightLimitKg,
    required CompetitionCategory category,
    int campWeeks = defaultCampWeeks,
  }) {
    final fight = calendarDay(fightDate);
    final weighIn = calendarDay(weighInDate ?? fightDate);
    final lead = daysBetween(weighIn, fight);
    if (lead < 0 || lead > maxWeighInLeadDays) return null;
    if (!weightLimitKg.isFinite ||
        weightLimitKg < minWeightLimitKg ||
        weightLimitKg > maxWeightLimitKg) {
      return null;
    }
    if (campWeeks < minCampWeeks || campWeeks > maxCampWeeks) return null;
    return FightCamp._(
      fightDate: fight,
      weighInDate: weighIn,
      weightLimitKg: weightLimitKg,
      category: category,
      campWeeks: campWeeks,
    );
  }

  /// App defaults, not values from the position stand.
  static const int defaultCampWeeks = 8;
  static const int minCampWeeks = 4;
  static const int maxCampWeeks = 16;
  static const int maxWeighInLeadDays = 2;
  static const int postFightDays = 7;

  /// The range the weigh-in dialog accepts.
  static const double minWeightLimitKg = 35;
  static const double maxWeightLimitKg = 220;

  final DateTime fightDate;
  final DateTime weighInDate;
  final double weightLimitKg;
  final CompetitionCategory category;
  final int campWeeks;

  /// The first day of fight week.
  DateTime get fightWeekStart =>
      addDays(weighInDate, -WeightCutPolicy.fightWeekDays);

  int daysToWeighIn(DateTime today) => daysBetween(today, weighInDate);

  int daysToFight(DateTime today) => daysBetween(today, fightDate);

  CampPhase phaseOn(DateTime today) {
    final toWeighIn = daysToWeighIn(today);
    final toFight = daysToFight(today);
    if (toFight < -postFightDays) return CampPhase.offCamp;
    if (toFight < 0) return CampPhase.postFight;
    if (toWeighIn < 0) return CampPhase.refuel;
    if (toWeighIn <= WeightCutPolicy.fightWeekDays) return CampPhase.fightWeek;
    if (toWeighIn <= campWeeks * 7) return CampPhase.camp;
    return CampPhase.offCamp;
  }
}
