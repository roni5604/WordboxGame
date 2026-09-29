import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

import 'ads_config.dart';
import 'ads_gateway.dart';
import 'ads_policy.dart';
import 'ads_quota_store.dart';

/// מזהה לדוגמה של Google. משמש רק בזמן פיתוח, בלי חשבון AdSense.
const _testAdSenseClient = 'ca-pub-1234567890123456';

const _adScriptBase =
    'https://pagead2.googlesyndication.com/pagead/js/adsbygoogle.js';

/// פרסומות לאתר דרך Ad Placement API של Google (משחקי HTML5).
/// AdMob לא רץ ב-Flutter Web. מתנות ומסך מלא משתמשים באותם כללים
/// כמו באפליקציה. כרטיס Native נשאר רק ב-AdMob.
class AdsWebGateway extends AdsGateway {
  AdsWebGateway({AdsQuotaStore? quota}) : _quota = quota ?? AdsQuotaStore();

  final AdsQuotaStore _quota;

  Future<void>? _initFuture;
  bool _initialized = false;
  bool _canRequestAds = false;
  bool _showing = false;

  bool get _useTestAds => !kReleaseMode;

  @override
  bool get isSupported {
    if (kReleaseMode && AdsConfig.adsenseClient.isEmpty) return false;
    return true;
  }

  @override
  bool get isInitialized => _initialized;

  @override
  bool get canRequestAds => _canRequestAds;

  @override
  bool get isRewardedReady => _canRequestAds && !_showing;

  @override
  int get adHintsRemaining => _quota.adHintsRemaining;

  @override
  int get storeRewardsRemaining => _quota.storeRewardsRemaining;

  @override
  bool get dailyBonusAdAvailable => _quota.dailyBonusAdAvailable;

  @override
  bool get privacyOptionsRequired => false;

  @override
  Future<void> ensureInitialized() {
    return _initFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!isSupported) {
      if (kReleaseMode && AdsConfig.adsenseClient.isEmpty) {
        debugPrint('Web ads disabled: missing ADSENSE_CLIENT.');
      }
      _initialized = true;
      notifyListeners();
      return;
    }

    try {
      await _quota.load();
      _installAdScript();
      final ready = Completer<void>();
      _callBridge('configure', () {
        if (!ready.isCompleted) ready.complete();
      }.toJS);
      final deadline = DateTime.now().add(const Duration(seconds: 8));
      while (!ready.isCompleted && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
      // onReady מגיע אחרי שהספרייה מוכנה. אם היא כבר נטענה עם מזהה מפרסם,
      // אפשר ללחוץ גם לפני כן: הבקשה ממתינה בתור ונפתחת כשהמודעה מוכנה.
      _canRequestAds = ready.isCompleted || _adsScriptLoaded();
      debugPrint(
        'Web ads ready=${ready.isCompleted} loaded=${_adsScriptLoaded()} '
        'canRequest=$_canRequestAds',
      );
    } catch (e, st) {
      debugPrint('Web ads init failed: $e\n$st');
      _canRequestAds = false;
    } finally {
      _initialized = true;
      notifyListeners();
    }
  }

  bool _adsScriptLoaded() {
    final ads = globalContext.getProperty<JSObject?>('adsbygoogle'.toJS);
    if (ads == null) return false;
    final loaded = ads.getProperty<JSBoolean?>('loaded'.toJS);
    return loaded?.toDart ?? false;
  }

  void _installAdScript() {
    final loader = web.document.getElementById('wordbox-ad-loader');
    if (loader == null) {
      throw StateError('Web ads: missing #wordbox-ad-loader in index.html');
    }
    // בלי data-ad-client הספרייה מתעלמת מהתג, adBreak נשאר פונקציית דמה,
    // והכפתור נשאר על «טוען פרסומת...» כי adBreakDone לא נקרא אף פעם.
    final client = AdsConfig.adsenseClient.isNotEmpty
        ? AdsConfig.adsenseClient
        : _testAdSenseClient;
    loader.setAttribute('data-ad-client', client);
    if (_useTestAds) {
      loader.setAttribute('data-adbreak-test', 'on');
      loader.setAttribute('data-ad-frequency-hint', '30s');
    } else {
      loader.removeAttribute('data-adbreak-test');
      loader.setAttribute('data-ad-frequency-hint', '120s');
    }
    final desired = '$_adScriptBase?client=$client';
    final src = loader.getAttribute('src') ?? '';
    if (src == desired) return;
    if (src.isNotEmpty) {
      // התג כבר רץ בלי מזהה. טעינה שנייה לא מאתחלת אותו מחדש.
      final reloaded = web.window.sessionStorage.getItem('wordbox_ads_tag_reload');
      if (reloaded != '1') {
        web.window.sessionStorage.setItem('wordbox_ads_tag_reload', '1');
        web.window.location.reload();
      }
      return;
    }
    loader.setAttribute('async', 'true');
    loader.setAttribute('crossorigin', 'anonymous');
    loader.setAttribute('src', desired);
  }

