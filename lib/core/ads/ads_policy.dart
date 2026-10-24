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

  /// Google מבטלת מודעה טעונה אחרי שעה. מודעה ישנה יותר לא מוצגת (היא
  /// לא תניב הכנסה) אלא מוחלפת בחדשה.
  static const Duration adMaxAge = Duration(minutes: 55);

  /// ניסיון טעינה חוזר אחרי כישלון: 10, 20, 40... שניות, עד 5 דקות,
  /// כדי לא להציף את AdMob בבקשות כשאין מלאי (Google ממליצה על backoff).
  static const Duration retryBase = Duration(seconds: 10);
  static const Duration retryMax = Duration(minutes: 5);

  static Duration retryDelay(int failedAttempts) {
    final exponent = failedAttempts < 1 ? 0 : (failedAttempts - 1).clamp(0, 10);
    final delay = retryBase * (1 << exponent);
    return delay > retryMax ? retryMax : delay;
  }

  static bool isAdFresh({required DateTime loadedAt, required DateTime now}) =>
      now.difference(loadedAt) < adMaxAge;

  static bool shouldShowInterstitial({
    required int levelNumber,
    required int levelsSinceLastInterstitial,
    required DateTime? lastFullScreenAt,
    required DateTime now,
    required bool canRequestAds,
    required bool adLoaded,
    bool isPayer = false,
  }) {
    if (!canRequestAds || !adLoaded) return false;
    // מי שקנה/תה בכסף אמיתי לא רואה מודעות מסך מלא שלא ביקש/ה. מתנות
    // תמורת צפייה עדיין זמינות - הן תמיד בחירה.
    if (isPayer) return false;
    if (levelNumber <= tutorialLevelsToSkip) return false;
    if (levelsSinceLastInterstitial < interstitialEveryLevels) return false;
    if (lastFullScreenAt != null &&
        now.difference(lastFullScreenAt) < interstitialMinGap) {
      return false;
    }
    return true;
  }
}
