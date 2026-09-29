import 'package:flutter/widgets.dart';

/// חוזה הפרסומות שמסכי המשחק מכירים. המימוש האמיתי (AdMob) חי רק
/// בקבצי iOS/Android; ב-Web ובבדיקות משתמשים במימוש שלא נוגע ב-SDK.
abstract class AdsGateway extends ChangeNotifier {
  bool get isSupported;

  bool get isInitialized;

  /// אחרי טופס ההסכמה (UMP): מותר לבקש פרסומות, כולל לא-מותאמות.
  bool get canRequestAds;

  bool get isRewardedReady;

  int get adHintsRemaining;

  int get storeRewardsRemaining;

  bool get dailyBonusAdAvailable;

  /// כפתור "אפשרויות פרטיות" נדרש כשהמשתמש באזור שבו Google דורשת זאת.
  bool get privacyOptionsRequired;

  Future<void> ensureInitialized();

  /// true רק אחרי שהצופה הרוויח את הפרס (לא אם סגר מוקדם או שאין מודעה).
  Future<bool> showRewarded();

  /// מציג אינטרסטיאל רק אם [AdsPolicy] מאפשר. true אם המודעה הוצגה.
  Future<bool> showInterstitialIfAllowed({required int levelNumber});

  Future<void> recordCampaignLevelFinished(int levelNumber);

  Future<void> recordAdHintGranted();

  Future<void> recordStoreRewardGranted();

  Future<void> recordDailyBonusAdGranted();

  Future<void> showPrivacyOptions();

  /// כרטיס Native, או תיבה ריקה כשאין מודעה. לא נטען ב-Web.
  Widget buildNativePlacement();
}