  void _callBridge(String method, JSAny? first, [JSAny? second]) {
    final bridge = globalContext.getProperty<JSObject?>('wordboxAds'.toJS);
    if (bridge == null) {
      throw StateError('Web ads: missing wordboxAds bridge');
    }
    final fn = bridge.getProperty<JSFunction?>(method.toJS);
    if (fn == null) {
      throw StateError('Web ads: missing wordboxAds.$method');
    }
    if (second == null) {
      fn.callAsFunction(bridge, first);
    } else {
      fn.callAsFunction(bridge, first, second);
    }
  }

  bool get _rewardStarted {
    final bridge = globalContext.getProperty<JSObject?>('wordboxAds'.toJS);
    final started = bridge?.getProperty<JSBoolean?>('started'.toJS);
    return started?.toDart ?? false;
  }

  void _coverGame(bool hide) {
    final view = web.document.querySelector('flutter-view');
    if (view == null) return;
    final style = view.getProperty<JSObject?>('style'.toJS);
    style?.setProperty('visibility'.toJS, (hide ? 'hidden' : 'visible').toJS);
  }

  @override
  Future<bool> showRewarded() async {
    if (!isSupported || !canRequestAds || _showing) return false;
    _showing = true;
    notifyListeners();

    final earned = Completer<bool>();
    var gotReward = false;
    try {
      _callBridge('showReward', () {
        gotReward = true;
      }.toJS, (JSAny? info) {
        final place = _asObject(info);
        final viewed =
            place.getProperty<JSBoolean?>('viewed'.toJS)?.toDart ?? false;
        unawaited(
          _finish(place, earned, gotReward || viewed, resetCounter: false),
        );
      }.toJS);
    } catch (e) {
      debugPrint('Web rewarded threw: $e');
      _coverGame(false);
      _showing = false;
      notifyListeners();
      return false;
    }
    unawaited(_failIfAdNeverStarts(earned));
    return _wait(earned);
  }

  @override
  Future<bool> showInterstitialIfAllowed({required int levelNumber}) async {
    if (!isSupported || _showing) return false;
    await _quota.load();
    final allowed = AdsPolicy.shouldShowInterstitial(
      levelNumber: levelNumber,
      levelsSinceLastInterstitial: _quota.levelsSinceInterstitial,
      lastFullScreenAt: _quota.lastFullScreenAt,
      now: DateTime.now(),
      canRequestAds: _canRequestAds,
      adLoaded: _canRequestAds,
    );
    if (!allowed) return false;

    _showing = true;
    notifyListeners();
    final shown = Completer<bool>();
    try {
      _callBridge('showNext', (JSAny? info) {
        final place = _asObject(info);
        final status = _breakStatus(place);
        final didShow = status == 'viewed' || status == 'dismissed';
        unawaited(_finish(place, shown, didShow, resetCounter: didShow));
      }.toJS);
    } catch (e) {
      debugPrint('Web interstitial threw: $e');
      _coverGame(false);
      _showing = false;
      notifyListeners();
      return false;
    }
    unawaited(_failIfAdNeverStarts(shown));
    return _wait(shown);
  }

  /// אם Google לא פותח מודעה, לא משאירים את הכפתור על «טוען פרסומת...».
  Future<void> _failIfAdNeverStarts(Completer<bool> done) async {
    await Future<void>.delayed(const Duration(seconds: 12));
    if (done.isCompleted || _rewardStarted) return;
    debugPrint('Web ad did not start');
    _coverGame(false);
    _showing = false;
    notifyListeners();
    if (!done.isCompleted) done.complete(false);
  }

  Future<bool> _wait(Completer<bool> done) {
    return done.future.timeout(
      const Duration(seconds: 90),
      onTimeout: () {
        _coverGame(false);
        _showing = false;
        notifyListeners();
        return false;
      },
    );
  }

  Future<void> _finish(
    JSObject info,
    Completer<bool> done,
    bool success, {
    required bool resetCounter,
  }) async {
    final status = _breakStatus(info);
    debugPrint('Web ad break done: $status');
    _coverGame(false);
    _showing = false;
    if (success) {
      await _quota.markFullScreenShown(DateTime.now());
      if (resetCounter) await _quota.resetInterstitialCounter();
    }
    notifyListeners();
    if (!done.isCompleted) done.complete(success);
  }

  JSObject _asObject(JSAny? value) {
    if (value.isA<JSObject>()) return value as JSObject;
    return JSObject();
  }

  String _breakStatus(JSObject info) {
    try {
      final status = info.getProperty<JSString?>('breakStatus'.toJS);
      return status?.toDart ?? '';
    } catch (e) {
      debugPrint('Web ad status unreadable: $e');
      return '';
    }
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
  Future<void> showPrivacyOptions() async {}

  @override
  Widget buildNativePlacement() => const SizedBox.shrink();
}

AdsGateway createAdsGateway() => AdsWebGateway();
