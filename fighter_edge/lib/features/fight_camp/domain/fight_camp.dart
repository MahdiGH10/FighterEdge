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

  /// The camp week [today] falls in, 1-based, or null outside the camp
  /// phase. Week 1 starts [campWeeks] weeks before the weigh-in.
  int? campWeekOn(DateTime today) {
    if (phaseOn(today) != CampPhase.camp) return null;
    final daysIntoCamp = campWeeks * 7 - daysToWeighIn(today);
    return (daysIntoCamp ~/ 7 + 1).clamp(1, campWeeks);
  }

  /// Fight-week day [today] falls on, 1–7 (7 is the day before the
  /// weigh-in), 8 on the weigh-in day itself, or null outside fight week.
  int? fightWeekDayOn(DateTime today) {
    if (phaseOn(today) != CampPhase.fightWeek) return null;
    return WeightCutPolicy.fightWeekDays - daysToWeighIn(today) + 1;
  }

  Map<String, Object> toJson() => {
        'fightDate': _dateKey(fightDate),
        'weighInDate': _dateKey(weighInDate),
        'weightLimitKg': weightLimitKg,
        'category': category.name,
        'campWeeks': campWeeks,
      };

  /// Null for anything [tryCreate] would refuse, so a corrupt or hand-edited
  /// document reads as "no fight" instead of throwing.
  static FightCamp? fromJson(Map<String, dynamic> json) {
    final fight = _parseDateKey(json['fightDate']);
    final weighIn = _parseDateKey(json['weighInDate']);
    final limit = json['weightLimitKg'];
    final category = CompetitionCategory.values
        .where((c) => c.name == json['category'])
        .firstOrNull;
    final weeks = json['campWeeks'];
    if (fight == null || limit is! num || category == null) return null;
    return tryCreate(
      fightDate: fight,
      weighInDate: weighIn ?? fight,
      weightLimitKg: limit.toDouble(),
      category: category,
      campWeeks: weeks is int ? weeks : defaultCampWeeks,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FightCamp &&
      other.fightDate == fightDate &&
      other.weighInDate == weighInDate &&
      other.weightLimitKg == weightLimitKg &&
      other.category == category &&
      other.campWeeks == campWeeks;

  @override
  int get hashCode =>
      Object.hash(fightDate, weighInDate, weightLimitKg, category, campWeeks);
}

String _dateKey(DateTime date) => '${date.year.toString().padLeft(4, '0')}-'
    '${date.month.toString().padLeft(2, '0')}-'
    '${date.day.toString().padLeft(2, '0')}';

DateTime? _parseDateKey(Object? value) {
  if (value is! String) return null;
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  // Rejects "2026-02-31", which DateTime would silently roll into March.
  if (date.month != month || date.day != day) return null;
  return date;
}
