import '../controllers/auth_controller.dart';
import '../features/edge_fuel/domain/calculators/training_plan_fuel_bridge.dart';
import '../features/edge_fuel/domain/models/fuel_day_plan.dart';
import '../features/edge_fuel/presentation/controllers/edge_fuel_controller.dart';
import '../features/fight_camp/domain/calendar.dart';
import '../features/fight_camp/presentation/fight_camp_controller.dart';
import '../features/training_plan/presentation/plan_controller.dart';
import 'notification_scheduler.dart';

/// Gathers what the planner needs from the app's controllers, fresh on every
/// call.
///
/// * Sessions come from the same dated plan the Train tab shows.
/// * Fuel day types come from the training plan through
///   [TrainingPlanFuelBridge], so the fuel window follows the week on screen
///   with no second copy of it. Only the day type is used: no carb tier, no
///   energy number and no weight ever reaches a notification. Days inside a
///   booked fight's week get their fight-week type, which has no fuel window.
/// * The fight date is the booked fight's date, for the 7 and 1 day notes.
/// * The trial end is the server-fed access state's, for the one billing
///   notice. A passing "unknown" state keeps the last value rather than drop
///   the notice.
/// * Age comes from the confirmed Fuel setup and is used only to hide the
///   nutrition channels from athletes under 18 or of unknown age.
class NotificationInputsReader {
  NotificationInputsReader({
    required PlanController plan,
    required FightCampController fightCamp,
    required EdgeFuelController edgeFuel,
    required AuthController auth,
  })  : _plan = plan,
        _fightCamp = fightCamp,
        _edgeFuel = edgeFuel,
        _auth = auth;

  final PlanController _plan;
  final FightCampController _fightCamp;
  final EdgeFuelController _edgeFuel;
  final AuthController _auth;

  /// The last trial end seen while the access state was known.
  DateTime? _lastTrialEnd;

  NotificationInputs read() => NotificationInputs(
        sessions: _plan.rows,
        fuelDayTypes: _fuelDayTypes(),
        fightDate: _fightCamp.camp?.fightDate,
        trialEndsAt: _trialEnd(),
        ageYears: ageYears,
      );

  /// The athlete's age, only from a confirmed Fuel setup.
  int? get ageYears => ageOf(_edgeFuel);

  /// The age in a confirmed Fuel setup, or null.
  static int? ageOf(EdgeFuelController edgeFuel) =>
      edgeFuel.hasCompletedSetup ? edgeFuel.draft?.ageYears : null;

  /// Whether the nutrition channels apply to this athlete: an adult with a
  /// confirmed Fuel setup. Settings shows the fuel window only when this is
  /// true, so there is never a switch that cannot do anything.
  static bool nutritionAllowed(EdgeFuelController edgeFuel) {
    final age = ageOf(edgeFuel);
    return age != null && age >= 18;
  }

  Map<DateTime, FuelDayType> _fuelDayTypes() {
    if (!_plan.hasPlan) return const {};
    final thisWeek = _plan.thisWeekStart;
    final fight = _plan.inputs?.fight;
    final out = <DateTime, FuelDayType>{};
    // The planner looks seven days ahead, which can cross into next week.
    for (final start in [thisWeek, addDays(thisWeek, 7)]) {
      final week = _plan.weekContaining(start);
      if (week == null) continue;
      for (final day in TrainingPlanFuelBridge.planWeek(week, fight: fight)) {
        out[calendarDay(day.date)] = day.type;
      }
    }
    return out;
  }

  DateTime? _trialEnd() {
    final access = _auth.accessState;
    final state = access.effective;
    if (state == null) {
      // Nothing known yet (or a blip before the first answer): keep what the
      // last answer said instead of cancelling the notice.
      return access.isUnknown ? _lastTrialEnd : null;
    }
    _lastTrialEnd = state.isTrial ? state.trialEndsAt : null;
    return _lastTrialEnd;
  }
}
