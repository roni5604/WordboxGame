/// דגלי תצורה גלובליים לאפליקציה.
///
/// [useFirebaseBackend] מופעל כברירת מחדל - פרויקט Firebase אמיתי
/// (wordbox-64b19) כבר מחובר (ראו lib/firebase_options.dart ו-
/// docs/FIREBASE_SETUP.md): Authentication (אורח/מייל/Google/Apple) ו-
/// Firestore פעילים. אפשר לכבות זמנית לצורך פיתוח אופליין עם:
///   flutter run --dart-define=USE_FIREBASE=false
class AppConfig {
  AppConfig._();

  static const bool useFirebaseBackend = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: true,
  );

  /// מצב "משחק מול חברים" (חדרים פרטיים אמיתיים דרך Firestore) פעיל
  /// כברירת מחדל - ראו lib/features/multiplayer/. אפשר לכבות זמנית (למשל
  /// אם חוקי Firestore עדיין לא נפרסו בפרודקשן) עם:
  ///   flutter run --dart-define=MULTIPLAYER_ENABLED=false
  static const bool multiplayerEnabled = bool.fromEnvironment(
    'MULTIPLAYER_ENABLED',
    defaultValue: true,
  );

  /// התחברות עם Google באפליקציה (iOS/Android). דורשת הפעלת Google ב-Firebase
  /// Authentication, טביעות SHA באנדרואיד, והורדה מחדש של google-services.json
  /// ו-GoogleService-Info.plist. אחרי זה בונים עם GOOGLE_LOGIN_NATIVE=true.
  /// באתר Google תמיד זמין.
  static const bool googleLoginNative = bool.fromEnvironment('GOOGLE_LOGIN_NATIVE');

  /// מפתח VAPID ציבורי ל-push באתר (Firebase Console → Project settings →
  /// Cloud Messaging → Web Push certificates). המפתח ציבורי - לא סוד. כל עוד
  /// הוא ריק, האתר מסתפק בהתראות כשהלשונית פתוחה ברקע (בלי push מהשרת).
  ///   flutter build web --dart-define=WEB_PUSH_VAPID_KEY=...
  static const String webPushVapidKey = String.fromEnvironment('WEB_PUSH_VAPID_KEY');
}
