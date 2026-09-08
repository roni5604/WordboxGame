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

  /// מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית) - כרגע מוצג כ"בקרוב".
  static const bool multiplayerEnabled = bool.fromEnvironment(
    'MULTIPLAYER_ENABLED',
    defaultValue: false,
  );
}
