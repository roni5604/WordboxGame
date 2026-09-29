import 'dart:async';
import 'dart:io' show Platform;

import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ads_config.dart';
import 'ads_gateway.dart';
import 'ads_native_placement.dart';
import 'ads_policy.dart';
import 'ads_quota_store.dart';

/// AdMob ל-iOS ולאנדרואיד: הסכמה (UMP), ATT ב-iOS, טעינה מראש של
/// Rewarded ו-Interstitial, ומתנות לפי [AdsPolicy].
class AdsMobileGateway extends AdsGateway {
  AdsMobileGateway({AdsQuotaStore? quota}) : _quota = quota ?? AdsQuotaStore();

  final AdsQuotaStore _quota;

  Future<void>? _initFuture;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _showing = false;
  bool _rewardedLoading = false;
  bool _interstitialLoading = false;

  RewardedAd? _rewarded;
  InterstitialAd? _interstitial;

  bool get _isIos => Platform.isIOS;

  bool get _mobilePlatform => Platform.isAndroid || Platform.isIOS;

  @override
  bool get isSupported {
    if (!_mobilePlatform) return false;
    if (kReleaseMode && !AdsConfig.hasProductionIds(isIos: _isIos)) {
      return false;
    }
    return true;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get isRewardedReady => _rewarded != null && !_showing;

  @override
  int get adHintsRemaining => _quota.adHintsRemaining;

  @override
  int get storeRewardsRemaining => _quota.storeRewardsRemaining;

  @override
  bool get dailyBonusAdAvailable => _quota.dailyBonusAdAvailable;

  @override
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  @override
  Future<void> ensureInitialized() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!isSupported) {
      if (kReleaseMode &&
          _mobilePlatform &&
          !AdsConfig.hasProductionIds(isIos: _isIos)) {
        debugPrint(
          'Ads disabled: missing production AdMob unit IDs (dart-define).',
        );
      }
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      await _quota.load();
      await _requestConsent();
      if (Platform.isIOS) await _requestAtt();
      _canRequestAds = await ConsentInformation.instance.canRequestAds();
      final privacy = await ConsentInformation.instance
          .getPrivacyOptionsRequirementStatus();
      _privacyOptionsRequired =
          privacy == PrivacyOptionsRequirementStatus.required;
      if (_canRequestAds) {
        await MobileAds.instance.updateRequestConfiguration(
          RequestConfiguration(
            maxAdContentRating: MaxAdContentRating.t,
            tagForChildDirectedTreatment: TagForChildDirectedTreatment.no,
            tagForUnderAgeOfConsent: TagForUnderAgeOfConsent.no,
          ),
        );
        await MobileAds.instance.initialize();
        await _loadRewarded();
        await _loadInterstitial();
      }
    } catch (e, st) {
      debugPrint('Ads init failed: $e\n$st');
      _canRequestAds = false;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  Future<void> _requestConsent() async {
    final updated = Completer<void>();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        if (!updated.isCompleted) updated.complete();
      },
      (error) {
        debugPrint('Consent info update failed: ${error.message}');
        if (!updated.isCompleted) updated.complete();
      },
    );
    await updated.future.timeout(const Duration(seconds: 8), onTimeout: () {});
    try {
      await ConsentForm.loadAndShowConsentFormIfRequired((_) {});
    } catch (e) {
      debugPrint('Consent form skipped: $e');
    }
  }

  Future<void> _requestAtt() async {
    try {
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;
      if (status == TrackingStatus.notDetermined) {
        // iOS מציג את הדיאלוג רק כשהאפליקציה כבר בקדמת המסך.
        await Future<void>.delayed(const Duration(milliseconds: 250));
        await AppTrackingTransparency.requestTrackingAuthorization();
      }
    } catch (e) {
      debugPrint('ATT skipped: $e');
    }
  }

  Future<void> _loadRewarded() async {
    if (!canRequestAds || _rewarded != null || _rewardedLoading) return;
    _rewardedLoading = true;
    try {
      await RewardedAd.load(
        adUnitId: AdsConfig.rewardedUnitId(isIos: _isIos),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _rewarded = ad;
            _rewardedLoading = false;
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            debugPrint('Rewarded failed to load: ${error.message}');
            _rewarded = null;
            _rewardedLoading = false;
            notifyListeners();
            _retryLater(_loadRewarded);
          },
        ),
      );
    } catch (e) {
      debugPrint('Rewarded load threw: $e');
      _rewardedLoading = false;
    }
  }

  Future<void> _loadInterstitial() async {
    if (!canRequestAds || _interstitial != null || _interstitialLoading) return;
    _interstitialLoading = true;
    try {
      await InterstitialAd.load(
        adUnitId: AdsConfig.interstitialUnitId(isIos: _isIos),
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _interstitialLoading = false;
            notifyListeners();
          },
          onAdFailedToLoad: (error) {
            debugPrint('Interstitial failed to load: ${error.message}');
            _interstitial = null;
            _interstitialLoading = false;
            notifyListeners();
            _retryLater(_loadInterstitial);
          },
        ),
      );
    } catch (e) {
      debugPrint('Interstitial load threw: $e');
      _interstitialLoading = false;
    }
  }

  void _retryLater(Future<void> Function() load) {
    Future<void>.delayed(const Duration(seconds: 25), () {
      if (!_initialized) return;
      load();
    });
  }

  @override
  Future<bool> showRewarded() async {
    if (!isSupported || !canRequestAds || _showing) return false;
    final ad = _rewarded;
    if (ad == null) {
      await _loadRewarded();
      return false;
    }

    _showing = true;
    _rewarded = null;
    notifyListeners();

    final earned = Completer<bool>();
    var gotReward = false;
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _showing = false;
        await _quota.markFullScreenShown(DateTime.now());
        notifyListeners();
        await _loadRewarded();
        if (!earned.isCompleted) earned.complete(gotReward);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Rewarded failed to show: ${error.message}');
        ad.dispose();
        _showing = false;
        notifyListeners();
        _loadRewarded();
        if (!earned.isCompleted) earned.complete(false);
      },
    );

    try {
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          gotReward = true;
        },
      );
    } catch (e) {
      debugPrint('Rewarded show threw: $e');
      _showing = false;
      if (!earned.isCompleted) earned.complete(false);
    }
    return earned.future;
  }

  @override
  Future<bool> showInterstitialIfAllowed({required int levelNumber}) async {
    if (!isSupported || _showing) return false;
    await _quota.load();
    final ad = _interstitial;
    final allowed = AdsPolicy.shouldShowInterstitial(
      levelNumber: levelNumber,
      levelsSinceLastInterstitial: _quota.levelsSinceInterstitial,
      lastFullScreenAt: _quota.lastFullScreenAt,
      now: DateTime.now(),
      canRequestAds: _canRequestAds,
      adLoaded: ad != null,
    );
    if (!allowed || ad == null) return false;

    _showing = true;
    _interstitial = null;
    notifyListeners();

    final shown = Completer<bool>();
    ad.fullScreenContentCallback = FullScreenContentCallback<InterstitialAd>(
      onAdDismissedFullScreenContent: (ad) async {
        ad.dispose();
        _showing = false;
        await _quota.markFullScreenShown(DateTime.now());
        await _quota.resetInterstitialCounter();
        notifyListeners();
        await _loadInterstitial();
        if (!shown.isCompleted) shown.complete(true);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('Interstitial failed to show: ${error.message}');
        ad.dispose();
        _showing = false;
        notifyListeners();
        _loadInterstitial();
        if (!shown.isCompleted) shown.complete(false);
      },
    );

    try {
      await ad.show();
    } catch (e) {
      debugPrint('Interstitial show threw: $e');
      _showing = false;
      if (!shown.isCompleted) shown.complete(false);
    }
    return shown.future;
  }

  @override
  Future<void> recordCampaignLevelFinished(int levelNumber) async {
    if (!isSupported) return;
    await _quota.load();
    await _quota.recordCampaignLevelFinished(levelNumber);
  }

  @override
  Future<void> recordAdHintGranted() async {
    await _quota.load();
    await _quota.recordAdHint();
    notifyListeners();
  }

  @override
  Future<void> recordStoreRewardGranted() async {
    await _quota.load();
    await _quota.recordStoreReward();
    notifyListeners();
  }

  @override
  Future<void> recordDailyBonusAdGranted() async {
    await _quota.load();
    await _quota.recordDailyBonusAd();
    notifyListeners();
  }

  @override
  Future<void> showPrivacyOptions() async {
    if (!_privacyOptionsRequired) return;
    try {
      await ConsentForm.showPrivacyOptionsForm((error) {
        if (error != null) debugPrint('Privacy options: ${error.message}');
      });
    } catch (e) {
      debugPrint('Privacy options skipped: $e');
    }
  }

  @override
  Widget buildNativePlacement() => const NativeAdPlacement();
}

AdsGateway createAdsGateway() => AdsMobileGateway();
