import 'fuel_day_plan.dart';

enum AcceptedFuelWeekStatus {
  ready,
  adultRequired,
  awaitingSignOff,
  needsMoreData,
  fightWeek,
  incompatibleTarget,
}

/// A display-only allocation of an accepted target. Never persisted in place
/// of that target. Blocked results contain no numeric day targets.
class AcceptedFuelWeek {
  AcceptedFuelWeek({
    required this.status,
    List<AcceptedFuelDay> days = const [],
    this.shiftApplied = false,
  }) : days = List.unmodifiable(days);

  final AcceptedFuelWeekStatus status;
  final List<AcceptedFuelDay> days;
  final bool shiftApplied;

  bool get isReady => status == AcceptedFuelWeekStatus.ready;
}

class AcceptedFuelDay {
  const AcceptedFuelDay({
    required this.plan,
    required this.calories,
    required this.proteinGrams,
    required this.carbGrams,
    required this.fatGrams,
  });

  final FuelDayPlan plan;
  final int calories;
  final int proteinGrams;
  final int carbGrams;
  final int fatGrams;

  int get macroDerivedCalories =>
      proteinGrams * 4 + carbGrams * 4 + fatGrams * 9;
}
