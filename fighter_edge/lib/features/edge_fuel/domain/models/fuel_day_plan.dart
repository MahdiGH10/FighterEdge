import 'planned_fuel_session.dart';

/// How a calendar day is fuelled, from the dated training plan.
///
/// Pure classification: no number here is a target. The numbers live in
/// `FuelDayPolicy` and are marked dietitian sign-off pending.
enum FuelDayType {
  /// No planned training.
  rest,

  /// Planned training, none of it hard, and not a double day.
  easy,

  /// A hard session, or a day of heavy total session energy.
  hard,

  /// Two or more sessions on one day, at least one beyond light.
  doubleDay,

  /// Inside the fight window: seven days before the weigh-in through fight
  /// day. The classification only says "fight week". The guidance for the day
  /// follows its training load, and nothing here restricts food or fluid.
  fightWeek,
}

/// Carbohydrate tier for a day, a range in g per kg of body weight.
enum CarbTier { light, moderate, heavy }

/// One dated session of the plan, in the pure input type Fuel works with.
///
/// Fuel does not import the training-plan feature. The caller maps its dated
/// plan onto this type, as it already does for [PlannedFuelSession].
class FuelDatedSession {
  const FuelDatedSession({
    required this.date,
    required this.discipline,
    required this.intensity,
    required this.durationMinutes,
    this.startMinuteOfDay,
  });

  /// Only the calendar day (year, month, day) is read.
  final DateTime date;
  final FuelDiscipline discipline;
  final FuelIntensity intensity;
  final int durationMinutes;

  /// Local start time as minutes after midnight, 0 to 1439, when known. Used
  /// only to order two sessions on one day and to size the gap between them.
  final int? startMinuteOfDay;

  /// The session as the energy table sees it.
  PlannedFuelSession toPlannedFuelSession(int dayIndex) => PlannedFuelSession(
        dayIndex: dayIndex,
        discipline: discipline,
        intensity: intensity,
        durationMinutes: durationMinutes,
      );
}

/// The fight window: the first day of fight week through fight day.
///
/// The caller builds it from its fight camp. Fuel only needs the two dates.
class FuelFightWindow {
  /// [fightWeekDays] defaults to the seven days before the weigh-in.
  const FuelFightWindow({
    required this.weighInDate,
    required this.fightDate,
    this.fightWeekDays = 7,
  });

  final DateTime weighInDate;
  final DateTime fightDate;
  final int fightWeekDays;

  bool contains(DateTime date) {
    final day = FuelCalendar.dayNumber(date);
    final weighIn = FuelCalendar.dayNumber(weighInDate);
    final fight = FuelCalendar.dayNumber(fightDate);
    return day >= weighIn - fightWeekDays && day <= fight;
  }
}

/// Calendar-day arithmetic without a clock, a time zone or DST. A date is
/// reduced to the number of days since the epoch for its year, month and day.
class FuelCalendar {
  const FuelCalendar._();

  static int dayNumber(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day)
          .difference(DateTime.utc(1970))
          .inDays;

  static bool sameDay(DateTime a, DateTime b) => dayNumber(a) == dayNumber(b);
}

/// The fuel classification of one day.
class FuelDayPlan {
  const FuelDayPlan({
    required this.date,
    required this.type,
    required this.load,
    required this.carbTier,
    required this.sessions,
    required this.sessionKcalPerKg,
  });

  final DateTime date;

  /// What the day is called. [FuelDayType.fightWeek] wins over [load].
  final FuelDayType type;

  /// The day type from training alone: never [FuelDayType.fightWeek].
  final FuelDayType load;

  final CarbTier carbTier;

  /// The day's sessions in time order, shortest-duration noise removed.
  final List<FuelDatedSession> sessions;

  /// Planned session energy per kg of body weight, from the energy table.
  final double sessionKcalPerKg;

  bool get isFightWeek => type == FuelDayType.fightWeek;
  bool get hasTraining => load != FuelDayType.rest;
}
