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

  /// מזהה מפרסם AdSense לאתר (`ca-pub-...`). בלי המזהה, בבילד release
  /// אין פרסומות באתר. בפיתוח רצה מצב בדיקה של Google בלי מזהה.
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
