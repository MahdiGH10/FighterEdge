import '../calculators/weekly_check_in.dart';
import '../policies/weight_rate_policy.dart';
import 'calendar_day.dart';
import 'fuel_log_day.dart';
import 'weigh_in.dart';
import 'weight_slope.dart';

/// How much the app may do with the data so far.
enum DataTier {
  /// Starting estimate: formula only, no proposals.
  tier0,

  /// Trend check-in: may propose a within-limits correction.
  tier1,

  /// Adaptive expenditure: may also show observed expenditure.
  tier2,
}

/// The tier and the numbers behind it.
class DataTierAssessment {
  const DataTierAssessment({
    required this.tier,
    required this.reasons,
    required this.dataDays,
    required this.thisWeek,
    required this.lastWeek,
    required this.weekBefore,
    required this.weighInDaysThisWeek,
    required this.weighInDaysLastWeek,
    required this.weighInDaysIn21,
  });

  final DataTier tier;

  /// Why the tier is not higher. Empty for [DataTier.tier2]; for tier 1 it
  /// holds the reasons tier 2 is not reached, as information only.
  final List<CheckInReason> reasons;

  /// Days of data since the target started, counting the first day.
  final int dataDays;

  /// The last 7 days, the 7 before, and the 7 before those.
  final LogWindow thisWeek;
  final LogWindow lastWeek;
  final LogWindow weekBefore;

  /// Distinct days with a usable weigh-in.
  final int weighInDaysThisWeek;
  final int weighInDaysLastWeek;
  final int weighInDaysIn21;

  bool get mayPropose => tier != DataTier.tier0;
}

/// Decides the [DataTier]. Pure: the caller passes `asOf`, the last day of
/// data to consider (inclusive; the last closed day, normally yesterday).
///
/// - Tier 0: fewer than 14 days of data since the target started, or the
///   Tier 1 gates are not met. Formula only.
/// - Tier 1: 14 or more days of data; at least 5 counted days in each of the
///   last 2 weeks; at least 3 usable weigh-in days in each of those weeks.
/// - Tier 2: Tier 1, plus 21 or more days of data, at least 6 counted days in
///   at least 2 of the last 3 weeks, at least 12 usable weigh-in days in 21,
///   and no day marked partial in those 21 days.
///
/// Thresholds are implementation defaults from
/// `docs/nutrition_research_20261022/targets.md` section 4.1, pending
/// dietitian review. The "or 8 weigh-ins in 14 days" alternative in that
/// table is not used: 3 a week, two weeks running, is the stricter reading
/// and the spec's.
class DataTierEvaluator {
  const DataTierEvaluator._();

  static const int tier1MinDataDays = 14;
  static const int tier1MinDaysLoggedPerWeek = 5;
  static const int tier1MinWeighInDaysPerWeek = 3;

  static const int tier2MinDataDays = 21;
  static const int tier2MinDaysLoggedPerWeek = 6;
  static const int tier2MinGoodWeeksOfThree = 2;
  static const int tier2MinWeighInDays = 12;

  static DataTierAssessment evaluate({
    required CalendarDay asOf,
    required CalendarDay targetStart,
    required double targetKcal,
    required List<FuelLogDay> logDays,
    required List<WeighIn> weighIns,
  }) {
    final dataDays = targetStart.daysUntil(asOf) + 1;
    LogWindow week(int back) => LoggingSummary.window(
          logDays,
          endDay: asOf.plusDays(-7 * back),
          targetKcal: targetKcal,
        );
    final thisWeek = week(0);
    final lastWeek = week(1);
    final weekBefore = week(2);

    final usableDays = <int>{
      for (final w in weighIns)
        if (w.isUsable && !w.day.isAfter(asOf)) w.day.epochDay,
    };
    int weighInDays(int from, int to) => usableDays
        .where((d) => d >= asOf.epochDay - from && d <= asOf.epochDay - to)
        .length;
    final wThis = weighInDays(6, 0);
    final wLast = weighInDays(13, 7);
    final wIn21 = weighInDays(20, 0);

    final tier1Reasons = <CheckInReason>[
      if (dataDays < tier1MinDataDays) CheckInReason.programTooNew,
      if (thisWeek.daysCounted < tier1MinDaysLoggedPerWeek ||
          lastWeek.daysCounted < tier1MinDaysLoggedPerWeek)
        CheckInReason.insufficientLogging,
      if (wThis < tier1MinWeighInDaysPerWeek ||
          wLast < tier1MinWeighInDaysPerWeek)
        CheckInReason.insufficientWeighIns,
    ];

    DataTierAssessment build(DataTier tier, List<CheckInReason> reasons) =>
        DataTierAssessment(
          tier: tier,
          reasons: reasons,
          dataDays: dataDays,
          thisWeek: thisWeek,
          lastWeek: lastWeek,
          weekBefore: weekBefore,
          weighInDaysThisWeek: wThis,
          weighInDaysLastWeek: wLast,
          weighInDaysIn21: wIn21,
        );

    if (tier1Reasons.isNotEmpty) return build(DataTier.tier0, tier1Reasons);

    final goodWeeks = [thisWeek, lastWeek, weekBefore]
        .where((w) => w.daysCounted >= tier2MinDaysLoggedPerWeek)
        .length;
    final partialIn21 =
        thisWeek.partialDays + lastWeek.partialDays + weekBefore.partialDays;
    final tier2Reasons = <CheckInReason>[
      if (dataDays < tier2MinDataDays) CheckInReason.programTooNew,
      if (goodWeeks < tier2MinGoodWeeksOfThree)
        CheckInReason.insufficientLogging,
      if (wIn21 < tier2MinWeighInDays) CheckInReason.insufficientWeighIns,
      if (partialIn21 > 0) CheckInReason.partialLoggingFlagged,
    ];
    return tier2Reasons.isEmpty
        ? build(DataTier.tier2, const [])
        : build(DataTier.tier1, tier2Reasons);
  }
}

/// Observed energy expenditure, Tier 2 only and proposal only.
///
/// `expenditure = mean logged intake - slope (kg/day) x 7,700`. The 7,700
/// kcal/kg figure treats all weight as fat and overstates the effect of a
/// sustained deficit; the value is shown next to the formula maintenance, never
/// applied by itself. Wearable calories are not used.
class ObservedExpenditure {
  const ObservedExpenditure._();

  /// Null unless [tier] is Tier 2, the [slope] is usable and an intake exists.
  static double? kcalPerDay({
    required DataTier tier,
    required double? meanIntakeKcal,
    required WeightSlope slope,
  }) {
    if (tier != DataTier.tier2 || !slope.isUsable) return null;
    if (meanIntakeKcal == null || !meanIntakeKcal.isFinite) return null;
    return meanIntakeKcal - slope.slopeKgPerDay! * WeightRatePolicy.kcalPerKg;
  }
}
