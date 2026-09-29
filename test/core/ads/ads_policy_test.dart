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
  }) {
    return AdsPolicy.shouldShowInterstitial(
      levelNumber: levelNumber,
      levelsSinceLastInterstitial: levelsSince,
      lastFullScreenAt: lastFullScreenAt,
      now: now,
      canRequestAds: canRequestAds,
      adLoaded: adLoaded,
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
}
