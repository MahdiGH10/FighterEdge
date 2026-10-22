import 'nutrition_policy_v2.dart';

/// Constants for day-type fuel guidance (Fuel V2, slice N3).
///
/// DIETITIAN SIGN-OFF PENDING: every number here is a published range copied
/// from `docs/nutrition_research_20261022/combat.md` (ISSN 2025 combat sports
/// position stand, ISSN 2017 nutrient timing, ACSM 2021 weight-category
/// consensus). The day-type to range mapping is a synthesis the research
/// report itself marks "information tier, needs dietitian sign-off". None of
/// it has been reviewed by a qualified dietitian, and
/// [dietitianSignOffPending] stays `true` until one has. The values are
/// guidance ranges for display and for ranking snack suggestions. They never
/// change a stored target: targets change only when the user taps Apply.
class FuelDayPolicy {
  const FuelDayPolicy._();

  /// Bump when any value in this class changes.
  static const int version = 1;

  /// See the class comment. Do not flip without a recorded sign-off.
  static const bool dietitianSignOffPending = true;

  // ---- day classification ----

  /// A session shorter than this does not count toward a double day. It still
  /// counts as training for the rest/easy split.
  static const int minimumCountedSessionMinutes = 20;

  /// A day whose planned sessions cost at least this many kcal per kg of body
  /// weight is hard even with no hard session in it. Shared with policy v2 so
  /// the target split and the day type never disagree.
  static const double hardDaySessionKcalPerKg =
      NutritionPolicyV2.hardDaySessionKcalPerKg;

  // ---- carbohydrate tiers, g per kg body weight per day ----
  // combat.md section 2.2, from ISSN 2025 light-activity range and ACSM 2021
  // Table 3 (moderate and heavy load).
  static const double carbLightLow = 3.0;
  static const double carbLightHigh = 5.0;
  static const double carbModerateLow = 5.0;
  static const double carbModerateHigh = 7.0;
  static const double carbHeavyLow = 6.0;
  static const double carbHeavyHigh = 10.0;

  /// Hard floor on every day (ISSN 2025 position 6, 3.0-4.0 g/kg while
  /// energy-restricted). Shared with policy v2.
  static const double carbFloorGPerKg = NutritionPolicyV2.carbFloorGPerKg;

  /// Proposed higher floor on a double day. The research report lists 3.5-4.0
  /// as a dietitian decision; the lower end is used until one is made.
  static const double carbFloorDoubleDayGPerKg = 3.5;

  // ---- protein, g per kg, flat across day types ----
  // ISSN 2025 practical application 1.6-2.2 g/kg.
  static const double proteinLowGPerKg = 1.6;
  static const double proteinHighGPerKg = 2.2;

  /// Hard floor, shared with policy v2.
  static const double proteinFloorGPerKg = NutritionPolicyV2.proteinFloorGPerKg;

  // ---- fat, g per kg ----
  // ISSN 2025: minimum 0.5-1.0 (position 6), body text 0.7-1.3.
  static const double fatLowGPerKg = 0.7;
  static const double fatHighGPerKg = 1.3;

  /// Hard floor, shared with policy v2.
  static const double fatFloorGPerKg = NutritionPolicyV2.fatFloorGPerKg;

  // ---- before a session ----
  // ISSN 2017: 1-4 g/kg carbohydrate several hours before a higher-intensity
  // or longer than 90 minute session. ISSN 2025: a meal 2-3 h before the
  // first session.
  static const double preCarbLowGPerKg = 1.0;
  static const double preCarbHighGPerKg = 4.0;
  static const int preMealLeadHoursMin = 2;
  static const int preMealLeadHoursMax = 3;

  /// A session longer than this counts as long for the pre-session rule.
  static const int longSessionMinutes = 90;

  // ---- after a session ----
  // ISSN 2017: 0.25-0.40 g/kg protein per dose, from immediately to 2 h after.
  static const double postProteinLowGPerKg = 0.25;
  static const double postProteinHighGPerKg = 0.40;
  static const int postProteinWithinHours = 2;

  // ISSN 2017: 0.6-1.0 g/kg carbohydrate within 30 minutes as the standard.
  static const double postCarbLowGPerKg = 0.6;
  static const double postCarbHighGPerKg = 1.0;
  static const int postCarbWithinMinutes = 30;

  // ACSM 2021 about 1 g/kg/h and ISSN 2017 1.2 g/kg/h when the next session
  // is under 4 hours away.
  static const double quickCarbLowGPerKgPerHour = 1.0;
  static const double quickCarbHighGPerKgPerHour = 1.2;
  static const int quickTurnaroundHours = 4;

  // ---- gap picker ----

  /// ISSN 2017: one protein dose is 0.25-0.40 g/kg. A protein gap above the
  /// upper end is split over more than one eating occasion.
  static const double maxProteinPerMealGPerKg = postProteinHighGPerKg;

  /// Per-meal protein cap in grams when body weight is unknown (ISSN 2017
  /// upper end of 20-40 g).
  static const int maxProteinPerMealGramsFallback = 40;

  /// Never split into more than this many eating occasions.
  static const int maxSplitParts = 3;
}
