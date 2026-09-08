# הפעלת Firebase (סנכרון + לידרבורד + רב-משתתפים)

המשחק היחיד-שחקן **עובד באופן מלא ללא Firebase** - כל ההתקדמות נשמרת
מקומית (Hive). הקוד ל-Firebase כבר קיים בפרויקט אבל כבוי כברירת מחדל,
כי הוא דורש חשבון Google/Firebase אישי שהסוכן האוטומטי לא יכול ליצור
בשמכם.

## שלב 1: יצירת פרויקט Firebase

1. היכנסו ל-<https://console.firebase.google.com> וצרו פרויקט חדש
   (למשל `wordbox-il`).
2. הפעילו את השירותים הבאים בקונסולה:
   - **Authentication** → הפעילו את ספק "Anonymous" (וגם Google/Apple אם רוצים).
   - **Firestore Database** → צרו מסד נתונים במצב Production.
   - **Realtime Database** (רק אם ממשיכים למצב רב-משתתפים).
   - **Hosting** (עבור גרסת האתר).

## שלב 2: חיבור הפרויקט המקומי

```bash
dart pub global activate flutterfire_cli
firebase login          # התחברות עם חשבון Google
flutterfire configure   # יבחר את הפרויקט וייצור/ידרוס את lib/firebase_options.dart
```

הפקודה תיצור אוטומטית גם את `android/app/google-services.json` ו-
`ios/Runner/GoogleService-Info.plist`.

## שלב 3: הפעלת האינטגרציה בקוד

ב-[`lib/core/config/app_config.dart`](../lib/core/config/app_config.dart)
שנו את ברירת המחדל, או הריצו עם:

```bash
flutter run --dart-define=USE_FIREBASE=true
```

ה-provider ב-[`lib/providers/repository_providers.dart`](../lib/providers/repository_providers.dart)
כבר בודק את הדגל הזה אוטומטית ועובר בין `LocalProgressRepository` ל-
`FirebaseProgressRepository` - אין צורך לשנות קוד נוסף.

## שלב 4: כללי אבטחה מומלצים ל-Firestore

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /players/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
    match /rooms/{roomCode} {
      allow read: if request.auth != null;
      allow write: if false; // רק Cloud Functions כותבות לסטטוס החדר
      match /players/{uid} {
        allow read: if request.auth != null;
        allow create, update: if request.auth != null && request.auth.uid == uid;
      }
    }
  }
}
```

## שלב 5: פריסת האתר (Firebase Hosting)

```bash
flutter build web --release
firebase deploy --only hosting
```

## מצב רב-משתתפים (שלב 2)

הקוד ב-`lib/features/multiplayer/services/firestore_multiplayer_repository.dart`
הוא שלד עובד, אבל **לא בטוח ל-production כמות שהוא**: ולידציית מילים
וניהול תורות חייבים לעבור ל-Cloud Functions כדי שלקוח לא יוכל לרמות.
ראו את הערות ה-TODO בקובץ עצמו וב"נושאים פתוחים" בתוכנית המקורית.
