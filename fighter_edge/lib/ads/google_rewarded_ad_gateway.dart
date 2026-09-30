import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'rewarded_ad_gateway.dart';

/// Rewarded videos through Google AdMob.
///
/// - Non-personalised ads only, rated PG. The app never passes health, food,
///   weight or account data to the ad SDK.
/// - Google's consent form (UMP) runs before the first video where the law
///   needs it (EEA/UK), not at app start.
/// - The ad unit comes from `--dart-define=ADMOB_REWARDED_UNIT_ID=...`.
///   Debug builds without one use Google's public test unit; a release
///   build without one shows no offer at all.
class GoogleRewardedAdGateway implements RewardedAdGateway {
  GoogleRewardedAdGateway({String? adUnitId})
      : _adUnitId = adUnitId ?? _configuredUnitId();

  final String? _adUnitId;
  bool _sdkStarted = false;
  bool _privacyOptionsRequired = false;

  static const _loadTimeout = Duration(seconds: 15);

  static String? _configuredUnitId() {
    const configured = String.fromEnvironment('ADMOB_REWARDED_UNIT_ID');
    if (configured.isNotEmpty) return configured;
    if (!kDebugMode || kIsWeb) return null;
    // Google's published sample units: they only ever serve test ads.
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'ca-app-pub-3940256099942544/5224354917',
      TargetPlatform.iOS => 'ca-app-pub-3940256099942544/1712485313',
      _ => null,
    };
  }

  @override
  bool get isAvailable =>
      !kIsWeb &&
      _adUnitId != null &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> showPrivacyOptions() async {
    final done = Completer<void>();
    await ConsentForm.showPrivacyOptionsForm((_) {
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  }

  @override
  Future<RewardedVideoResult> show({
    required String ssvToken,
    required String customData,
  }) async {
    final unitId = _adUnitId;
    if (!isAvailable || unitId == null) return RewardedVideoResult.unavailable;
    try {
      if (!await _gatherConsentAndStart()) {
        return RewardedVideoResult.unavailable;
      }
      final ad = await _load(unitId);
      if (ad == null) return RewardedVideoResult.unavailable;
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(userId: ssvToken, customData: customData),
      );

      final done = Completer<RewardedVideoResult>();
      var earned = false;
      ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          if (!done.isCompleted) {
            done.complete(earned
                ? RewardedVideoResult.earned
                : RewardedVideoResult.closedEarly);
          }
        },
        onAdFailedToShowFullScreenContent: (ad, _) {
          ad.dispose();
          if (!done.isCompleted) done.complete(RewardedVideoResult.unavailable);
        },
      );
      await ad.show(onUserEarnedReward: (_, __) => earned = true);
      return await done.future;
    } catch (_) {
      return RewardedVideoResult.unavailable;
    }
  }

  /// Updates the consent state, shows Google's form if it is required, and
  /// starts the SDK once ads may be requested.
  Future<bool> _gatherConsentAndStart() async {
    final info = ConsentInformation.instance;
    final updated = Completer<void>();
    info.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () => updated.complete(),
      (_) => updated.complete(),
    );
    await updated.future;
    await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    _privacyOptionsRequired = await info.getPrivacyOptionsRequirementStatus() ==
        PrivacyOptionsRequirementStatus.required;
    if (!await info.canRequestAds()) return false;

    if (!_sdkStarted) {
      await MobileAds.instance.initialize();
      await MobileAds.instance.updateRequestConfiguration(
        RequestConfiguration(maxAdContentRating: MaxAdContentRating.pg),
      );
      _sdkStarted = true;
    }
    return true;
  }

  Future<RewardedAd?> _load(String unitId) {
    final loaded = Completer<RewardedAd?>();
    RewardedAd.load(
      adUnitId: unitId,
      request: const AdRequest(nonPersonalizedAds: true),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (!loaded.isCompleted) loaded.complete(ad);
        },
        onAdFailedToLoad: (_) {
          if (!loaded.isCompleted) loaded.complete(null);
        },
      ),
    );
    return loaded.future.timeout(_loadTimeout, onTimeout: () => null);
  }
}
