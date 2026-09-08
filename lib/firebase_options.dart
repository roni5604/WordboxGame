// קובץ זה נוצר אוטומטית ע"י `flutterfire configure` ומכיל את הגדרות
// פרויקט ה-Firebase האמיתי של המשחק (wordbox-64b19). המפתחות כאן (apiKey
// וכו') אינם סודיים - זוהי דרך העבודה הרגילה/מתועדת של Firebase; ההגנה
// האמיתית היא בכללי האבטחה של Firestore/Auth בקונסולה, לא בהסתרת הקובץ.
//
// כדי לעדכן/לרענן את ההגדרות בעתיד (למשל אחרי הוספת אפליקציה חדשה):
//   flutterfire configure --project=wordbox-64b19
//
// ה-Backend מופעל בפועל רק כש-AppConfig.useFirebaseBackend == true - ראו
// docs/FIREBASE_SETUP.md לפרטי הפעלת ספקי ההתחברות ו-Firestore בקונסולה.

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
    apiKey: 'AIzaSyCZ8qZ4JgWY-54zRo7iYyiiDhzyLt9QWk8',
    appId: '1:856063251417:web:8c744bd4324a4a68697fc8',
    messagingSenderId: '856063251417',
    projectId: 'wordbox-64b19',
    authDomain: 'wordbox-64b19.firebaseapp.com',
    storageBucket: 'wordbox-64b19.firebasestorage.app',
    measurementId: 'G-8VZF3JSVD6',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAtJePOWx0Xv3-lplC0bKh4L-ofTqTpPNo',
    appId: '1:856063251417:android:c7b6bc5afce965ce697fc8',
    messagingSenderId: '856063251417',
    projectId: 'wordbox-64b19',
    storageBucket: 'wordbox-64b19.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyD_wIuVNT3yUVUj5ycZs1zi3sD2pHbPg0E',
    appId: '1:856063251417:ios:76307dca59da7098697fc8',
    messagingSenderId: '856063251417',
    projectId: 'wordbox-64b19',
    storageBucket: 'wordbox-64b19.firebasestorage.app',
    iosBundleId: 'com.wordboxil.wordboxHebrew',
  );
}
