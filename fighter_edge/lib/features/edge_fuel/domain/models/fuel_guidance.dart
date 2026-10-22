import 'fuel_day_plan.dart';

/// Daily macro guidance for one day, as ranges in grams.
///
/// DIETITIAN SIGN-OFF PENDING (see `FuelDayPolicy`). Guidance only: it never
/// replaces or edits a stored target.
class FuelMacroGuidance {
  const FuelMacroGuidance({
    required this.dayType,
    required this.carbTier,
    required this.weightKg,
    required this.carbGramsLow,
    required this.carbGramsHigh,
    required this.carbFloorGrams,
    required this.proteinGramsLow,
    required this.proteinGramsHigh,
    required this.proteinFloorGrams,
    required this.fatGramsLow,
    required this.fatGramsHigh,
    required this.fatFloorGrams,
  });

  final FuelDayType dayType;
  final CarbTier carbTier;
  final double weightKg;

  final int carbGramsLow;
  final int carbGramsHigh;

  /// The lowest carbohydrate a day may be planned at.
  final int carbFloorGrams;

  final int proteinGramsLow;
  final int proteinGramsHigh;
  final int proteinFloorGrams;

  final int fatGramsLow;
  final int fatGramsHigh;
  final int fatFloorGrams;
}

/// Why a hint says what it says. Codes only: the screen owns the words.
enum FuelHintReason {
  /// A hard session, or one longer than 90 minutes.
  highIntensityOrLong,

  /// Keep fat low in the meal before a session.
  lowFatBeforeSession,

  /// Keep fibre low in the meal before a session.
  lowFibreBeforeSession,

  /// A protein dose in the recovery window.
  proteinDoseAfter,

  /// Carbohydrate soon after a hard or long session.
  carbRefillAfter,

  /// Another session follows later the same day.
  nextSessionSameDay,

  /// Another session follows in under four hours.
  nextSessionSoon,

  /// A moderate session: fuel is optional and no number applies.
  moderateSessionOptional,

  /// A light session: nothing special is needed.
  lightSession,
}

enum FuelHintNeed { none, optional, recommended }

/// A gram range scaled from a g/kg range, rounded to whole grams.
class GramRange {
  const GramRange(this.low, this.high);

  final int low;
  final int high;

  @override
  bool operator ==(Object other) =>
      other is GramRange && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => 'GramRange($low-$high)';
}

/// A g/kg range. Convert with [forWeight].
class PerKgRange {
  const PerKgRange(this.low, this.high);

  final double low;
  final double high;

  /// Whole grams for a body weight. Returns null for a weight that is not
  /// positive and finite.
  GramRange? forWeight(double weightKg) {
    if (!weightKg.isFinite || weightKg <= 0) return null;
    return GramRange((low * weightKg).round(), (high * weightKg).round());
  }

  @override
  bool operator ==(Object other) =>
      other is PerKgRange && other.low == low && other.high == high;

  @override
  int get hashCode => Object.hash(low, high);

  @override
  String toString() => 'PerKgRange($low-$high g/kg)';
}

/// Fuel before one session.
class PreSessionFuel {
  const PreSessionFuel({
    required this.need,
    this.carbs,
    this.mealLeadHoursMin,
    this.mealLeadHoursMax,
    this.reasons = const [],
  });

  final FuelHintNeed need;

  /// Carbohydrate for the pre-session meal, g/kg. Null when [need] is not
  /// [FuelHintNeed.recommended]: the research gives no number for those.
  final PerKgRange? carbs;

  /// How many hours before the session to eat, when [need] is recommended.
  final int? mealLeadHoursMin;
  final int? mealLeadHoursMax;
  final List<FuelHintReason> reasons;
}

/// Fuel after one session.
class PostSessionFuel {
  const PostSessionFuel({
    required this.need,
    this.protein,
    this.proteinWithinHours,
    this.carbs,
    this.carbWithinMinutes,
    this.carbsPerHour,
    this.carbsPerHourForHours,
    this.reasons = const [],
  });

  final FuelHintNeed need;

  /// One protein dose, g/kg.
  final PerKgRange? protein;
  final int? proteinWithinHours;

  /// Carbohydrate as one amount soon after the session, g/kg.
  final PerKgRange? carbs;
  final int? carbWithinMinutes;

  /// Carbohydrate as a rate, g/kg per hour, when the next session is soon.
  /// Replaces [carbs].
  final PerKgRange? carbsPerHour;
  final int? carbsPerHourForHours;
  final List<FuelHintReason> reasons;
}

/// Pre- and post-session fuel for one session of the plan.
class SessionFuelHint {
  const SessionFuelHint({
    required this.sessionIndex,
    required this.session,
    required this.pre,
    required this.post,
  });

  /// Position among the day's sessions, in time order, from 0.
  final int sessionIndex;
  final FuelDatedSession session;
  final PreSessionFuel pre;
  final PostSessionFuel post;
}
