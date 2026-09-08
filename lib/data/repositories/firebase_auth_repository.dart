import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'dart:convert';
import 'dart:math';

import '../models/auth_user.dart';
import 'auth_repository.dart';

/// מימוש אמיתי מבוסס Firebase Authentication - פעיל רק אחרי
/// `flutterfire configure` + הפעלת AppConfig.useFirebaseBackend
/// (ראו docs/FIREBASE_SETUP.md, כולל הוראות הפעלת כל ספק).
///
/// גישה: בדפדפן (Web) נעשה שימוש ב-`signInWithPopup` ישירות מול
/// Firebase (עובד לכל אחד מהספקים בלי SDK ילידי נוסף - רק צריך להפעיל
/// את הספק בקונסולת Firebase). בנייד/דסקטופ נעשה שימוש ב-SDK הילידי
/// המתאים (google_sign_in / sign_in_with_apple / flutter_facebook_auth)
/// וממירים את הפלט שלו לאישור (credential) של Firebase.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  bool _googleInitialized = false;

  FirebaseAuthRepository({fb.FirebaseAuth? auth}) : _auth = auth ?? fb.FirebaseAuth.instance;

  AuthUser _mapUser(fb.User user) {
    AuthProviderType provider = AuthProviderType.guest;
    if (!user.isAnonymous) {
      final providerId = user.providerData.isNotEmpty ? user.providerData.first.providerId : '';
      provider = switch (providerId) {
        'google.com' => AuthProviderType.google,
        'apple.com' => AuthProviderType.apple,
        'facebook.com' => AuthProviderType.facebook,
        'password' => AuthProviderType.email,
        _ => AuthProviderType.email,
      };
    }
    return AuthUser(
      uid: user.uid,
      displayName: user.displayName,
      email: user.email,
      photoUrl: user.photoURL,
      isAnonymous: user.isAnonymous,
      provider: provider,
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

  /// מנסה "לשדרג" משתמש אורח קיים לחשבון אמיתי (linkWithCredential) כדי
  /// לשמר את ההתקדמות שכבר נצברה; אם הקרדנציאל כבר שייך לחשבון אחר,
  /// נופלים חזרה להתחברות רגילה (המשתמש יעבור לפרופיל הקיים שלו בענן).
  Future<fb.UserCredential> _linkOrSignIn(fb.AuthCredential credential) async {
    final current = _auth.currentUser;
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithCredential(credential);
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        // ממשיכים להתחברות רגילה עם הקרדנציאל הקיים.
      }
    }
    return _auth.signInWithCredential(credential);
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
    if (current != null && current.isAnonymous) {
      try {
        return await current.linkWithPopup(provider);
      } on fb.FirebaseAuthException catch (e) {
        if (e.code != 'credential-already-in-use' && e.code != 'email-already-in-use') rethrow;
        final credential = e.credential;
        if (credential != null) {
          return await _auth.signInWithCredential(credential);
        }
        // גיבוי: אם הפעם הזו לא חוזרת קרדנציאל שמיש, פותחים popup נוסף.
        return await _auth.signInWithPopup(provider);
      }
    }
    return _auth.signInWithPopup(provider);
  }

  @override
  Future<AuthUser> signInAsGuest() async {
    try {
      final result = await _auth.signInAnonymously();
      return _mapUser(result.user!);
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final userCred = await _linkOrSignInWithPopup(fb.GoogleAuthProvider());
        return _mapUser(userCred.user!);
      }

      if (!_googleInitialized) {
        await _googleSignIn.initialize();
        _googleInitialized = true;
      }
      final account = await _googleSignIn.authenticate();
      final idToken = account.authentication.idToken;
      final credential = fb.GoogleAuthProvider.credential(idToken: idToken);
      final userCred = await _linkOrSignIn(credential);
      return _mapUser(userCred.user!);
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
        return _mapUser(userCred.user!);
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
      return _mapUser(userCred.user!);
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
  Future<AuthUser> signInWithFacebook() async {
    try {
      if (kIsWeb) {
        final userCred = await _linkOrSignInWithPopup(fb.FacebookAuthProvider());
        return _mapUser(userCred.user!);
      }

      final result = await FacebookAuth.instance.login(permissions: ['email', 'public_profile']);
      if (result.status != LoginStatus.success) {
        throw const AuthException('ההתחברות עם Facebook בוטלה או נכשלה.');
      }
      final token = result.accessToken!.tokenString;
      final credential = fb.FacebookAuthProvider.credential(token);
      final userCred = await _linkOrSignIn(credential);
      return _mapUser(userCred.user!);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw _friendlyError(e);
    }
  }

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) async {
    try {
      final userCred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      return _mapUser(userCred.user!);
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
      return _mapUser(userCred.user!);
    } catch (e) {
      throw _friendlyError(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        if (_googleInitialized) {
          await _googleSignIn.signOut();
        }
        await FacebookAuth.instance.logOut();
      }
    } catch (_) {
      // אם ה-SDK של ספק כלשהו לא הופעל, אין צורך להיכשל על היציאה.
    }
    await _auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  String _sha256(String input) => sha256.convert(utf8.encode(input)).toString();
}
