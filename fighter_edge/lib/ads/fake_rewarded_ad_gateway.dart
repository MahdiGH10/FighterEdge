import 'rewarded_ad_gateway.dart';

/// A rewarded-ad gateway for tests: plays nothing and returns [nextResult].
class FakeRewardedAdGateway implements RewardedAdGateway {
  FakeRewardedAdGateway({
    this.nextResult = RewardedVideoResult.earned,
    this.privacyOptionsRequired = false,
  });

  RewardedVideoResult nextResult;

  @override
  bool privacyOptionsRequired;

  int shows = 0;
  int privacyOptionsShown = 0;
  String? lastToken;
  String? lastCustomData;

  @override
  bool get isAvailable => true;

  @override
  Future<RewardedVideoResult> show({
    required String ssvToken,
    required String customData,
  }) async {
    shows++;
    lastToken = ssvToken;
    lastCustomData = customData;
    return nextResult;
  }

  @override
  Future<void> showPrivacyOptions() async => privacyOptionsShown++;
}
