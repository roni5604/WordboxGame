/// כללי תדירות ומתנות לפרסומות. לוגיקה טהורה, בלי SDK ובלי אחסון,
/// כדי שאפשר לבדוק אותה בלי לאתחל את AdMob.
class AdsPolicy {
  AdsPolicy._();

  /// שלבים 1-3 הם הדרכה - אין אינטרסטיאל, והם גם לא נספרים למונה.
  static const int tutorialLevelsToSkip = 3;

  /// אינטרסטיאל לכל היותר אחרי כל 3 שלבי קמפיין שהושלמו (מעבר להדרכה).
  static const int interstitialEveryLevels = 3;

  /// מרווח מינימלי בין שתי מודעות מסך-מלא (Rewarded או Interstitial).
  static const Duration interstitialMinGap = Duration(seconds: 120);

  /// רמזים מצפייה במהלך שלב, ביום קלנדרי אחד (היה 3).
  static const int maxAdHintsPerDay = 2;

  /// צפיות מתנה בחנות (רמז או מטבעות), ביום קלנדרי אחד.
  static const int maxStoreRewardsPerDay = 2;

  /// מטבעות למתנת חנות. פחות ממחיר רמז בודד (60) כדי שהחנות תישאר רלוונטית.
  static const int storeCoinGift = 25;

  static bool shouldShowInterstitial({
    required int levelNumber,
    required int levelsSinceLastInterstitial,
    required DateTime? lastFullScreenAt,
    required DateTime now,
    required bool canRequestAds,
    required bool adLoaded,
  }) {
    if (!canRequestAds || !adLoaded) return false;
    if (levelNumber <= tutorialLevelsToSkip) return false;
    if (levelsSinceLastInterstitial < interstitialEveryLevels) return false;
    if (lastFullScreenAt != null &&
        now.difference(lastFullScreenAt) < interstitialMinGap) {
      return false;
    }
    return true;
  }
}
