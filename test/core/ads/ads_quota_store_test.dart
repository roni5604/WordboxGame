import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:wordbox_hebrew/core/ads/ads_policy.dart';
import 'package:wordbox_hebrew/core/ads/ads_quota_store.dart';

void main() {
  late Directory dir;
  var now = DateTime(2026, 9, 29, 12);

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('wordbox_ads_test');
    Hive.init(dir.path);
    now = DateTime(2026, 9, 29, 12);
  });

  tearDown(() async {
    if (Hive.isBoxOpen(AdsQuotaStore.boxName)) {
      await Hive.box(AdsQuotaStore.boxName).close();
    }
    await Hive.deleteBoxFromDisk(AdsQuotaStore.boxName);
    if (dir.existsSync()) await dir.delete(recursive: true);
  });

  AdsQuotaStore store() => AdsQuotaStore(clock: () => now);

  test('מכסות יומיות מתחילות מלאות ומתאפסות ביום חדש', () async {
    final quota = store();
    await quota.load();
    expect(quota.adHintsRemaining, AdsPolicy.maxAdHintsPerDay);
    expect(quota.storeRewardsRemaining, AdsPolicy.maxStoreRewardsPerDay);
    expect(quota.dailyBonusAdAvailable, isTrue);

    await quota.recordAdHint();
    await quota.recordAdHint();
    await quota.recordStoreReward();
    await quota.recordDailyBonusAd();
    expect(quota.adHintsRemaining, AdsPolicy.maxAdHintsPerDay - 2);
    expect(quota.storeRewardsRemaining, AdsPolicy.maxStoreRewardsPerDay - 1);
    expect(quota.dailyBonusAdAvailable, isFalse);

    now = DateTime(2026, 9, 30, 8);
    expect(quota.adHintsRemaining, AdsPolicy.maxAdHintsPerDay);
    expect(quota.storeRewardsRemaining, AdsPolicy.maxStoreRewardsPerDay);
    expect(quota.dailyBonusAdAvailable, isTrue);
  });

  test('שלבי הדרכה לא נספרים לאינטרסטיאל, והמונה נשמר בין טעינות', () async {
    final quota = store();
    await quota.load();
    await quota.recordCampaignLevelFinished(1);
    await quota.recordCampaignLevelFinished(3);
    expect(quota.levelsSinceInterstitial, 0);
    await quota.recordCampaignLevelFinished(4);
    await quota.recordCampaignLevelFinished(5);
    await quota.recordCampaignLevelFinished(6);
    expect(quota.levelsSinceInterstitial, 3);

    final shownAt = DateTime(2026, 9, 29, 12, 5);
    await quota.markFullScreenShown(shownAt);
    await quota.resetInterstitialCounter();

    if (Hive.isBoxOpen(AdsQuotaStore.boxName)) {
      await Hive.box(AdsQuotaStore.boxName).close();
    }
    final reloaded = store();
    await reloaded.load();
    expect(reloaded.levelsSinceInterstitial, 0);
    expect(reloaded.lastFullScreenAt, shownAt);
  });

  test('אי אפשר לעבור את המכסה גם בקריאות חוזרות', () async {
    final quota = store();
    await quota.load();
    for (var i = 0; i < 6; i++) {
      await quota.recordAdHint();
    }
    expect(quota.adHintsRemaining, 0);
  });
}
