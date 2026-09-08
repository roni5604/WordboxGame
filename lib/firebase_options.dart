// ⚠️ קובץ זה הוא Placeholder בלבד ואינו מכיל פרויקט Firebase אמיתי.
//
// כדי לחבר את המשחק ל-Firebase אמיתי (Auth, Firestore, Realtime Database,
// Hosting) יש להריץ את הפקודה הבאה מתוך תיקיית הפרויקט (דורשת חשבון
// Google וכניסה ל-Firebase CLI - לא ניתן לבצע זאת אוטומטית מתוך הסוכן):
//
//   dart pub global activate flutterfire_cli
//   flutterfire configure
//
// הפקודה תדרוס אוטומטית את הקובץ הזה עם ערכים אמיתיים, ותוסיף את קבצי
// ההגדרה הנדרשים לכל פלטפורמה (google-services.json / GoogleService-Info.plist).
// לפרטים מלאים ראו docs/FIREBASE_SETUP.md.
//
// עד אז, AppConfig.useFirebaseBackend נשאר false והמשחק פועל במלואו
// במצב מקומי (ללא רשת), כך שהקובץ הזה לא נטען בפועל.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) return web;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions הוא Placeholder - הריצו flutterfire configure.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'wordbox-il-placeholder',
    authDomain: 'wordbox-il-placeholder.firebaseapp.com',
    storageBucket: 'wordbox-il-placeholder.appspot.com',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'wordbox-il-placeholder',
    storageBucket: 'wordbox-il-placeholder.appspot.com',
  );

  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'REPLACE_ME',
    appId: 'REPLACE_ME',
    messagingSenderId: 'REPLACE_ME',
    projectId: 'wordbox-il-placeholder',
    storageBucket: 'wordbox-il-placeholder.appspot.com',
    iosBundleId: 'com.wordboxil.wordboxHebrew',
  );
}
