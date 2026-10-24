/// מזהי יחידות AdMob.
///
/// ברירת המחדל היא מזהי הבדיקה הרשמיים של Google, כדי שאפשר לפתח בלי
/// חשבון AdMob ובלי להסתכן בחסימה על פרסומות בדיקה בחשבון אמיתי.
/// בפרודקשן מעבירים מזהים אמיתיים דרך --dart-define. בבילד release בלי
/// מזהים כאלה הפרסומות כבויות לגמרי (ראו AdsMobileGateway.isSupported).
///
/// גם מזהה האפליקציה ב-AndroidManifest.xml / Info.plist הוא מזהה בדיקה
/// עד שמחליפים אותו. ראו docs/STORE_LAUNCH_CHECKLIST.md.
class AdsConfig {
  AdsConfig._();

  static const String rewardedAndroid = String.fromEnvironment(
    'ADMOB_REWARDED_ANDROID',
  );
  static const String rewardedIos = String.fromEnvironment(
    'ADMOB_REWARDED_IOS',
  );
  static const String interstitialAndroid = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_ANDROID',
  );
  static const String interstitialIos = String.fromEnvironment(
    'ADMOB_INTERSTITIAL_IOS',
  );
  static const String nativeAndroid = String.fromEnvironment(
    'ADMOB_NATIVE_ANDROID',
  );
  static const String nativeIos = String.fromEnvironment('ADMOB_NATIVE_IOS');

  /// בקשת אישור מעקב (ATT) ב-iOS, מופעלת בבילד החנות (ATT_ENABLED=true ב-
  /// config/release.json). NSUserTrackingUsageDescription נמצא ב-Info.plist, והודעת
  /// ההסבר (IDFA explainer) של AdMob מוצגת לפני הדיאלוג של Apple. לפני העלאת
  /// בילד כזה חובה לסמן ב-App Privacy ש-Device ID ונתוני פרסום משמשים ל-Tracking.
  static const bool trackingPrompt = bool.fromEnvironment('ATT_ENABLED');

  /// מכשירי בדיקה (מופרדים בפסיק): מקבלים מודעות בדיקה גם עם המזהים
  /// האמיתיים, כדי שבדיקות על האייפון של המפתח לא ייחשבו כתנועה לא תקינה.
  /// את המזהה של מכשיר מוצאים בלוג של Xcode בהפעלה הראשונה:
  /// "To get test ads on this device, set: ... testDeviceIdentifiers = @[ @"..." ]".
  /// סימולטורים הם תמיד מכשירי בדיקה.
  static const String _testDeviceIdsRaw = String.fromEnvironment(
    'ADMOB_TEST_DEVICE_IDS',
  );

  static List<String> get testDeviceIds => parseDeviceIds(_testDeviceIdsRaw);

  static List<String> parseDeviceIds(String raw) => raw
      .split(',')
      .map((id) => id.trim())
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  /// מזהה מפרסם AdSense לאתר (`ca-pub-...`). בלי המזהה האתר מציג
  /// את מודעת הדוגמה של Google. עם המזהה, בבילד release, רצות פרסומות אמיתיות.
  static const String adsenseClient = String.fromEnvironment('ADSENSE_CLIENT');

  static const String testAppIdAndroid =
      'ca-app-pub-3940256099942544~3347511713';
  static const String testAppIdIos = 'ca-app-pub-3940256099942544~1458002511';

  static const String testRewardedAndroid =
      'ca-app-pub-3940256099942544/5224354917';
  static const String testRewardedIos =
      'ca-app-pub-3940256099942544/1712485313';
  static const String testInterstitialAndroid =
      'ca-app-pub-3940256099942544/1033173712';
  static const String testInterstitialIos =
      'ca-app-pub-3940256099942544/4411468910';
  static const String testNativeAndroid =
      'ca-app-pub-3940256099942544/2247696110';
  static const String testNativeIos = 'ca-app-pub-3940256099942544/3986624511';

  static String rewardedUnitId({required bool isIos}) => isIos
      ? _pick(rewardedIos, testRewardedIos)
      : _pick(rewardedAndroid, testRewardedAndroid);

  static String interstitialUnitId({required bool isIos}) => isIos
      ? _pick(interstitialIos, testInterstitialIos)
      : _pick(interstitialAndroid, testInterstitialAndroid);

  static String nativeUnitId({required bool isIos}) => isIos
      ? _pick(nativeIos, testNativeIos)
      : _pick(nativeAndroid, testNativeAndroid);

  /// true רק אם לפלטפורמה הנוכחית הועברו שלושת מזהי היחידות (מתנה,
  /// מסך מלא, ומובנית). מזהה האפליקציה עצמו נשאר בקבצי ה-native.
  static bool hasProductionIds({required bool isIos}) {
    if (isIos) {
      return rewardedIos.isNotEmpty &&
          interstitialIos.isNotEmpty &&
          nativeIos.isNotEmpty;
    }
    return rewardedAndroid.isNotEmpty &&
        interstitialAndroid.isNotEmpty &&
        nativeAndroid.isNotEmpty;
  }

  static String _pick(String override, String testId) =>
      override.isNotEmpty ? override : testId;
}
