# התראות Push מהשרת (Firebase Cloud Messaging)

התראות שמגיעות **גם כשהאפליקציה סגורה לגמרי**:

| אירוע | מתי | לאן הלחיצה מובילה |
|---|---|---|
| 🎮 הזמנה למשחק | נוצר מסמך ב-`invites` (בתוקף לדקה, ה-push פג אחרי דקה) | `/home` (חלון ההזמנה) |
| 💌 בקשת חברות | נוצר מסמך ב-`friendRequests` | `/friends?tab=1` |
| 🏆 חבר/ה עקף/ה אותך באתגר היומי | הניקוד היומי של חבר/ה עלה מעל שלך היום | `/daily` |

עד שהפונקציות נפרסות, הכול ממשיך לעבוד כמו בגרסה 1.1.0: תזכורות מקומיות,
והתראות על הזמנות/בקשות כל עוד האפליקציה (או הלשונית) חיה ברקע.

## איך זה בנוי

```
אפליקציה                                  שרת (functions/, Node 22, europe-west1)
─────────                                  ──────────────────────────────────────
push_service.dart                          onInviteCreated        invites/{id}
  הרשאה (אותה בקשה כמו התזכורות)            onFriendRequestCreated friendRequests/{id}
  → players/{uid}/devices/{token}  ──────▶  onDailyScoreRaised     publicProfiles/{uid}
  מתג "התראות" כבוי / התנתקות               onDeviceRegistered     players/{uid}/devices/{token}
  → מוחקים את הרישום                         ↓
                                           sendEachForMulticast → כל המכשירים של הנמען/ת
                                           טוקן מת → נמחק מ-devices
```

- **בלי כפילויות**: ה-push וההתראה המקומית של אותו אירוע מקבלים אותו מזהה
  (`SocialNotificationKey` ב-Dart, `keys.ts` בשרת, עם בדיקות זהות בשני הצדדים),
  ולכן מערכת ההפעלה מחליפה אחת בשנייה.
- **בחזית**: הזמנות ובקשות חברות מוצגות בחלון בתוך המשחק (כמו היום), אז ה-push
  שלהן לא מוצג. "חבר/ה עקף/ה אותך" מוצג כהתראה רגילה בערוץ `social`.
- **אתר**: `web/firebase-messaging-sw.js` מציג את ההתראות כשהלשונית סגורה.
  `firebase-messaging.js` נטען רק כשיש מפתח VAPID, כדי שחוסם פרסומות לא יתקע
  את טעינת Firebase (כמו Analytics).
- **פרטיות**: מחיקת חשבון מוחקת גם את `players/{uid}/devices`, והתנתקות מוחקת את
  רישום המכשיר ומבטלת את הטוקן.

## הפעלה - צעדים בקונסולה (פעם אחת)

> שום דבר כאן עוד לא נפרס. כל צעד הוא החלטה שלך.

### 1. מעבר לתוכנית Blaze (חובה לפונקציות)

Firebase Console → ⚙️ → **Usage and billing** → **Modify plan** → Blaze.
מומלץ להגדיר מיד **Budget alert** (למשל $5) ב-Google Cloud Billing.

עלות צפויה: FCM חינם. בפונקציות יש מכסה חינמית של 2 מיליון הפעלות בחודש.
`onDailyScoreRaised` רץ על **כל** עדכון של הכרטיס הציבורי, כולל דופק הנוכחות
(פעם בדקה לכל שחקן/ית מחובר/ת). הוא יוצא מיד בלי לקרוא כלום מ-Firestore כשהניקוד
לא עלה. בפועל: בערך הפעלה אחת לכל דקת משחק, כלומר המכסה החינמית מכסה בערך 46
שחקנים מחוברים 24/7. אם רוצים לוותר על ההתראה הזאת, פורסים בלעדיה (ראו צעד 5).
בפריסה הראשונה ה-CLI ישאל על מדיניות ניקוי ל-Artifact Registry. כדאי לאשר
(למשל יום אחד), כדי שתמונות ישנות של הפונקציות לא יצברו עלות אחסון.

