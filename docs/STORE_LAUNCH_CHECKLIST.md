# צ'ק-ליסט להשקה (App Store / Google Play / Web)

## לפני הגשה לחנויות

- [ ] להחליף אייקון האפליקציה (`assets/icon`, `flutter_launcher_icons` מומלץ להוספה)
- [ ] מסך פתיחה (Splash) native - `flutter_native_splash`
- [ ] להחליף את מילון המשחק ברשימה גדולה/מורשית יותר (ראו `docs/DICTIONARY_LICENSING.md`)
- [x] צלילי SFX למשחק (`audioplayers`) - נוצרו פרוצדורלית (ראו
      `tool/generate_sfx.py`), מכובים אוטומטית לפי הגדרת "צלילים" בפרופיל.
      עדיין אין מוזיקת רקע (loop) - ניתן להוסיף בהמשך אם רוצים.
- [ ] לבדוק נגישות (ניגודיות צבעים, גדלי טקסט) ותמיכה ב-Dynamic Type / Font Scale
- [ ] לבדוק על מכשירים אמיתיים בגדלי מסך שונים (iPhone SE עד iPad, מסכי Android קטנים/גדולים)
- [ ] לוודא RTL תקין בכל המסכים (כיווני אנימציה, אייקוני חזרה, יישור טקסט)

## iOS (App Store)

- [ ] Apple Developer Account פעיל
- [ ] הרצת `sudo xcode-select --switch /Applications/Xcode.app` + התקנת Xcode מלא
- [ ] הגדרת Bundle ID תואם (`com.wordboxil.wordboxHebrew`) ב-App Store Connect
- [x] מסכי Privacy: App Tracking Transparency (הטקסט ב-`ios/Runner/Info.plist`) + טופס הסכמה של Google (UMP) לפני בקשת פרסומות
- [ ] צילומי מסך בכל הגדלים הנדרשים + תיאור בעברית
- [ ] להחליף את מזהה אפליקציית AdMob לבדיקה ב-`Info.plist` (`GADApplicationIdentifier`) במזהה האמיתי

## Android (Google Play)

- [ ] התקנת Android `cmdline-tools` (`sdkmanager --install "cmdline-tools;latest"`)
- [ ] יצירת Keystore חתימה + הגדרתו ב-`android/key.properties`
- [ ] מילוי Data Safety Form ב-Play Console (כולל מזהה פרסום ושותף Google AdMob)
- [ ] בדיקת Target API Level עדכני (ל-2026: Android 15/API 35 ומעלה)
- [ ] להחליף את מזהה אפליקציית AdMob לבדיקה ב-`android/app/src/main/AndroidManifest.xml` במזהה האמיתי

## פרסומות (AdMob)

הקוד רץ על מזהי בדיקה של Google כל עוד לא הועברו מזהי יחידות אמיתיים.
בבילד **release** בלי המזהים האלה הפרסומות כבויות, כדי לא להגיש לחנות
פרסומות בדיקה (זה חוסם חשבון AdMob).

לפני ההעלאה יוצרים ב-AdMob אפליקציית Android ואפליקציית iOS, ושלוש יחידות:
Rewarded, Interstitial, Native. מחליפים את מזהה האפליקציה בקבצי ה-native
שלמעלה, ובונים עם:

```bash
flutter build appbundle --release \
  --dart-define=ADMOB_REWARDED_ANDROID=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_INTERSTITIAL_ANDROID=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_NATIVE_ANDROID=ca-app-pub-XXXX/YYYY

flutter build ipa --release \
  --dart-define=ADMOB_REWARDED_IOS=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_INTERSTITIAL_IOS=ca-app-pub-XXXX/YYYY \
  --dart-define=ADMOB_NATIVE_IOS=ca-app-pub-XXXX/YYYY
```

באתר אין AdMob. הפרסומות שם הן Ad Placement API של AdSense
(מתנה ומסך מלא). בפיתוח מוצגת מודעת בדיקה של Google. בבילד release
בלי מזהה מפרסם הפרסומות באתר כבויות.

```bash
flutter build web --release \
  --dart-define=ADSENSE_CLIENT=ca-pub-XXXXXXXXXXXXXXXX
```

## Web (Firebase Hosting / כל אחסון סטטי אחר)

- [ ] `flutter build web --release --pwa-strategy=offline-first`
- [ ] בדיקת Lighthouse (ביצועים, נגישות, PWA)
- [ ] הגדרת דומיין מותאם אישית + HTTPS
- [ ] מדיניות פרטיות ותנאי שימוש זמינים בקישור מהאתר (ראו `docs/PRIVACY_POLICY_DRAFT.md`)

## Backend

- [ ] הגדרת פרויקט Firebase אמיתי (ראו `docs/FIREBASE_SETUP.md`)
- [ ] פריסת חוקי אבטחה ל-Firestore/Realtime Database
- [ ] Cloud Functions לוולידציית מילים בצד שרת (רב-משתתפים)
- [ ] ניטור/Crashlytics + Analytics מופעלים
