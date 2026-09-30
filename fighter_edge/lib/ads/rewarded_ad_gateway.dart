/// How a rewarded video ended.
enum RewardedVideoResult {
  /// Watched to the end: Google will confirm it to our server.
  earned,

  /// Closed before the end. Nothing is earned.
  closedEarly,

  /// No video could be shown (no fill, offline, no ad consent, not set up).
  unavailable,
}

/// The one seam to the ad SDK. Only rewarded videos exist in this app: the
/// athlete chooses to watch one, and never sees an ad they did not ask for.
abstract class RewardedAdGateway {
  /// False when this build has no ad unit (tests, web, a release without
  /// one configured). The offer is then never shown.
  bool get isAvailable;

  /// Asks for ad consent when the law needs it, then plays one video.
  /// [ssvToken] is our server's one-time token (never the account ID); it
  /// travels with Google's signed confirmation back to our server.
  Future<RewardedVideoResult> show({
    required String ssvToken,
    required String customData,
  });

  /// Whether the athlete must be offered a way to change their ad consent
  /// (EEA/UK). Known once a video has been asked for this session.
  bool get privacyOptionsRequired;

  Future<void> showPrivacyOptions();
}

/// Ads switched off: tests, web, and builds without an ad unit.
class UnavailableRewardedAdGateway implements RewardedAdGateway {
  const UnavailableRewardedAdGateway();

  @override
  bool get isAvailable => false;

  @override
  Future<RewardedVideoResult> show({
    required String ssvToken,
    required String customData,
  }) async =>
      RewardedVideoResult.unavailable;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> showPrivacyOptions() async {}
}
