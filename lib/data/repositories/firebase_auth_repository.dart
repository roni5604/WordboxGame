import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:math';

import '../models/auth_user.dart';
import '../services/account_data_eraser.dart';
import 'auth_repository.dart';

/// מימוש אמיתי מבוסס Firebase Authentication - פעיל רק אחרי
/// `flutterfire configure` + הפעלת AppConfig.useFirebaseBackend
/// (ראו docs/FIREBASE_SETUP.md, כולל הוראות הפעלת כל ספק).
///
/// גישה: בדפדפן (Web) נעשה שימוש ב-`signInWithPopup` ישירות מול
/// Firebase (עובד לכל אחד מהספקים בלי SDK ילידי נוסף - רק צריך להפעיל
/// את הספק בקונסולת Firebase). בנייד/דסקטופ נעשה שימוש ב-SDK הילידי
/// המתאים (google_sign_in / sign_in_with_apple)
/// וממירים את הפלט שלו לאישור (credential) של Firebase.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  FirebaseAuthRepository({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  AuthUser _mapUser(fb.User user, {bool isNewUser = false}) {
    AuthProviderType provider = AuthProviderType.guest;
    fb.UserInfo? providerInfo;
    if (!user.isAnonymous) {
      providerInfo = user.providerData.isNotEmpty ? user.providerData.first : null;
      final providerId = providerInfo?.providerId ?? '';
      provider = switch (providerId) {
        'google.com' => AuthProviderType.google,
        'apple.com' => AuthProviderType.apple,
        'facebook.com' => AuthProviderType.facebook,
        'password' => AuthProviderType.email,
        _ => AuthProviderType.email,
      };
    }
    // כשמקשרים חשבון אורח/ת לספק (Google/Apple) עם
    // linkWithCredential/linkWithPopup, Firebase לא בהכרח מעדכן את השדות
    // הראשיים displayName/photoURL של המשתמש - הם נשארים null (מהאורח/ת),
    // בזמן שהמידע האמיתי מהספק קיים רק בתוך providerData. לכן, כל עוד
    // השדה הראשי ריק, נופלים חזרה למידע מה-provider כדי שהשם והתמונה
    // האמיתיים באמת יופיעו במקום להישאר "תקועים" עם ערך ריק.
    final displayName = (user.displayName?.trim().isNotEmpty ?? false)
        ? user.displayName
        : providerInfo?.displayName;
    final photoUrl = (user.photoURL?.trim().isNotEmpty ?? false)
        ? user.photoURL
        : providerInfo?.photoURL;
    final email = user.email ?? providerInfo?.email;
    return AuthUser(
      uid: user.uid,
      displayName: displayName,
      email: email,
      photoUrl: photoUrl,
      isAnonymous: user.isAnonymous,
      provider: provider,
      isNewUser: isNewUser,
    );
  }

  @override
  Stream<AuthUser?> authStateChanges() =>
      // משתמשים ב-userChanges() ולא ב-authStateChanges(): קישור אורח/ת לחשבון
      // אמיתי (linkWithCredential/linkWithPopup) לא משנה את ה-UID, כך ש-
      // authStateChanges() לא בהכרח יודיע על השינוי - וה-UI (כפתורי
      // התחברות מול כרטיס חשבון) עלול "להיתקע" עם המצב הישן. userChanges()
      // מכסה גם אירועי linking/unlinking/עדכון פרופיל, לא רק sign-in/out.
      _auth.userChanges().map((u) => u == null ? null : _mapUser(u));

  @override
  AuthUser? get currentUser {
    final u = _auth.currentUser;
    return u == null ? null : _mapUser(u);
  }

  AuthException _friendlyError(Object error) {
    if (error is fb.FirebaseAuthException) {
      final message = switch (error.code) {
        'invalid-email' => 'כתובת המייל לא תקינה.',
        'user-disabled' => 'המשתמש הזה חסום.',
        'user-not-found' => 'לא נמצא משתמש עם הפרטים האלו.',
        'wrong-password' || 'invalid-credential' => 'סיסמה שגויה או פרטי התחברות לא תקינים.',
        'email-already-in-use' || 'credential-already-in-use' =>
          'כתובת המייל הזו כבר משויכת לחשבון אחר.',
        'weak-password' => 'הסיסמה חלשה מדי - נסו סיסמה עם 6 תווים לפחות.',
        'network-request-failed' => 'בעיית רשת - בדקו את החיבור לאינטרנט ונסו שוב.',
        'popup-closed-by-user' || 'canceled' || 'sign_in_canceled' => 'ההתחברות בוטלה.',
        'operation-not-allowed' => 'שיטת ההתחברות הזו לא מופעלת עדיין בפרויקט.',
        _ => 'משהו השתבש בהתחברות (${error.code}). נסו שוב.',
      };
      return AuthException(message);
    }
    return AuthException('משהו השתבש בהתחברות. נסו שוב.');
  }

  /// אחרי קישור/התחברות מוצלחת, מעתיק displayName/photoURL מ-providerData
  /// (המידע האמיתי מהספק) לשדות הראשיים של המשתמש, אם הם עדיין ריקים -
  /// כדי שהשם והתמונה יישארו נכונים בכל מקום שקורא אותם ישירות מ-Firebase,
  /// ולא רק דרך ה-fallback שב-_mapUser. לא קריטי אם זה נכשל.
  Future<void> _backfillProfileFromProvider(fb.User user) async {
    if (user.providerData.isEmpty) return;
    final info = user.providerData.first;
    try {
      if ((user.displayName?.trim().isEmpty ?? true) &&
          (info.displayName?.trim().isNotEmpty ?? false)) {
        await user.updateDisplayName(info.displayName);
      }
      if ((user.photoURL?.trim().isEmpty ?? true) &&
          (info.photoURL?.trim().isNotEmpty ?? false)) {
        await user.updatePhotoURL(info.photoURL);
      }
    } catch (_) {
      // לא קריטי - _mapUser עושה fallback בכל מקרה גם בלי זה.
    }
  }

  /// מנסה "לשדרג" משתמש אורח קיים לחשבון אמיתי (linkWithCredential) כדי
  /// לשמר את ההתקדמות שכבר נצברה; אם הקרדנציאל כבר שייך לחשבון אחר,
  /// נופלים חזרה להתחברות רגילה (המשתמש יעבור לפרופיל הקיים שלו בענן).
  Future<fb.UserCredential> _linkOrSignIn(fb.AuthCredential credential) async {
    final current = _auth.currentUser;
    fb.UserCredential result;
    if (current != null && current.isAnonymous) {
      try {
        result = await current.linkWithCredential(credential);
        await _backfillProfileFromProvider(result.user!);
        return result;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        // ממשיכים להתחברות רגילה עם הקרדנציאל הקיים.
      }
    }
    result = await _auth.signInWithCredential(credential);
    await _backfillProfileFromProvider(result.user!);
    return result;
  }

  /// גרסת ה-Web של [_linkOrSignIn]: מנסה לקשר את משתמש/ת האורח/ת הנוכחי/ת
  /// ל-popup של הספק, ואם מתברר שהחשבון הזה (למשל אותו חשבון Google
  /// שהתחברתם איתו בעבר, לפני שהתנתקתם) כבר קיים כחשבון עצמאי - מתחברים
  /// ישירות אליו במקום להיכשל עם שגיאה. זה קורה בדיוק במקרה של: התחברתם
  /// עם Google, התנתקתם (מה שהופך אתכם לאורח/ת חדש/ה), ואז ניסיתם להתחבר
  /// שוב עם אותו חשבון Google - הקרדנציאל שהתקבל מה-popup הכושל מוחזר
  /// בתוך השגיאה עצמה (e.credential), כך שאין צורך לפתוח popup שני.
  Future<fb.UserCredential> _linkOrSignInWithPopup(fb.AuthProvider provider) async {
    final current = _auth.currentUser;
    fb.UserCredential result;
    if (current != null && current.isAnonymous) {
      try {
        result = await current.linkWithPopup(provider);
        await _backfillProfileFromProvider(result.user!);
        return result;
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        final credential = e.credential;
        if (credential != null) {
          result = await _auth.signInWithCredential(credential);
          await _backfillProfileFromProvider(result.user!);
          return result;
        }
        // גיבוי: אם הפעם הזו לא חוזרת קרדנציאל שמיש, פותחים popup נוסף.
        result = await _auth.signInWithPopup(provider);
        await _backfillProfileFromProvider(result.user!);
        return result;
      }
    }
    result = await _auth.signInWithPopup(provider);
    await _backfillProfileFromProvider(result.user!);
    return result;
  }

  @override
  Future<AuthUser> signInAsGuest() async {
    try {
      final result = await _auth.signInAnonymously();
      return _mapUser(result.user!, isNewUser: result.additionalUserInfo?.isNewUser ?? false);
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final userCred = await _linkOrSignInWithPopup(fb.GoogleAuthProvider());
        return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
      }

      if (!_googleInitialized) {
        await _googleSignIn.initialize();
        _googleInitialized = true;
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await _linkOrSignIn(credential);
      return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
    } on GoogleSignInException catch (e) {
      throw AuthException(
        e.code.name == 'canceled' ? 'ההתחברות בוטלה.' : 'ההתחברות עם Google נכשלה (${e.code.name}).',
      );
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> signInWithApple() async {
    try {
      if (kIsWeb) {
        final provider = fb.OAuthProvider('apple.com')
          ..addScope('email')
          ..addScope('name');
        final userCred = await _linkOrSignInWithPopup(provider);
        return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
      }

      if (!Platform.isIOS && !Platform.isMacOS) {
        throw const AuthException('התחברות עם Apple זמינה כרגע רק ב-iOS ובדפדפן.');
      }

      final rawNonce = _generateNonce();
      final nonce = _sha256(rawNonce);
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );
      final credential = fb.OAuthProvider('apple.com').credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
        accessToken: appleCredential.authorizationCode,
      );
      final userCred = await _linkOrSignIn(credential);
      return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
    } on SignInWithAppleAuthorizationException catch (e) {
      throw AuthException(
        e.code == AuthorizationErrorCode.canceled ? 'ההתחברות בוטלה.' : 'ההתחברות עם Apple נכשלה.',
      );
    } catch (e) {
      if (e is AuthException) rethrow;
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final credential = fb.EmailAuthProvider.credential(email: email, password: password);
      final userCred = await _linkOrSignIn(credential);
      await userCred.user!.updateDisplayName(displayName);
      return _mapUser(userCred.user!, isNewUser: userCred.additionalUserInfo?.isNewUser ?? false);
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb && _googleInitialized) {
        await _googleSignIn.signOut();
      }
    } catch (_) {
      // אם ה-SDK של ספק כלשהו לא הופעל, אין צורך להיכשל על היציאה.
    }
    await _auth.signOut();
  }

  @override
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    // Firebase דורש התחברות "טרייה" (כ-5 דקות) כדי למחוק משתמש. בודקים
    // מראש, כדי לא למחוק את הנתונים ואז להיכשל במחיקת החשבון עצמו.
    final lastSignIn = user.metadata.lastSignInTime;
    if (!user.isAnonymous &&
        (lastSignIn == null || DateTime.now().difference(lastSignIn) > const Duration(minutes: 4))) {
      throw const RecentLoginRequiredException();
    }

    try {
      await AccountDataEraser(FirebaseFirestore.instance).eraseUser(user.uid);
    } catch (e) {
      throw AuthException('מחיקת הנתונים נכשלה. בדקו את החיבור לאינטרנט ונסו שוב. ($e)');
    }

    try {
      await user.delete();
    } on fb.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // משתמש/ת אורח/ת: הנתונים כבר נמחקו, ונשאר רק מזהה אנונימי בלי
        // שום מידע אישי - מספיק להתנתק ממנו.
        if (!user.isAnonymous) throw const RecentLoginRequiredException();
      } else {
        throw _friendlyError(e);
      }
    }
    await signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
