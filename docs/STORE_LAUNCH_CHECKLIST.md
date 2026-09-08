# צ'ק-ליסט להשקה (App Store / Google Play / Web)

## לפני הגשה לחנויות

- [ ] להחליף אייקון האפליקציה (`assets/icon`, `flutter_launcher_icons` מומלץ להוספה)
- [ ] מסך פתיחה (Splash) native - `flutter_native_splash`
- [ ] להחליף את מילון המשחק ברשימה גדולה/מורשית יותר (ראו `docs/DICTIONARY_LICENSING.md`)
- [ ] להוסיף צלילי SFX/מוזיקת רקע אמיתיים (`audioplayers`/`just_audio`) -
      כרגע אין קבצי אודיו בפרויקט, רק haptics
- [ ] לבדוק נגישות (ניגודיות צבעים, גדלי טקסט) ותמיכה ב-Dynamic Type / Font Scale
- [ ] לבדוק על מכשירים אמיתיים בגדלי מסך שונים (iPhone SE עד iPad, מסכי Android קטנים/גדולים)
- [ ] לוודא RTL תקין בכל המסכים (כיווני אנימציה, אייקוני חזרה, יישור טקסט)

## iOS (App Store)

- [ ] Apple Developer Account פעיל
- [ ] הרצת `sudo xcode-select --switch /Applications/Xcode.app` + התקנת Xcode מלא
- [ ] הגדרת Bundle ID תואם (`com.wordboxil.wordboxHebrew`) ב-App Store Connect
- [ ] מסכי Privacy: App Tracking Transparency (אם יתווספו פרסומות/אנליטיקס)
- [ ] צילומי מסך בכל הגדלים הנדרשים + תיאור בעברית

## Android (Google Play)

- [ ] התקנת Android `cmdline-tools` (`sdkmanager --install "cmdline-tools;latest"`)
- [ ] יצירת Keystore חתימה + הגדרתו ב-`android/key.properties`
- [ ] מילוי Data Safety Form ב-Play Console
- [ ] בדיקת Target API Level עדכני (ל-2026: Android 15/API 35 ומעלה)

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
