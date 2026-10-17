import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// מחזיר את ה-uid של המשתמש/ת המחובר/ת, ומתחבר כאורח/ת רק אם באמת אין
/// חיבור.
///
/// באתר (Web) `currentUser` הוא null ברגעים הראשונים, עד ש-Firebase משחזר
/// את החיבור השמור מהדפדפן. בדיקה מוקדמת מדי יצרה משתמש אורח חדש בכל טעינה
/// (וההתקדמות "נעלמה"), ובקשה מיד אחרי ההתחברות יכלה להגיע לשרת עם
/// ההרשאות של המשתמש הקודם. לכן:
///   1. מחכים לאירוע הראשון של authStateChanges (= החיבור השמור שוחזר).
///   2. רק אז, אם אין משתמש, מתחברים כאורח/ת - פעם אחת בלבד גם אם כמה
///      חלקים במשחק מבקשים במקביל.
class AuthSession {
  AuthSession._();

  static final Map<FirebaseAuth, Future<String>> _pending = {};

  static Future<String> ensureUid(FirebaseAuth auth) {
    final current = auth.currentUser;
    if (current != null) return Future.value(current.uid);
    // שימו לב: הקולבק לא מחזיר את ה-Future שהוסר - אחרת whenComplete היה
    // ממתין לעצמו ונתקע.
    return _pending[auth] ??= _resolve(auth).whenComplete(() {
      _pending.remove(auth);
    });
  }

  static Future<String> _resolve(FirebaseAuth auth) async {
    User? user = auth.currentUser;
    // רק באתר החיבור השמור משוחזר באיחור; באפליקציה currentUser מוכן מיד.
    if (user == null && kIsWeb) {
      try {
        user = await auth
            .authStateChanges()
            .first
            .timeout(const Duration(seconds: 3), onTimeout: () => auth.currentUser);
      } catch (_) {
        user = auth.currentUser;
      }
    }
    if (user != null) return user.uid;

    final credential = await auth.signInAnonymously();
    return credential.user!.uid;
  }
}
