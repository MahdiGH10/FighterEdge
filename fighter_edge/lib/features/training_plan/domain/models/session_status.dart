/// Where a planned session stands today. Resolved by
/// `SessionStatusResolver`; never stored.
enum SessionStatus {
  /// Date is before the plan start.
  beforeStart,

  /// In the future, not logged.
  planned,

  /// Today, not logged.
  today,

  /// Logged.
  completed,

  /// Past, not logged, not skipped or moved.
  missed,

  /// The athlete skipped it. Neutral, not a failure.
  skipped,

  /// The athlete moved it to another date. This is the original date's row.
  moved,

  /// Rest or recovery day: calm, never at risk.
  rest,
}
