import '../fight_camp.dart';

enum CampLengthCaution {
  /// The cut from walk-around weight to the limit is more than
  /// [CampLengthCheck.cautionLossFraction] of walk-around weight.
  largeTotalLoss,

  /// A cut with less than [CampLengthCheck.minCampWeeks] weeks to the
  /// weigh-in.
  shortCamp,
}

class CampLengthResult {
  const CampLengthResult._({
    required this.cautions,
    required this.totalLossKg,
    required this.totalLossFraction,
    required this.daysToWeighIn,
  });

  final Set<CampLengthCaution> cautions;

  /// Walk-around weight minus the limit, never below zero.
  final double totalLossKg;

  /// [totalLossKg] as a share of walk-around weight (0.12 is 12%).
  final double totalLossFraction;

  final int daysToWeighIn;

  bool get showCaution => cautions.isNotEmpty;

  /// Above the top of the 12-15% band, not only its bottom.
  bool get aboveUpperBand =>
      totalLossFraction > CampLengthCheck.upperLossFraction + 1e-9;
}

/// The camp-length check (Fuel V2 N4; combat research §9.1): ISSN 2025
/// point 3 puts the walk-around weight 12-15% above the class limit at
/// most, for camps of 8 weeks or more. A bigger total cut, or any cut in a
/// shorter camp, raises the risk of low energy availability, so it shows a
/// caution. A caution, not a block: the weight path still applies its own
/// limits.
///
/// Pure Dart: no clock, no platform, no network. Callers pass [today].
// dietitian sign-off pending: the 12%, 15% and 8-week thresholds and the
// caution wording.
class CampLengthCheck {
  const CampLengthCheck._();

  /// The bottom of the 12-15% band: the caution starts here.
  static const double cautionLossFraction = 0.12;

  /// The top of the band.
  static const double upperLossFraction = 0.15;

  static const int minCampWeeks = 8;

  /// Null when [walkAroundWeightKg] is not a real weight or the weigh-in has
  /// passed.
  static CampLengthResult? evaluate({
    required double walkAroundWeightKg,
    required FightCamp camp,
    required DateTime today,
  }) {
    final walkAround = walkAroundWeightKg;
    if (!walkAround.isFinite || walkAround <= 0) return null;
    final days = camp.daysToWeighIn(today);
    if (days < 0) return null;
    final loss =
        walkAround > camp.weightLimitKg ? walkAround - camp.weightLimitKg : 0.0;
    final fraction = loss / walkAround;
    return CampLengthResult._(
      cautions: {
        if (fraction > cautionLossFraction + 1e-9)
          CampLengthCaution.largeTotalLoss,
        if (loss > 0 && days < minCampWeeks * 7) CampLengthCaution.shortCamp,
      },
      totalLossKg: loss,
      totalLossFraction: fraction,
      daysToWeighIn: days,
    );
  }
}
