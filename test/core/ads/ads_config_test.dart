import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/ads/ads_config.dart';

void main() {
  test('בלי dart-define משתמשים במזהי הבדיקה של Google', () {
    // בבדיקות לא מועברים מזהים אמיתיים - כך גם בפיתוח, ולכן אין סכנה
    // ללחוץ על מודעה אמיתית בטעות.
    expect(AdsConfig.hasProductionIds(isIos: true), isFalse);
    expect(AdsConfig.hasProductionIds(isIos: false), isFalse);
    expect(AdsConfig.rewardedUnitId(isIos: true), AdsConfig.testRewardedIos);
    expect(
      AdsConfig.interstitialUnitId(isIos: true),
      AdsConfig.testInterstitialIos,
    );
    expect(AdsConfig.nativeUnitId(isIos: true), AdsConfig.testNativeIos);
    expect(
      AdsConfig.rewardedUnitId(isIos: false),
      AdsConfig.testRewardedAndroid,
    );
  });

  test('מזהי הבדיקה שייכים לחשבון הבדיקה של Google', () {
    for (final id in [
      AdsConfig.testRewardedIos,
      AdsConfig.testInterstitialIos,
      AdsConfig.testNativeIos,
      AdsConfig.testRewardedAndroid,
      AdsConfig.testInterstitialAndroid,
      AdsConfig.testNativeAndroid,
    ]) {
      expect(id, startsWith('ca-app-pub-3940256099942544/'));
    }
  });

  test('רשימת מכשירי בדיקה: פסיקים, רווחים ורשומות ריקות', () {
    expect(AdsConfig.parseDeviceIds(''), isEmpty);
    expect(AdsConfig.parseDeviceIds(' abc , ,def,'), ['abc', 'def']);
    expect(AdsConfig.testDeviceIds, isEmpty);
  });
}
