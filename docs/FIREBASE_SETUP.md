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

## שלב 6: הפעלת התחברות עם Google / Apple / Facebook / מייל

הקוד לכל שיטות ההתחברות כבר קיים ומוכן ב-
[`lib/data/repositories/firebase_auth_repository.dart`](../lib/data/repositories/firebase_auth_repository.dart)
ובמסך [`lib/features/auth/auth_screen.dart`](../lib/features/auth/auth_screen.dart)
(נגיש מהפרופיל). כל עוד `AppConfig.useFirebaseBackend == false`, לחיצה על
כל כפתור מלבד "אורח" תציג הודעה ידידותית שההתחברות דורשת הפעלת Firebase -
זה לא באג, זו התנהגות מכוונת. לאחר שלב 1-3 למעלה, השלימו גם את הצעדים
הבאים כדי שכל ספק יעבוד בפועל:

### Google
1. בקונסולת Firebase → Authentication → Sign-in method → הפעילו **Google**.
2. בווב זה מספיק (המשחק משתמש ב-`signInWithPopup`, בלי הגדרה נוספת בקוד).
3. באנדרואיד/iOS יש להוסיף SHA-1/SHA-256 (אנדרואיד) ולהריץ שוב
   `flutterfire configure` כדי שה-Client ID הנכון ייכנס אוטומטית לפרויקט.

### Apple (זמין ב-iOS/macOS/Web)
1. בחשבון Apple Developer: הוסיפו את היכולת **"Sign In with Apple"** ל-App ID.
2. בקונסולת Firebase → Authentication → Sign-in method → הפעילו **Apple**.
3. עבור Web: ייצרו **Services ID** בפורטל Apple Developer עם ה-Redirect URI
   שמופיע בקונסולת Firebase, והזינו אותו שם.

### Facebook
1. צרו אפליקציה ב-<https://developers.facebook.com> והפעילו בה **Facebook Login**.
2. בקונסולת Firebase → Authentication → Sign-in method → הפעילו **Facebook**
   והזינו את ה-App ID וה-App Secret.
3. באנדרואיד: הוסיפו `facebook_app_id` ו-`facebook_client_token` ל-
   `android/app/src/main/res/values/strings.xml` וב-`AndroidManifest.xml`
   (לפי הוראות חבילת `flutter_facebook_auth`).
4. ב-iOS: הוסיפו את אותם מפתחות ל-`Info.plist` (`FacebookAppID`,
   `FacebookClientToken`, `FacebookDisplayName`, וסכימת URL תואמת).

### מייל וסיסמה
בקונסולת Firebase → Authentication → Sign-in method → הפעילו **Email/Password**.
זה עובד מיד בכל הפלטפורמות ללא הגדרה נוספת.

> שימו לב: אם שחקן/ית כבר שיחקו כאורח/ת ואז מתחברים עם חשבון אמיתי, הקוד
> מנסה קודם "לשדרג" (link) את המשתמש האנונימי לחשבון האמיתי כדי לשמר את
> ההתקדמות שכבר נצברה - וזה עובד אוטומטית, בלי צורך בקוד נוסף.

## מצב רב-משתתפים (שלב 2)

הקוד ב-`lib/features/multiplayer/services/firestore_multiplayer_repository.dart`
הוא שלד עובד, אבל **לא בטוח ל-production כמות שהוא**: ולידציית מילים
וניהול תורות חייבים לעבור ל-Cloud Functions כדי שלקוח לא יוכל לרמות.
ראו את הערות ה-TODO בקובץ עצמו וב"נושאים פתוחים" בתוכנית המקורית.
