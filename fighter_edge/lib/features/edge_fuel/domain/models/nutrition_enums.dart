/// Pure-Dart enums for the EdgeFuel nutrition domain. No Flutter imports —
/// this whole `domain/` subtree must stay usable outside the widget tree.
library;

/// The user's stated nutrition goal (master prompt §6, step 1).
enum NutritionGoal { loseFat, maintain, gainMuscle }

/// Which published Mifflin–St Jeor offset the estimate uses. Framed as an
/// equation choice, not a social-gender question (master prompt §6,
/// "Inclusive equation UX").
enum EquationProfile {
  /// `base + 5` offset.
  higherOffset,

  /// `base - 161` offset.
  lowerOffset,

  /// Midpoint of both offsets, used for "prefer not to answer" — confidence
  /// is marked lower and the maintenance range widened.
  neutral,
}

/// Daily-movement assumption, kept distinct from *planned* training so the
/// two are never double-counted (master prompt §7.3, §8).
enum ActivityLevel { veryLow, light, moderate, high, veryHigh }

/// Requested pace for a fat-loss or muscle-gain goal. Maintenance has no
/// pace — the adjustment is always 0%.
enum GoalPace {
  /// Fat loss only: ~0.25% body weight/week.
  gentle,

  /// Fat loss only: ~0.5% body weight/week (default for loseFat).
  standard,

  /// Fat loss only: ~0.75% body weight/week — the automated upper limit.
  upperLimit,

  /// Muscle gain only: ~0.10–0.25% body weight/week.
  conservative,

  /// Muscle gain only: up to ~0.25–0.50% body weight/week (default for
  /// novice/intermediate lifters).
  gainStandard,
}

/// How much the calculator trusts the resulting estimate. Lower confidence
/// is paired with a wider maintenance range, not false precision.
enum ConfidenceLabel { high, medium, low }

/// The outcome of a target calculation. Never collapse a safety problem
/// into a generic exception — this is the typed alternative (master prompt
/// §7.6).
enum NutritionTargetStatus {
  /// A full target was calculated and is safe to show.
  success,

  /// Required inputs are missing; no target was calculated.
  needsMoreData,

  /// The automated flow does not support this profile at all (e.g. under
  /// 18, or an invalid loss/gain target) — not offered, no partial result.
  unsupported,

  /// Clinical safety flags are present. The user should consult a
  /// qualified professional before an automated plan is generated.
  needsProfessionalReview,
}

/// Shared `enum.name` <-> string helpers so every model's toJson/fromJson
/// uses the same convention instead of repeating `Values.firstWhere(...)`.
T? enumFromName<T extends Enum>(List<T> values, Object? name) {
  if (name is! String) return null;
  for (final v in values) {
    if (v.name == name) return v;
  }
  return null;
}
