import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/ads/ads_policy.dart';

void main() {
  final now = DateTime(2026, 9, 29, 15);

  bool allow({
    int levelNumber = 8,
    int levelsSince = 3,
    DateTime? lastFullScreenAt,
    bool canRequestAds = true,
    bool adLoaded = true,
    bool isPayer = false,
  }) {
    return AdsPolicy.shouldShowInterstitial(
      levelNumber: levelNumber,
      levelsSinceLastInterstitial: levelsSince,
      lastFullScreenAt: lastFullScreenAt,
      now: now,
      canRequestAds: canRequestAds,
      adLoaded: adLoaded,
      isPayer: isPayer,
    );
  }

  test('לא מציגים בלי הסכמה או בלי מודעה טעונה', () {
    expect(allow(canRequestAds: false), isFalse);
    expect(allow(adLoaded: false), isFalse);
  });

  test('שלבי ההדרכה 1-3 לא מציגים אינטרסטיאל', () {
    expect(allow(levelNumber: 1), isFalse);
    expect(allow(levelNumber: 2), isFalse);
    expect(allow(levelNumber: 3), isFalse);
    expect(allow(levelNumber: 4), isTrue);
  });

  test('רק אחרי 3 שלבי קמפיין מאז המודעה הקודמת', () {
    expect(allow(levelsSince: 2), isFalse);
    expect(allow(levelsSince: 3), isTrue);
    expect(allow(levelsSince: 5), isTrue);
  });

  test('מרווח של שתי דקות מאז מודעת מסך מלא קודמת', () {
    expect(
      allow(lastFullScreenAt: now.subtract(const Duration(seconds: 119))),
      isFalse,
    );
    expect(
      allow(lastFullScreenAt: now.subtract(const Duration(seconds: 120))),
      isTrue,
    );
    expect(allow(lastFullScreenAt: null), isTrue);
  });

  test('מי שקנה/תה בכסף אמיתי לא רואה אינטרסטיאל', () {
    expect(allow(isPayer: true), isFalse);
    expect(allow(isPayer: true, levelsSince: 50), isFalse);
    expect(allow(isPayer: false), isTrue);
  });

  test('מודעה טעונה תקפה פחות משעה (55 דקות)', () {
    final loadedAt = now.subtract(const Duration(minutes: 54, seconds: 59));
    expect(AdsPolicy.isAdFresh(loadedAt: loadedAt, now: now), isTrue);
    expect(
      AdsPolicy.isAdFresh(
        loadedAt: now.subtract(AdsPolicy.adMaxAge),
        now: now,
      ),
      isFalse,
    );
    expect(
      AdsPolicy.isAdFresh(
        loadedAt: now.subtract(const Duration(hours: 2)),
        now: now,
      ),
      isFalse,
    );
  });

  test('ניסיון טעינה חוזר מתארך פי 2 עד תקרה של 5 דקות', () {
    expect(AdsPolicy.retryDelay(0), const Duration(seconds: 10));
    expect(AdsPolicy.retryDelay(1), const Duration(seconds: 10));
    expect(AdsPolicy.retryDelay(2), const Duration(seconds: 20));
    expect(AdsPolicy.retryDelay(3), const Duration(seconds: 40));
    expect(AdsPolicy.retryDelay(5), const Duration(seconds: 160));
    expect(AdsPolicy.retryDelay(6), AdsPolicy.retryMax);
    expect(AdsPolicy.retryDelay(100), AdsPolicy.retryMax);
  });
}
