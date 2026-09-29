import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';

import 'ads_policy.dart';

/// מוני פרסומות יומיים ומרווח האינטרסטיאל. נשמרים ב-Hive בתיבה נפרדת
/// מהפרופיל (`wordbox_ads`), כדי לא לשבור פרופילים קיימים ולא לערבב
/// מגבלת צפייה מקומית עם סנכרון ההתקדמות לענן.
class AdsQuotaStore {
  static const String boxName = 'wordbox_ads';

  AdsQuotaStore({DateTime Function()? clock}) : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;

  Box? _box;
  bool _loaded = false;

  String? _hintsDate;
  int _hintsToday = 0;
  String? _storeDate;
  int _storeToday = 0;
  String? _dailyBonusAdDate;
  int _levelsSinceInterstitial = 0;
  int? _lastFullScreenAtMs;

  String get todayKey {
    final now = _clock();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  int get adHintsRemaining =>
      _remaining(_hintsDate, _hintsToday, AdsPolicy.maxAdHintsPerDay);

  int get storeRewardsRemaining =>
      _remaining(_storeDate, _storeToday, AdsPolicy.maxStoreRewardsPerDay);

  bool get dailyBonusAdAvailable => _dailyBonusAdDate != todayKey;

  int get levelsSinceInterstitial => _levelsSinceInterstitial;

  DateTime? get lastFullScreenAt => _lastFullScreenAtMs == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(_lastFullScreenAtMs!);

  Future<void> load() async {
    if (_loaded) return;
    try {
      final box = await Hive.openBox(boxName);
      _box = box;
      _hintsDate = box.get('ad_hints_date') as String?;
      _hintsToday = box.get('ad_hints_today', defaultValue: 0) as int;
      _storeDate = box.get('ad_store_date') as String?;
      _storeToday = box.get('ad_store_today', defaultValue: 0) as int;
      _dailyBonusAdDate = box.get('daily_bonus_ad_date') as String?;
      _levelsSinceInterstitial =
          box.get('levels_since_interstitial', defaultValue: 0) as int;
      _lastFullScreenAtMs = box.get('last_fullscreen_at_ms') as int?;
    } catch (e) {
      debugPrint('Ads quota load skipped: $e');
    }
    _loaded = true;
  }

  Future<void> recordAdHint() async {
    if (adHintsRemaining <= 0) return;
    final today = todayKey;
    if (_hintsDate != today) {
      _hintsDate = today;
      _hintsToday = 0;
    }
    _hintsToday += 1;
    await _persist({
      'ad_hints_date': _hintsDate,
      'ad_hints_today': _hintsToday,
    });
  }

  Future<void> recordStoreReward() async {
    if (storeRewardsRemaining <= 0) return;
    final today = todayKey;
    if (_storeDate != today) {
      _storeDate = today;
      _storeToday = 0;
    }
    _storeToday += 1;
    await _persist({
      'ad_store_date': _storeDate,
      'ad_store_today': _storeToday,
    });
  }

  Future<void> recordDailyBonusAd() async {
    _dailyBonusAdDate = todayKey;
    await _persist({'daily_bonus_ad_date': _dailyBonusAdDate});
  }

  /// סופר שלב קמפיין שהסתיים, לצורך תדירות האינטרסטיאל. שלבי ההדרכה
  /// (1-3) לא נספרים.
  Future<void> recordCampaignLevelFinished(int levelNumber) async {
    if (levelNumber <= AdsPolicy.tutorialLevelsToSkip) return;
    _levelsSinceInterstitial += 1;
    await _persist({'levels_since_interstitial': _levelsSinceInterstitial});
  }

  Future<void> resetInterstitialCounter() async {
    _levelsSinceInterstitial = 0;
    await _persist({'levels_since_interstitial': 0});
  }

  Future<void> markFullScreenShown(DateTime when) async {
    _lastFullScreenAtMs = when.millisecondsSinceEpoch;
    await _persist({'last_fullscreen_at_ms': _lastFullScreenAtMs});
  }

  int _remaining(String? storedDate, int used, int max) {
    if (storedDate != todayKey) return max;
    final left = max - used;
    if (left <= 0) return 0;
    return left;
  }

  Future<void> _persist(Map<String, Object?> values) async {
    try {
      await _box?.putAll(values);
    } catch (e) {
      debugPrint('Ads quota save skipped: $e');
    }
  }
}
