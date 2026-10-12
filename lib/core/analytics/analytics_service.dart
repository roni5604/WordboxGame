import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

import '../../data/models/auth_user.dart';
import '../../data/services/firebase_bootstrap.dart';
import '../../game_engine/models/level_config.dart';
import 'analytics_web_loader_stub.dart'
    if (dart.library.js_interop) 'analytics_web_loader_web.dart'
    as web_loader;

/// Consent state reported by Google's UMP SDK (see ads_mobile_gateway.dart).
/// Kept independent of google_mobile_ads so this file compiles on every
/// platform (the ads SDK is only imported on iOS/Android).
enum AdsConsentState { notRequired, obtained, required, unknown }

/// The single entry point for all product analytics (Firebase Analytics /
/// GA4, exported to BigQuery). Every custom event of the spec in
/// docs/ANALYTICS_EVENTS.md is a typed method here, so event names and
/// parameters stay consistent across the codebase.
///
/// Safety guarantees:
/// * No-op when Firebase is disabled (`--dart-define=USE_FIREBASE=false`),
///   failed to initialize, or [init] was never called (unit/widget tests).
/// * Never throws: every SDK call is guarded and errors are only printed in
///   debug builds.
/// * In debug builds every event is printed (`[analytics] name {params}`).
/// * Never logs names, emails, free text or chat. The user id is the
///   Firebase uid only.
class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  /// App version sent with every custom event and as a user property.
  /// Keep in sync with `version:` in pubspec.yaml, or override in CI with
  /// `--dart-define=APP_VERSION=x.y.z+n`.
  static const String gameVersion = String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0+1');

  /// The app UI is Hebrew only (see app.dart).
  static const String appLanguage = 'he';

  /// Hive box for per-level attempt counters (same storage the app already
  /// uses for similar local counters, e.g. AdsQuotaStore).
  static const String attemptsBoxName = 'wordbox_analytics';

  static const int _maxParams = 25;
  static const int _maxStringParam = 100;
  static const int _maxUserPropertyValue = 36;

  FirebaseAnalytics? _fa;
  Future<bool>? _ready;
  bool _persistAttempts = false;
  Box? _attemptsBox;
  final Map<int, int> _memoryAttempts = {};
  final Map<String, String?> _userProperties = {};
  bool _userIdSet = false;
  String? _userId;

  /// true once Firebase Analytics is ready to receive events.
  bool get isEnabled => _fa != null;

  /// Call once after Firebase was bootstrapped (main.dart). Safe to call when
  /// Firebase is disabled - the service then stays a no-op. Events logged
  /// before initialization finishes are delivered once it is ready.
  Future<bool> init() {
    if (_ready != null) return _ready!;
    _persistAttempts = true;
    final ready = _ready = _initialize();
    _userProperties
      ..['game_version'] = gameVersion
      ..['app_language'] = appLanguage;
    // Replays identity captured before init (listeners may fire early).
    final properties = Map<String, String?>.of(_userProperties);
    unawaited(_guard('initial identity', (fa) async {
      for (final entry in properties.entries) {
        await fa.setUserProperty(name: entry.key, value: entry.value);
      }
      if (_userIdSet) await fa.setUserId(id: _userId);
    }));
    return ready;
  }

  Future<bool> _initialize() async {
    try {
      if (!isFirebaseBackendReady()) {
        debugPrint('[analytics] disabled: Firebase backend is not ready');
        return false;
      }
      // On the web the Analytics JS module is loaded by us (non-blocking, see
      // web/index.html) so an ad blocker can never stall Firebase.initializeApp.
      if (kIsWeb && !await web_loader.ensureWebAnalyticsLoaded()) {
        debugPrint('[analytics] disabled: web analytics script unavailable');
        return false;
      }
      _fa = FirebaseAnalytics.instance;
      return true;
    } catch (e) {
      debugPrint('[analytics] disabled: $e');
      _fa = null;
      return false;
    }
  }

  Future<FirebaseAnalytics?> _client() async {
    final ready = _ready;
    if (ready == null) return null;
    final ok = await ready;
    return ok ? _fa : null;
  }

  Future<void> _guard(String what, Future<void> Function(FirebaseAnalytics fa) action) async {
    try {
      final fa = await _client();
      if (fa == null) return;
      await action(fa);
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] $what failed: $e');
    }
  }

  /// Normalizes params to what GA4 accepts: String/num only (bool as 1/0),
  /// strings cut to 100 chars, nulls dropped, at most 25 params, and
  /// game_version added.
  @visibleForTesting
  static Map<String, Object> sanitizeParams(Map<String, Object?> params) {
    final out = <String, Object>{};
    for (final entry in params.entries) {
      if (out.length >= _maxParams - 1) break;
      final value = entry.value;
      if (value == null) continue;
      if (value is bool) {
        out[entry.key] = value ? 1 : 0;
      } else if (value is num) {
        out[entry.key] = value;
      } else {
        out[entry.key] = _truncate(value.toString(), _maxStringParam);
      }
    }
    out['game_version'] = gameVersion;
    return out;
  }

  static String _truncate(String value, int max) => value.length <= max ? value : value.substring(0, max);

  void _log(String name, [Map<String, Object?> params = const {}]) {
    try {
      final clean = sanitizeParams(params);
      if (kDebugMode) debugPrint('[analytics] $name $clean');
      unawaited(_guard(name, (fa) => fa.logEvent(name: name, parameters: clean)));
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] $name failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // User identity, user properties, consent
  // ---------------------------------------------------------------------------

  /// Sets a user property (deduplicated; values are cut to GA4's 36 chars).
  void setUserProperty(String name, String? value) {
    final v = value == null ? null : _truncate(value, _maxUserPropertyValue);
    if (_userProperties.containsKey(name) && _userProperties[name] == v) return;
    _userProperties[name] = v;
    if (kDebugMode) debugPrint('[analytics] user_property $name=$v');
    unawaited(_guard('setUserProperty($name)', (fa) => fa.setUserProperty(name: name, value: v)));
  }

  /// User id = Firebase uid only (never email/name). null clears it.
  void setUserId(String? uid) {
    if (_userIdSet && _userId == uid) return;
    _userIdSet = true;
    _userId = uid;
    if (kDebugMode) debugPrint('[analytics] user_id ${uid == null ? 'cleared' : 'set'}');
    unawaited(_guard('setUserId', (fa) => fa.setUserId(id: uid)));
  }

  /// Called whenever the signed-in user changes (app.dart): sets the user id
  /// to the Firebase uid (anonymous guests included, so guest journeys can be
  /// joined with Firestore data) and clears it on sign-out.
  void setAuthUser(AuthUser? user) {
    setUserId(user?.uid);
    setUserProperty('auth_method', user?.provider.name);
  }

  /// Keeps max_level / current_world in sync with the player's progress.
  void setProgress({required int highestUnlockedLevel}) {
    final maxLevel = highestUnlockedLevel.clamp(1, CampaignLevels.totalLevels);
    setUserProperty('max_level', '$maxLevel');
    setUserProperty('current_world', CampaignLevels.byLevelNumber(maxLevel).tier.name);
  }

  /// After a successful real-money purchase.
  void markPayer() => setUserProperty('is_payer', 'true');

  /// Google Consent Mode v2 (analytics_storage, ad_storage, ad_user_data,
  /// ad_personalization) from the UMP result - iOS/Android only.
  ///
  /// * notRequired (outside EEA/UK/CH): all granted.
  /// * required (consent region, but no decision could be collected, e.g.
  ///   the form failed to show): all denied until the user decides.
  /// * obtained: the UMP SDK itself writes the user's per-purpose choices to
  ///   Consent Mode for Google Analytics for Firebase. Those choices are not
  ///   exposed to Dart, and setConsent() persists and would override them,
  ///   so we deliberately leave them alone.
  /// * unknown (consent info could not be fetched): unchanged.
  Future<void> applyAdsConsent(AdsConsentState state) async {
    if (kDebugMode) debugPrint('[analytics] consent state ${state.name}');
    final bool granted;
    switch (state) {
      case AdsConsentState.notRequired:
        granted = true;
      case AdsConsentState.required:
        granted = false;
      case AdsConsentState.obtained:
      case AdsConsentState.unknown:
        return;
    }
    await _guard(
      'setConsent',
      (fa) => fa.setConsent(
        analyticsStorageConsentGranted: granted,
        adStorageConsentGranted: granted,
        adUserDataConsentGranted: granted,
        adPersonalizationSignalsConsentGranted: granted,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Screens
  // ---------------------------------------------------------------------------

  void screenView(String screenName, {int? levelId}) {
    try {
      final params = sanitizeParams({'level_id': levelId});
      if (kDebugMode) debugPrint('[analytics] screen_view $screenName $params');
      unawaited(_guard(
        'screen_view',
        (fa) => fa.logScreenView(screenName: screenName, screenClass: screenName, parameters: params),
      ));
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] screen_view failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Shared events
  // ---------------------------------------------------------------------------

  void tutorialBegin() => _log('tutorial_begin');

  void tutorialComplete({required bool skipped}) => _log('tutorial_complete', {'skipped': skipped});

  /// method: google | apple | facebook | guest | email
  void signUp(String method) => _log('sign_up', {'method': method});

  /// method: google | apple | facebook | guest | email
  void login(String method) => _log('login', {'method': method});

  /// virtual_currency_name: coins | hints.
  /// source: level | daily | ad | wheel | purchase | gift | other.
  void earnVirtualCurrency({
    required String currency,
    required int value,
    required String source,
    String? item,
  }) {
    if (value <= 0) return;
    _log('earn_virtual_currency', {
      'virtual_currency_name': currency,
      'value': value,
      'source': source,
      'item_name': item,
    });
  }

  void spendVirtualCurrency({required String currency, required int value, required String itemName}) {
    if (value <= 0) return;
    _log('spend_virtual_currency', {'virtual_currency_name': currency, 'value': value, 'item_name': itemName});
  }

  void adOfferShown({required String placement, String? reward}) =>
      _log('ad_offer_shown', {'placement': placement, 'reward': reward});

  void adRewardEarned({required String placement, required String reward}) =>
      _log('ad_reward_earned', {'placement': placement, 'reward': reward});

  /// format: rewarded | interstitial
  void adShowFailed({required String placement, required String format, required String reason}) =>
      _log('ad_show_failed', {'placement': placement, 'format': format, 'reason': reason});

  void storeOpen({required String source}) => _log('store_open', {'source': source});

  void purchaseStart({required String productId}) => _log('purchase_start', {'product_id': productId});

  void purchaseFailed({required String productId, required String reason}) =>
      _log('purchase_failed', {'product_id': productId, 'reason': reason});

  /// method: whatsapp | facebook | system | copy_link | copy_code.
  void share({required String method, required String contentType}) =>
      _log('share', {'method': method, 'content_type': contentType});

  void settingsChange({required String setting, required String value}) =>
      _log('settings_change', {'setting': setting, 'value': value});

  // ---------------------------------------------------------------------------
  // Word game events
  // ---------------------------------------------------------------------------

  static Map<String, Object?> _levelParams(LevelConfig config) => {
        'level_id': config.levelNumber,
        'world': config.tier.name,
        'level_kind': config.kind.name,
        'grid_size': config.gridSize,
      };

  /// Increments and returns the 1-based attempt number of [levelId]
  /// (persisted in Hive across sessions; in-memory only in tests).
  Future<int> _nextAttempt(int levelId) async {
    final inMemory = _memoryAttempts[levelId] ?? 0;
    var attempt = inMemory + 1;
    if (_persistAttempts) {
      try {
        final box = _attemptsBox ??= await Hive.openBox(attemptsBoxName).timeout(const Duration(seconds: 2));
        final Object? stored = box.get('attempt_$levelId');
        final int previous = stored is int && stored > inMemory ? stored : inMemory;
        attempt = previous + 1;
        await box.put('attempt_$levelId', attempt);
      } catch (e) {
        if (kDebugMode) debugPrint('[analytics] attempt counter not persisted: $e');
      }
    }
    _memoryAttempts[levelId] = attempt;
    return attempt;
  }

  /// Logs level_start and returns the attempt number for the run's other
  /// events. Never throws.
  Future<int> levelStart(LevelConfig config) async {
    var attempt = 0;
    try {
      attempt = await _nextAttempt(config.levelNumber);
      _log('level_start', {..._levelParams(config), 'attempt': attempt});
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] level_start failed: $e');
    }
    return attempt;
  }

  /// reason: win | time_up | out_of_moves | other.
  /// success = 1 when the level was passed (at least 1 star) by playing it.
  /// time_sec = game-clock seconds since level_start (pauses excluded),
  /// wall_sec = real seconds since level_start (pauses included).
  void levelEnd({
    required LevelConfig config,
    required int attempt,
    required bool success,
    required int score,
    required int stars,
    required int wordsFound,
    required int wordsPossible,
    required int timeSec,
    required int wallSec,
    required int hintsUsed,
    required String reason,
    int shufflesUsed = 0,
    int coinsEarned = 0,
    bool firstClear = false,
  }) {
    _log('level_end', {
      ..._levelParams(config),
      'attempt': attempt,
      'success': success,
      'score': score,
      'stars': stars,
      'words_found': wordsFound,
      // The campaign goal is a score, not a word count - see LevelConfig.
      'score_target': config.scoreRequired,
      'words_possible': wordsPossible,
      'time_sec': timeSec,
      'wall_sec': wallSec,
      'hints_used': hintsUsed,
      'shuffles_used': shufflesUsed,
      'reason': reason,
      'coins_earned': coinsEarned,
      'first_clear': firstClear,
    });
  }

  /// quit_type: exit | restart | skip | abandon.
  void levelQuit({
    required LevelConfig config,
    required int attempt,
    required int timeSec,
    required int wordsFound,
    required int score,
    required String quitType,
  }) {
    _log('level_quit', {
      ..._levelParams(config),
      'attempt': attempt,
      'time_sec': timeSec,
      'words_found': wordsFound,
      'score': score,
      'quit_type': quitType,
    });
  }

  /// hint_type: word_hint | reveal_letter | shuffle. cost_currency: hints | coins.
  void hintUsed({required int levelId, required String hintType, required int cost, required String costCurrency}) =>
      _log('hint_used', {'level_id': levelId, 'hint_type': hintType, 'cost': cost, 'cost_currency': costCurrency});

  void worldUnlocked(WorldTier world) => _log('world_unlocked', {'world': world.name});

  /// Logs world_unlocked when the highest unlocked level moved into a new
  /// world (finale passed or skipped).
  void worldUnlockedIfCrossed({required int highestBefore, required int highestAfter}) {
    try {
      final total = CampaignLevels.totalLevels;
      if (highestAfter <= highestBefore || highestAfter > total) return;
      final before = CampaignLevels.byLevelNumber(highestBefore.clamp(1, total)).tier;
      final after = CampaignLevels.byLevelNumber(highestAfter).tier;
      if (after != before) worldUnlocked(after);
    } catch (e) {
      if (kDebugMode) debugPrint('[analytics] world_unlocked failed: $e');
    }
  }

  void wheelSpin({required String rewardType, required int rewardValue}) =>
      _log('wheel_spin', {'reward_type': rewardType, 'reward_value': rewardValue});

  void dailyStart({required String dailyDate, required int gridSize}) =>
      _log('daily_start', {'daily_date': dailyDate, 'grid_size': gridSize});

  /// reason: time_up | quit | abandon.
  void dailyEnd({
    required String dailyDate,
    required bool success,
    required int score,
    required int timeSec,
    required int wordsFound,
    required String reason,
  }) {
    _log('daily_end', {
      'daily_date': dailyDate,
      'success': success,
      'score': score,
      'time_sec': timeSec,
      'words_found': wordsFound,
      'reason': reason,
    });
  }

  /// mode: bots | friends.
  void mpMatchStart({required String mode, required int players, required int gridSize}) =>
      _log('mp_match_start', {'mode': mode, 'players': players, 'grid_size': gridSize});

  /// result: win | lose | draw | abandon.
  void mpMatchEnd({
    required String mode,
    required int players,
    required String result,
    required int score,
    required int durationSec,
  }) {
    _log('mp_match_end', {
      'mode': mode,
      'players': players,
      'result': result,
      'score': score,
      'duration_sec': durationSec,
    });
  }
}

/// Riverpod access to the analytics singleton (widgets/notifiers use this;
/// non-widget code such as repositories can use [AnalyticsService.instance]).
final analyticsProvider = Provider<AnalyticsService>((ref) => AnalyticsService.instance);
