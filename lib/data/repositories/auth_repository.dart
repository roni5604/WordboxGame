import '../models/auth_user.dart';

/// ממשק מופשט להתחברות/הרשמה - כמו [ProgressRepository], יש שני מימושים:
/// [LocalAuthRepository] (ברירת מחדל, אורח בלבד, ללא שרת) ו-
/// [FirebaseAuthRepository] (Google/Apple/Facebook/מייל+סיסמה אמיתיים,
/// דורש הפעלת AppConfig.useFirebaseBackend - ראו docs/FIREBASE_SETUP.md).
abstract class AuthRepository {
  /// זרם שמעדכן בכל שינוי במשתמש המחובר (כניסה/יציאה/החלפת חשבון).
  Stream<AuthUser?> authStateChanges();

  /// המשתמש המחובר כרגע, אם יש.
  AuthUser? get currentUser;

  /// כניסה כאורח - תמיד זמינה, גם ללא הגדרת שרת.
  Future<AuthUser> signInAsGuest();

  Future<AuthUser> signInWithGoogle();
  Future<AuthUser> signInWithApple();
  Future<AuthUser> signInWithFacebook();
  Future<AuthUser> signInWithEmail({required String email, required String password});
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  });

  Future<void> signOut();
}
