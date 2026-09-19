import '../models/nutrition_day.dart';
import '../models/nutrition_target.dart';

/// How one day went against the target.
enum FuelDayStatus {
  /// Nothing logged — unknown, not zero. The log is the only evidence.
  notLogged,

  /// Logged, well under target.
  under,

  /// Within the on-target band.
  onTarget,

  /// Logged, well over target.
  over,
}

class FuelDaySummary {
  final String localDate;
  final int calories;
  final int proteinGrams;
  final FuelDayStatus status;

  const FuelDaySummary({
    required this.localDate,
    required this.calories,
    required this.proteinGrams,
    required this.status,
  });
}

class WeeklyFuelSummary {
  /// One entry per day, oldest first.
  final List<FuelDaySummary> days;
  final int targetCalories;
  final int targetProtein;

  const WeeklyFuelSummary({
    required this.days,
    required this.targetCalories,
    required this.targetProtein,
  });

  int get loggedDays =>
      days.where((d) => d.status != FuelDayStatus.notLogged).length;

  int get onTargetDays =>
      days.where((d) => d.status == FuelDayStatus.onTarget).length;

  /// Days that reached [WeeklyFuelCalculator.proteinHitRatio] of the protein
  /// target — for a fighter, usually the number that matters most.
  int get proteinHitDays => days
      .where((d) =>
          d.status != FuelDayStatus.notLogged &&
          targetProtein > 0 &&
          d.proteinGrams >=
              targetProtein * WeeklyFuelCalculator.proteinHitRatio)
      .length;

  /// Average over logged days only: unlogged days are unknown, and counting
  /// them as zero would invent a deficit.
  int? get averageCalories {
    final logged =
        days.where((d) => d.status != FuelDayStatus.notLogged).toList();
    if (logged.isEmpty) return null;
    return (logged.fold<int>(0, (sum, d) => sum + d.calories) / logged.length)
        .round();
  }
}

/// Summarises a run of logged days against the athlete's target. Pure: the
/// caller supplies the days, so there is no clock or storage in here.
class WeeklyFuelCalculator {
  WeeklyFuelCalculator._();

  /// ±10% of target counts as on target: tight enough to mean something,
  /// loose enough that logging estimates can still land in it.
  static const onTargetBand = 0.10;

  /// 90% of the protein target counts as hitting it.
  static const proteinHitRatio = 0.90;

  static WeeklyFuelSummary summarise({
    required List<NutritionDay> days,
    required NutritionTarget target,
  }) {
    final targetKcal = target.targetCalories ?? 0;
    final targetProtein = target.proteinGrams ?? 0;
    return WeeklyFuelSummary(
      targetCalories: targetKcal,
      targetProtein: targetProtein,
      days: [
        for (final day in days)
          FuelDaySummary(
            localDate: day.localDate,
            calories: day.totals.calories,
            proteinGrams: day.totals.proteinGrams,
            status: _statusOf(day, targetKcal),
          ),
      ],
    );
  }

  static FuelDayStatus _statusOf(NutritionDay day, int targetKcal) {
    final logged = day.entries.any((e) => e.consumed);
    if (!logged) return FuelDayStatus.notLogged;
    if (targetKcal <= 0) return FuelDayStatus.onTarget;
    final ratio = day.totals.calories / targetKcal;
    if (ratio < 1 - onTargetBand) return FuelDayStatus.under;
    if (ratio > 1 + onTargetBand) return FuelDayStatus.over;
    return FuelDayStatus.onTarget;
  }
}
