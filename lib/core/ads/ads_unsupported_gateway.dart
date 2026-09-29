import 'package:flutter/widgets.dart';

import 'ads_gateway.dart';

/// מימוש ריק לשולחן העבודה ולכל פלטפורמה בלי פרסומות. הממשק נשאר זהה,
/// ומסכי המשחק פשוט לא מציגים כפתורי פרסומת.
class AdsUnsupportedGateway extends AdsGateway {
  @override
  bool get isSupported => false;

  @override
  bool get isInitialized => true;

  @override
  bool get canRequestAds => false;

  @override
  bool get isRewardedReady => false;

  @override
  int get adHintsRemaining => 0;

  @override
  int get storeRewardsRemaining => 0;

  @override
  bool get dailyBonusAdAvailable => false;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> ensureInitialized() async {}

  @override
  Future<bool> showRewarded() async => false;

  @override
  Future<bool> showInterstitialIfAllowed({required int levelNumber}) async =>
      false;

  @override
  Future<void> recordCampaignLevelFinished(int levelNumber) async {}

  @override
  Future<void> recordAdHintGranted() async {}

  @override
  Future<void> recordStoreRewardGranted() async {}

  @override
  Future<void> recordDailyBonusAdGranted() async {}

  @override
  Future<void> showPrivacyOptions() async {}

  @override
  Widget buildNativePlacement() => const SizedBox.shrink();
}

AdsGateway createAdsGateway() => AdsUnsupportedGateway();
