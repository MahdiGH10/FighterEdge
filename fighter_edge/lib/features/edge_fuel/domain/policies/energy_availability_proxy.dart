import 'nutrition_policy_v2.dart';

/// A proxy floor for energy availability (EA) in training athletes.
///
/// "Never below resting energy" does not protect someone training five times
/// a week: their intake can sit at resting energy while they spend several
/// hundred kcal a day in the gym. EA proper is
/// `(intake - exercise energy) / fat-free mass`, and the IOC 2023 REDs
/// consensus treats about 30 kcal/kg FFM as a risk marker, not a threshold.
/// Fuel has no body-fat figure, so it uses a proxy that needs only numbers it
/// already has:
///
/// ```text
/// floor = resting energy + 0.5 x average planned session energy per day
/// ```
///
/// DIETITIAN SIGN-OFF PENDING: the 0.5 is a placeholder from
/// `docs/nutrition_research_20261022/targets.md` section 4.5 (gap G3). It is
/// not reviewed by a qualified dietitian and nothing may present it as
/// clinically validated. [dietitianSignOffPending] stays `true` until one has
/// signed it off. The floor only ever stops a target going lower; it never
/// raises a target by itself except to lift a fat-loss goal back to it.
class EnergyAvailabilityProxy {
  const EnergyAvailabilityProxy._();

  /// See the class comment. Do not flip without a recorded sign-off.
  static const bool dietitianSignOffPending = true;

  /// Share of the average planned session energy added to resting energy.
  static const double sessionShare = 0.5;

  /// The lowest weekly-average target, in kcal per day, for an athlete with
  /// [restingEnergyKcal] and [averageSessionKcalPerDay] of planned training.
  /// Rounded up to ten. A missing, non-finite or negative session figure counts
  /// as no training, so the floor is never below resting energy.
  static int floorKcal({
    required double restingEnergyKcal,
    required double averageSessionKcalPerDay,
  }) {
    if (!restingEnergyKcal.isFinite || restingEnergyKcal <= 0) return 0;
    final sessions =
        averageSessionKcalPerDay.isFinite && averageSessionKcalPerDay > 0
            ? averageSessionKcalPerDay
            : 0.0;
    return NutritionPolicyV2.ceilToTen(
      restingEnergyKcal + sessionShare * sessions,
    );
  }
}
