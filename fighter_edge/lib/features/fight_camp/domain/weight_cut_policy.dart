import 'dart:math' as math;

/// Weight-cut limits, from the International Society of Sports Nutrition
/// position stand "Nutrition and weight cut strategies for mixed martial arts
/// and other combat sports" (J Int Soc Sports Nutr, 2025,
/// doi:10.1080/15502783.2025.2467909). Change a value only against that
/// source, and say where in it the new value comes from.
///
/// The app plans only what food can do. Water loss needs supervision
/// (point 10), so a plan that depends on it is flagged, never written out.
class WeightCutPolicy {
  WeightCutPolicy._();

  /// Fight camp: "0.5–1 kg of body mass each week" (section 5.2.1).
  static const double gentleWeeklyLossKg = 0.5;
  static const double maxWeeklyLossKg = 1.0;

  /// Fight week: the last seven days before the weigh-in.
  static const int fightWeekDays = 7;

  /// Fight-week loss from food alone: gut content from under 10 g of fibre a
  /// day for four days (1–2% of body mass) plus glycogen through
  /// carbohydrate restriction (1–2%) (point 9). The low end of each, so a
  /// plan never depends on the best case.
  static const double lowFibreAcuteFraction = 0.01;
  static const double lowCarbAcuteFraction = 0.01;
  static const double dietOnlyAcuteFraction =
      lowFibreAcuteFraction + lowCarbAcuteFraction;

  /// "A low-fiber intake of <10 g/day for 4 days" (point 9), ending the day
  /// before the weigh-in. The stand gives no length for carbohydrate
  /// restriction, so the plan uses the same days: one date when eating
  /// changes, not two.
  static const int lowFibreDays = 4;
  static const int lowFibreMaxGramsPerDay = 10;

  /// After the weigh-in: an oral rehydration solution at "1 to 1.5 liters/h"
  /// first (point 12), then fast-acting carbohydrate "at a tolerable rate of
  /// ≤ 60 g/h", with fibre kept low (point 13).
  static const double refuelMinLitresPerHour = 1.0;
  static const double refuelMaxLitresPerHour = 1.5;
  static const int refuelMaxCarbGramsPerHour = 60;

  /// Carbohydrate between weigh-in and fight: "About 4–7 g/kg may be
  /// suitable for modest carbohydrate restriction" (point 14). The 8–12 g/kg
  /// range is for significant glycogen depletion, which the app never plans.
  static const double refuelMinCarbGramsPerKg = 4;
  static const double refuelMaxCarbGramsPerKg = 7;

  /// The most body mass that can suitably be lost in the days before the
  /// weigh-in, food and water together: "6.7% at 72 h, 5.7% at 48 h, and
  /// 4.4% at 24 h, prior to weigh-in" (point 7).
  static double maxAcuteFraction(int daysToWeighIn) {
    if (daysToWeighIn >= 3) return 0.067;
    if (daysToWeighIn == 2) return 0.057;
    return 0.044;
  }

  /// The largest fight-week loss for [category], [daysToWeighIn] days out:
  /// food plus the category's sweat allowance, never above point 7.
  static double supervisedAcuteFraction(
    CompetitionCategory category,
    int daysToWeighIn,
  ) =>
      math.min(
        maxAcuteFraction(daysToWeighIn),
        dietOnlyAcuteFraction + category.maxSweatLossFraction,
      );

  /// Weight plans are for adults only. The position stand gives no
  /// guidance for minors, and the app's targets already refuse under 18.
  static const int minimumAgeYears = 18;
}

/// Competition formats grouped by how much sweat loss the position stand
/// allows before their weigh-in (Table 1, upper end of each range, "starting
/// in a euhydrated state"). The shorter the gap between weigh-in and the
/// first bout, the less there is time to recover.
enum CompetitionCategory {
  /// NCAA and Olympic freestyle wrestling, IBJJF, ADCC: 0–3%.
  grappling(0.03),

  /// Amateur boxing and amateur Muay Thai: 2–4%.
  amateurStriking(0.04),

  /// IJF judo, Olympic boxing, Olympic taekwondo: 3–5%.
  olympic(0.05),

  /// Professional MMA, boxing, kickboxing and Muay Thai: 4–6%.
  professional(0.06);

  const CompetitionCategory(this.maxSweatLossFraction);

  final double maxSweatLossFraction;
}