### 2. iOS - מפתח APNs

1. [Apple Developer → Keys](https://developer.apple.com/account/resources/authkeys/list) → **+** →
   מסמנים **Apple Push Notifications service (APNs)** → מורידים את קובץ ה-`.p8`
   (אפשר להוריד רק פעם אחת) ורושמים את ה-**Key ID** ואת ה-**Team ID**.
2. Firebase Console → ⚙️ Project settings → **Cloud Messaging** → Apple app
   configuration (`com.wordboxil.wordboxHebrew`) → **APNs Authentication Key** →
   Upload (אותו מפתח משמש גם לפיתוח וגם ל-production).
3. ב-Apple Developer → Identifiers → `com.wordboxil.wordboxHebrew` לוודא ש-**Push
   Notifications** מסומן. ב-Xcode עם Automatic signing זה קורה לבד, כי
   `Runner.entitlements` כבר כולל `aps-environment`. Xcode מחליף אותו
   ל-production בייצוא ל-App Store.

בלי המפתח, השליחה ל-iOS נכשלת עם `messaging/third-party-auth-error`. השרת
**לא** מוחק טוקנים במקרה כזה, אז אחרי ההעלאה הכול מתחיל לעבוד בלי לפתוח מחדש.

### 3. אתר - מפתח VAPID

Firebase Console → ⚙️ Project settings → **Cloud Messaging** → **Web Push
certificates** → **Generate key pair** → מעתיקים את המפתח הציבורי ובונים:

```bash
flutter build web --release --dart-define=WEB_PUSH_VAPID_KEY=<המפתח>
```

(המפתח ציבורי, לא סוד.) בלי המפתח, האתר ממשיך כמו היום ולא נרשם ל-push.
בבנייה עם המפתח צריך להעביר אותו בכל `flutter build web`.

### 4. Android

אין צעדים. FCM עובד דרך `google-services.json` הקיים, וההרשאה (Android 13+)
כבר מתבקשת בזרימה הקיימת.

### 5. פריסה

```bash
npm --prefix functions ci
```

```bash
firebase deploy --only firestore:rules,firestore:indexes,functions --project wordbox-64b19
```

- החוקים (`players/{uid}/devices`) והאינדקס (`devices.token` ברמת collection
  group, בשביל `onDeviceRegistered`) נפרסים יחד עם הפונקציות. חוקים ואינדקסים
  עובדים גם בתוכנית Spark.
- בלי ההתראה של האתגר היומי:
  `--only functions:onInviteCreated,functions:onFriendRequestCreated,functions:onDeviceRegistered`.
- כתובת האתר ללחיצה על התראה בדפדפן נמצאת ב-`functions/.env` (`WEB_APP_URL`).
  כשיהיה דומיין משלך, מעדכנים שם.
- שימו לב: מעכשיו `firebase deploy` בלי `--only` פורס גם את הפונקציות.

### 6. בדיקה

1. מתקינים גרסה חדשה של האפליקציה, נכנסים לחשבון ומאשרים התראות.
   ב-Firestore אמור להופיע `players/<uid>/devices/<token>`.
2. סוגרים את האפליקציה לגמרי, ומחשבון אחר שולחים בקשת חברות.
3. לוגים: `firebase functions:log --project wordbox-64b19`. כל שליחה נרשמת כ-`push`
   עם `sent` / `failed` / `removed` ו-`errors` (קודי השגיאה של FCM).

## בדיקות

```bash
cd functions && npm ci && npm test
```

```bash
cd firestore-tests && npm ci && npx firebase emulators:exec --only firestore --project demo-wordbox "npm test"
```

```bash
flutter test test/core/notifications test/data
```

הרצה מקומית של הפונקציות מול האמולטור דורשת firebase-tools 14 ומעלה
(firebase-functions 7). הגרסה שב-`firestore-tests` (13) מספיקה לחוקים בלבד.
