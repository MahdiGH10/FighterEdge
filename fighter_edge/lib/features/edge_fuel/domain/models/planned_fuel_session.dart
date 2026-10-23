/// Pure input types for training-aware nutrition (policy v2).
///
/// The caller maps its planned week onto these simple types, so Fuel and
/// Train share one source of truth. `TrainingPlanFuelBridge` is the one place
/// in the Fuel domain that reads the training-plan domain.
library;

/// What a planned session trains, for the purpose of energy cost only.
enum FuelDiscipline {
  boxing,
  kickboxing,
  muayThai,
  wrestling,
  bjj,
  mma,
  strength,
  conditioning,

  /// Recovery work, a class the app prescribes nothing for, or anything the
  /// caller cannot map. Costed conservatively.
  other,
}

/// How hard a planned session is.
enum FuelIntensity { light, moderate, hard }

/// One planned session in the week Fuel is sizing a target for.
class PlannedFuelSession {
  const PlannedFuelSession({
    required this.dayIndex,
    required this.discipline,
    required this.intensity,
    required this.durationMinutes,
  });

  /// Days since the first day of the planned week, 0 to 6. The order of the
  /// days is all that matters; the domain never reads a calendar.
  final int dayIndex;
  final FuelDiscipline discipline;
  final FuelIntensity intensity;
  final int durationMinutes;

  bool get hasValidDay => dayIndex >= 0 && dayIndex < 7;
}

/// How a day is fuelled relative to the rest of the week.
enum FuelDayKind {
  /// No planned session.
  rest,

  /// Planned training, none of it hard.
  light,

  /// A hard session, or a day of heavy total session energy.
  hard,
}
