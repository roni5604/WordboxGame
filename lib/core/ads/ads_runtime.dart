import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'ads_gateway.dart';
import 'ads_unsupported_gateway.dart'
    if (dart.library.html) 'ads_web_gateway.dart'
    if (dart.library.io) 'ads_mobile_gateway.dart';

/// נקודת הכניסה לפרסומות. ב-Web נטען Ad Placement API, ב-VM (iOS,
/// Android, וגם בדיקות על macOS) נטען AdMob, והמימוש עצמו נדלק רק
/// על iOS/Android. בשולחן העבודה אין פרסומות.
class AdsRuntime {
  AdsRuntime._();

  static final AdsGateway instance = createAdsGateway();

  static Future<void> ensureInitialized() => instance.ensureInitialized();
}

/// עוטף את הסינגלטון כדי ש-Riverpod יוכל להאזין לו בלי ל-dispose אותו
/// כש-ProviderScope של בדיקה נסגר.
class _AdsGatewayBinding extends AdsGateway {
  _AdsGatewayBinding(this._inner) {
    _onInner = notifyListeners;
    _inner.addListener(_onInner);
  }

  final AdsGateway _inner;
  late final VoidCallback _onInner;

  @override
  void dispose() {
    _inner.removeListener(_onInner);
    super.dispose();
  }

  @override
  bool get isSupported => _inner.isSupported;

  @override
  bool get isInitialized => _inner.isInitialized;

  @override
  bool get canRequestAds => _inner.canRequestAds;

  @override
  bool get isRewardedReady => _inner.isRewardedReady;

  @override
  int get adHintsRemaining => _inner.adHintsRemaining;

  @override
  int get storeRewardsRemaining => _inner.storeRewardsRemaining;

  @override
  bool get dailyBonusAdAvailable => _inner.dailyBonusAdAvailable;

  @override
  bool get privacyOptionsRequired => _inner.privacyOptionsRequired;

  @override
  Future<void> ensureInitialized() => _inner.ensureInitialized();

  @override
  Future<bool> showRewarded() => _inner.showRewarded();

  @override
  Future<bool> showInterstitialIfAllowed({required int levelNumber}) =>
      _inner.showInterstitialIfAllowed(levelNumber: levelNumber);

  @override
  Future<void> recordCampaignLevelFinished(int levelNumber) =>
      _inner.recordCampaignLevelFinished(levelNumber);

  @override
  Future<void> recordAdHintGranted() => _inner.recordAdHintGranted();

  @override
  Future<void> recordStoreRewardGranted() => _inner.recordStoreRewardGranted();

  @override
  Future<void> recordDailyBonusAdGranted() =>
      _inner.recordDailyBonusAdGranted();

  @override
  Future<void> showPrivacyOptions() => _inner.showPrivacyOptions();

  @override
  Widget buildNativePlacement() => _inner.buildNativePlacement();
}

final adsGatewayProvider = ChangeNotifierProvider<AdsGateway>((ref) {
  return _AdsGatewayBinding(AdsRuntime.instance);
});
