/// The kinds of notification the app can plan. Each one is switched on
/// separately by the user (all are off by default).
enum NotificationChannel {
  /// "Your session is coming up." Fires before the usual training time.
  sessionReminder,

  /// Information-only heads-up that a fuel window is open before a hard day.
  fuelWindow,

  /// The Sunday weekly review.
  weeklyReview,

  /// Fight countdown at 7 days and 1 day. Never carries cut, weigh-in or
  /// hydration content.
  fightCountdown,

  /// A plain "time to weigh in" reminder on the weekdays the caller passes.
  weighIn,

  /// One evening nudge on training days. Numberless.
  proteinGap,

  /// A short tip from a small bundled list.
  fighterTip,

  /// "Your free trial ends soon." A billing notice, see [isTransactional].
  trialEnding;

  /// Channels that exist because of nutrition data. Hidden by `pauseNutrition`
  /// and for athletes under 18 or of unknown age.
  bool get isNutrition => switch (this) {
        NotificationChannel.fuelWindow ||
        NotificationChannel.weighIn ||
        NotificationChannel.proteinGap =>
          true,
        _ => false,
      };

  /// A transactional notice is not counted against the one-a-day cap and is
  /// not silenced by `pauseAll`.
  bool get isTransactional => this == NotificationChannel.trialEnding;

  /// Lower number wins when several channels want the same day:
  /// fight countdown, then session (with its fuel window), then weekly
  /// review, weigh-in, protein, tip. Transactional is outside the ranking.
  int get priority => switch (this) {
        NotificationChannel.trialEnding => -1,
        NotificationChannel.fightCountdown => 0,
        NotificationChannel.sessionReminder ||
        NotificationChannel.fuelWindow =>
          1,
        NotificationChannel.weeklyReview => 2,
        NotificationChannel.weighIn => 3,
        NotificationChannel.proteinGap => 4,
        NotificationChannel.fighterTip => 5,
      };
}
