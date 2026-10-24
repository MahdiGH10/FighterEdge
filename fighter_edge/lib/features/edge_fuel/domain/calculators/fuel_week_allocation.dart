/// Integer allocation shared by policy v2 and accepted-target day views.
/// It redistributes a weekly budget; it never increases that budget.
class FuelWeekAllocation {
  const FuelWeekAllocation._();

  static const int daysPerWeek = 7;

  /// Rounds seven zero-sum deviations, then places the rounding residue in
  /// error order. Returns null if the budget or floors cannot be respected.
  /// [quantum] is ten for kcal and one for carbohydrate grams.
  static List<int>? split({
    required int average,
    required List<double> deviations,
    required double shift,
    required List<int> minimums,
    int quantum = 10,
  }) {
    if (average < 0 ||
        deviations.length != daysPerWeek ||
        minimums.length != daysPerWeek ||
        minimums.any((v) => v < 0) ||
        !shift.isFinite ||
        shift < 0 ||
        shift > 1 ||
        quantum <= 0 ||
        deviations.any((v) => !v.isFinite)) {
      return null;
    }
    final raw = [for (final d in deviations) average + shift * d];
    if (raw.any((v) => !v.isFinite)) return null;
    final rounded = [for (final r in raw) (r / quantum).round() * quantum];
    for (var i = 0; i < daysPerWeek; i++) {
      if (rounded[i] < minimums[i]) return null;
    }
    var residue = average * daysPerWeek - rounded.fold<int>(0, (a, b) => a + b);
    if (residue % quantum != 0) return null;
    if (residue == 0) return List.unmodifiable(rounded);
    final order = List<int>.generate(daysPerWeek, (i) => i)
      ..sort((a, b) {
        final error = (raw[b] - rounded[b]).compareTo(raw[a] - rounded[a]);
        final byError = residue > 0 ? error : -error;
        return byError != 0 ? byError : a.compareTo(b);
      });
    final step = residue > 0 ? quantum : -quantum;
    // Zero-sum inputs need at most seven rounding corrections. Bound work
    // even for malformed callers whose deviations do not sum to zero.
    var guard = 0;
    while (residue != 0 && guard++ < daysPerWeek * 10) {
      var placed = false;
      for (final i in order) {
        if (residue == 0) break;
        if (rounded[i] + step < minimums[i]) continue;
        rounded[i] += step;
        residue -= step;
        placed = true;
      }
      if (!placed) return null;
    }
    return residue == 0 ? List.unmodifiable(rounded) : null;
  }
}
