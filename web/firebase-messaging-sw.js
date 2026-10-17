// Service worker של Firebase Cloud Messaging: מציג push (הזמנה למשחק, בקשת
// חברות, חבר/ה שעקף/ה אותך באתגר היומי) כשהלשונית סגורה או ברקע.
//
// ההודעות נשלחות מ-functions/ עם notification + webpush.fcmOptions.link,
// אז ה-SDK מציג אותן בעצמו ופותח את המסך הנכון בלחיצה - אין צורך
// ב-onBackgroundMessage (זה היה מציג כל התראה פעמיים).
//
// הגרסה זהה ל-Firebase JS SDK שהאפליקציה טוענת (firebase_core_web 2.24.1 →
// 11.9.1). ההגדרות זהות ל-DefaultFirebaseOptions.web ב-lib/firebase_options.dart
// (הן ציבוריות - ההגנה היא בחוקי Firestore).
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/11.9.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyCZ8qZ4JgWY-54zRo7iYyiiDhzyLt9QWk8',
  appId: '1:856063251417:web:8c744bd4324a4a68697fc8',
  messagingSenderId: '856063251417',
  projectId: 'wordbox-64b19',
  authDomain: 'wordbox-64b19.firebaseapp.com',
  storageBucket: 'wordbox-64b19.firebasestorage.app',
});

firebase.messaging();
