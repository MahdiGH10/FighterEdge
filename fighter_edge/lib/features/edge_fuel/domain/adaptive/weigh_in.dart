import 'calendar_day.dart';

/// Under which conditions a weigh-in was taken. Only a standard weigh-in is
/// comparable day to day; after training, a sweat loss or a meal can swing a
/// fighter's scale weight by 1 to 2 kg.
enum WeighInCondition {
  /// Morning, after the toilet, before food and fluid. The reference.
  morningFasted,

  /// Morning, but after food or fluid.
  morning,

  /// After a training session.
  afterTraining,

  /// Any other time or unknown.
  other,
}

/// One scale reading.
class WeighIn {
  const WeighIn({
    required this.day,
    required this.kg,
    this.condition = WeighInCondition.morningFasted,
    this.inFightWeek = false,
  });

  final CalendarDay day;
  final double kg;
  final WeighInCondition condition;

  /// Taken in fight week, when the camp plan owns weight and the decision
  /// slope ignores it.
  final bool inFightWeek;

  static const double minValidKg = 20;
  static const double maxValidKg = 250;

  /// Finite and between [minValidKg] and [maxValidKg].
  bool get isValid => kg.isFinite && kg >= minValidKg && kg <= maxValidKg;

  /// Morning readings count for the decision slope. `morning` (not fasted) is
  /// accepted: a few hundred grams of food is smaller than the noise band.
  bool get isStandardCondition =>
      condition == WeighInCondition.morningFasted ||
      condition == WeighInCondition.morning;

  /// Usable for tiers and the decision slope: valid, standard, not fight week.
  bool get isUsable => isValid && isStandardCondition && !inFightWeek;
}
