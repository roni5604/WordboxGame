import 'package:flutter/widgets.dart';
import 'package:wordbox_hebrew/core/ads/ads_gateway.dart';

/// שער פרסומות לבדיקות - בלי SDK ובלי Hive.
class FakeAdsGateway extends AdsGateway {
  FakeAdsGateway({
    this.supported = true,
    this.initialized = true,
    this.requestAds = true,
    this.rewardedReady = true,
    this.rewardGranted = true,
    this.hintsRemaining = 3,
    this.storeRemaining = 2,
    this.dailyBonusAvailable = true,
    this.native = const SizedBox(key: Key('native-ad'), height: 48),
  });

  bool supported;
  bool initialized;
  bool requestAds;
  bool rewardedReady;
  bool rewardGranted;
  int hintsRemaining;
  int storeRemaining;
  bool dailyBonusAvailable;
  final Widget native;

  int showRewardedCount = 0;
  final List<int> interstitialLevels = [];
  final List<int> recordedLevels = [];

  @override
  bool get isSupported => supported;

  @override
  bool get isInitialized => initialized;

  @override
  bool get canRequestAds => requestAds;

  @override
  bool get isRewardedReady => rewardedReady;

  @override
  int get adHintsRemaining => hintsRemaining;

  @override
  int get storeRewardsRemaining => storeRemaining;

  @override
  bool get dailyBonusAdAvailable => dailyBonusAvailable;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<bool> showRewarded() async {
    showRewardedCount++;
    return rewardGranted && rewardedReady;
  }

  @override
  Future<bool> showInterstitialIfAllowed({required int levelNumber}) async {
    interstitialLevels.add(levelNumber);
    return false;
  }

  @override
  Future<void> recordCampaignLevelFinished(int levelNumber) async {
    recordedLevels.add(levelNumber);
  }

  @override
  Future<void> recordAdHintGranted() async {
    if (hintsRemaining > 0) hintsRemaining -= 1;
    notifyListeners();
  }

  @override
  Future<void> recordStoreRewardGranted() async {
    if (storeRemaining > 0) storeRemaining -= 1;
    notifyListeners();
  }

  @override
  Future<void> recordDailyBonusAdGranted() async {
    dailyBonusAvailable = false;
    notifyListeners();
  }

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget buildNativePlacement() => native;
}
