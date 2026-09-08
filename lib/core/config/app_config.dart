/// דגלי תצורה גלובליים לאפליקציה.
///
/// [useFirebaseBackend] כבוי כברירת מחדל כדי שהמשחק היחיד-שחקן ירוץ באופן
/// מלא ואופליין ללא שום הגדרה חיצונית. לאחר הרצת `flutterfire configure`
/// (ראו docs/FIREBASE_SETUP.md) ניתן להפעיל את הדגל כדי לחבר סנכרון ענן,
/// לוח מובילים, והתחברות משתמשים.
class AppConfig {
  AppConfig._();

  static const bool useFirebaseBackend = bool.fromEnvironment(
    'USE_FIREBASE',
    defaultValue: false,
  );

  /// מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית) - כרגע מוצג כ"בקרוב".
  static const bool multiplayerEnabled = bool.fromEnvironment(
    'MULTIPLAYER_ENABLED',
    defaultValue: false,
  );
}
