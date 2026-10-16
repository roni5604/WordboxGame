# מדריך השקה: App Store, Google Play ואתר

המסמך מסודר לפי סדר העבודה. כל מה שאפשר היה לעשות בקוד כבר נעשה (ראו
"מה כבר מוכן בקוד" בסוף). מה שנשאר דורש חשבונות, תשלום או לחיצות
בקונסולות - דברים שרק בעל/ת החשבון יכול/ה לעשות.

---

## שלב 0: חשבונות (פעם אחת)

| חשבון | עלות | הערות |
|---|---|---|
| [Google Play Console](https://play.google.com/console/signup) | 25$ חד-פעמי | חשבון **אישי** חדש חייב **בדיקה סגורה עם 12 בודקים במשך 14 יום** לפני שמותר לפרסם לכולם. כדאי להתחיל מוקדם. |
| [Apple Developer Program](https://developer.apple.com/programs/enroll/) | 99$ לשנה | צריך Mac עם Xcode מלא לבנייה ולהעלאה (או שירות ענן כמו Codemagic). |
| [AdMob](https://admob.google.com) | חינם | לאותו חשבון Google של Firebase. |
| [AdSense](https://adsense.google.com) | חינם | רק לפרסומות באתר. דורש דומיין משלכם (לא תת-תיקייה ב-github.io). |

---

## שלב 1: Firebase

1. **פריסת חוקי האבטחה** (בלי זה המשחק מול חברים ומחיקת החשבון לא יעבדו נכון):
   ```bash
   npm i -g firebase-tools && firebase login
   firebase deploy --only firestore:rules
   ```
2. **Authentication → Sign-in method**: להפעיל Anonymous, Email/Password, Apple.
3. **Apple**: ב-Apple Developer → Identifiers → `com.wordboxil.wordboxHebrew` → לסמן
   **Sign In with Apple**. (קובץ ה-entitlement כבר בפרויקט.)
4. **Google (לא חובה)**: להפעיל את Google ב-Firebase, להוסיף ב-Project settings →
   Android app את טביעות **SHA-1 ו-SHA-256** של מפתח ההעלאה **וגם** של מפתח
   Play App Signing (Play Console → Setup → App signing), להוריד מחדש את
   `android/app/google-services.json` ואת `ios/Runner/GoogleService-Info.plist`,
   להעתיק את `REVERSED_CLIENT_ID` ל-`AppSecrets.xcconfig`, ולבנות עם
   `"GOOGLE_LOGIN_NATIVE": "true"`. עד אז הכפתור מוסתר באפליקציה (באתר הוא עובד).
5. **Facebook (לא חובה)**: אפליקציה ב-developers.facebook.com עם Facebook Login,
   להפעיל ב-Firebase, למלא את המזהים ב-`android/key.properties` וב-
   `ios/Flutter/AppSecrets.xcconfig`, ולבנות עם `"FACEBOOK_LOGIN_NATIVE": "true"`.
   ההמלצה: להשיק בלי, ולהוסיף בגרסה הבאה.

---

## שלב 2: פרסומות (AdMob)

1. AdMob → Apps → **Add app** פעמיים: Android ו-iOS (עדיין לא בחנות = "No").
2. בכל אפליקציה ליצור 3 יחידות: **Rewarded**, **Interstitial**, **Native advanced**.
3. למלא את המזהים:
   - מזהה **האפליקציה** (עם `~`): ב-`android/key.properties` (`ADMOB_APP_ID_ANDROID`)
     וב-`ios/Flutter/AppSecrets.xcconfig` (`ADMOB_APP_ID_IOS`).
   - מזהי **היחידות** (עם `/`): ב-`config/release.json` (העתק של
     `config/release.example.json`).
4. **Privacy & messaging** ב-AdMob: ליצור ולפרסם הודעת **GDPR** והודעת
   **IDFA explainer** (ל-iOS). בלי הודעה מפורסמת טופס ההסכמה לא יופיע,
   ובאירופה לא יוצגו פרסומות.
5. **app-ads.txt**: AdMob ייתן שורה כמו
   `google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0`. היא צריכה לשבת
   בשורש הדומיין של "אתר המפתח" שמופיע בדף החנות, למשל
   `https://ronimichaeli.com/app-ads.txt`.
6. לקשר את AdMob ל-Firebase (AdMob → App settings → Link to Firebase) כדי
   שהכנסות פרסום יופיעו ב-Analytics.

> בבילד release בלי מזהי יחידות הפרסומות כבויות לגמרי - בכוונה, כדי לא
> להעלות לחנות פרסומות בדיקה (זה חוסם חשבון AdMob).

---

## שלב 3: תשלומים (רכישות בתוך האפליקציה)

המשחק מוכר 6 חבילות **Consumable** (נצרכות). המזהים חייבים להיות זהים בדיוק:

| מזהה מוצר | תוכן | מחיר מוצע |
|---|---|---|
| `wordbox_coins_200` | 200 מטבעות | 0.99$ (₪3.90) |
| `wordbox_coins_600` | 600 מטבעות | 1.99$ (₪7.90) |
| `wordbox_coins_1500` | 1500 מטבעות | 3.99$ (₪14.90) |
| `wordbox_hints_5` | 5 רמזים | 0.99$ |
| `wordbox_hints_15` | 15 רמזים | 1.99$ |
| `wordbox_hints_40` | 40 רמזים | 3.99$ |

**Google Play**
1. Play Console → Setup → **Payments profile** (פרטי בנק ומס).
2. קודם להעלות AAB אחד לבדיקה פנימית (Play לא מאפשר ליצור מוצרים לפני כן).
3. Monetize → Products → **In-app products** → ליצור את 6 המוצרים ולהפעיל (Active).
4. Setup → **License testing**: להוסיף את המייל שלכם כדי לקנות בלי חיוב אמיתי.

**App Store**
1. App Store Connect → Business → לחתום על **Paid Apps Agreement** ולמלא בנק ומס.
2. האפליקציה → Monetization → **In-App Purchases** → 6 מוצרים מסוג *Consumable*,
   עם שם ותיאור בעברית וצילום מסך של החנות במשחק (Apple דורשת לבדיקה).
3. לבדוק עם משתמש **Sandbox** (Users and Access → Sandbox).
4. בהגשה הראשונה לסמן את 6 המוצרים יחד עם גרסת האפליקציה.

הקוד כבר מטפל ב: הצגת מחיר מקומי מהחנות, זיכוי מטבעות/רמזים, השלמת
הרכישה מול החנות, מניעת זיכוי כפול, ורכישה ממתינה. באתר הרכישה לא זמינה
(מוצגת הודעה שהיא באפליקציה).

---

## שלב 4: בנייה

### אנדרואיד
1. ליצור מפתח העלאה (פעם אחת, **לגבות את הקובץ והסיסמאות!**):
   ```bash
   keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA \
           -keysize 2048 -validity 10000 -alias upload
   ```
2. `cp android/key.properties.example android/key.properties` ולמלא.
3. `cp config/release.example.json config/release.json` ולמלא.
4. לבנות:
   ```bash
   flutter build appbundle --release --dart-define-from-file=config/release.json
   ```
   הקובץ: `build/app/outputs/bundle/release/app-release.aab`.

### iOS (על Mac)
1. `cp ios/Flutter/AppSecrets.example.xcconfig ios/Flutter/AppSecrets.xcconfig` ולמלא.
2. `open ios/Runner.xcworkspace` → Runner → Signing & Capabilities → לבחור Team.
3. לבנות ולהעלות:
   ```bash
   flutter build ipa --release --dart-define-from-file=config/release.json
   ```
   ואז לפתוח את `build/ios/archive/Runner.xcarchive` ב-Xcode → Distribute App,
   או להשתמש ב-Transporter.

### לפני כל העלאה
להעלות את `version` ב-`pubspec.yaml` (למשל `1.0.1+2`). המספר אחרי `+` חייב
לעלות בכל העלאה.

---

## שלב 5: דפי החנות

**קישורים לחנות** (חיים אחרי מיזוג ל-main, דרך GitHub Pages):
- מדיניות פרטיות: `https://roni5604.github.io/WordboxGame/privacy.html`
- מחיקת חשבון: `https://roni5604.github.io/WordboxGame/delete-account.html`
- תנאי שימוש: `https://roni5604.github.io/WordboxGame/terms.html`

**Google Play Console**
- [ ] Store listing: שם, תיאור קצר (80 תווים), תיאור מלא, אייקון 512×512,
      Feature graphic 1024×500, לפחות 2 צילומי מסך של טלפון.
- [ ] App content: Privacy policy, **Ads: Yes**, **Data safety** (ראו למטה),
      **Content rating** (שאלון IARC), **Target audience: 13+**, App access
      (אין צורך בהתחברות - אפשר לשחק כאורח), **Account deletion URL**.
- [ ] בדיקה סגורה: 12 בודקים, 14 יום, ואז Apply for production.

**App Store Connect**
- [ ] צילומי מסך iPhone 6.9" (1320×2868) או 6.5" (1284×2778).
- [ ] תיאור, מילות מפתח, Support URL, Privacy Policy URL.
- [ ] **App Privacy** (ראו למטה), Age rating (שאלון), Category: Games → Word.
- [ ] Review notes: "אפשר לשחק כאורח. מחיקת חשבון: הגדרות ← חשבון ← מחיקת חשבון."

**מה לסמן ב-Data safety / App Privacy**

| סוג מידע | נאסף | למה | מקושר למשתמש |
|---|---|---|---|
| User IDs | כן | פונקציונליות, אנליטיקס | כן |
| Name, Email (רק בהתחברות) | כן | פונקציונליות | כן |
| Photos (תמונת פרופיל מהספק) | כן | פונקציונליות | כן |
| Device or advertising ID | כן | פרסום, אנליטיקס | Android: כן / iOS: Tracking אם אושר ATT |
| Purchase history | כן | פונקציונליות | כן |
| App interactions, Crash/diagnostics | כן | אנליטיקס | לא |
| Gameplay content (ניקוד, חברים) | כן | פונקציונליות | כן |

מוצפן בהעברה: כן. אפשר לבקש מחיקה: כן.

---

## שלב 6: לבדוק על מכשיר אמיתי לפני הגשה

- [ ] כניסה כאורח, שלב ראשון, רמז, חנות.
- [ ] טופס הסכמה לפרסומות + בקשת ATT ב-iPhone.
- [ ] פרסומת מתנה בחנות (רמז), פרסומת מסך מלא אחרי שלב 6+.
- [ ] רכישה בכל חנות עם חשבון בדיקה, וזיכוי המטבעות.
- [ ] התחברות עם מייל ועם Apple, ואז **מחיקת חשבון**.
- [ ] משחק מול חבר בשני מכשירים.
- [ ] קישורי פרטיות/תנאים בהגדרות נפתחים.

---

## אתר (Web)

- נפרס אוטומטית ל-GitHub Pages בכל push ל-main.
- פרסומות באתר: AdSense לא מאשר אתרים בתת-תיקייה של github.io. כדי להרוויח
  מהאתר צריך דומיין משלכם (למשל `play.ronimichaeli.com`), לחבר אותו ל-GitHub
  Pages או ל-Firebase Hosting, ולבנות עם `ADSENSE_CLIENT`.

---

## מה כבר מוכן בקוד

- [x] מחיקת חשבון מתוך המשחק (הגדרות ← חשבון) + דף מחיקה ציבורי.
- [x] מדיניות פרטיות ותנאי שימוש כדפים באתר, עם קישורים מההגדרות + "צרו קשר".
- [x] חתימת release מ-`android/key.properties`.
- [x] מזהי AdMob/Facebook/Google מחוץ לקוד (`key.properties`, `AppSecrets.xcconfig`,
      `config/release.json`), לא נשמרים ב-git.
- [x] Sign in with Apple entitlement.
- [x] נעילה לאורך; iOS ל-iPhone בלבד (לא צריך צילומי מסך של iPad).
- [x] `ITSAppUsesNonExemptEncryption = NO` (לא צריך מסמכי הצפנה).
- [x] כפתורי Google/Facebook מוסתרים באפליקציה עד שמגדירים אותם.
- [x] פרסומות: AdMob (מתנה, מסך מלא, מובנית), UMP, ATT, SKAdNetwork, מכסות יומיות.
- [x] רכישות: 6 חבילות, מחירים מקומיים, מניעת זיכוי כפול, רכישה ממתינה.
- [x] אייקונים, צלילים, Analytics.
- [x] CI: ניתוח, בדיקות, בילד אתר ובילד App Bundle.

## אחרי ההשקה (לא חוסם)

- [ ] Crashlytics לדיווח קריסות.
- [ ] Native splash (`flutter_native_splash`).
- [ ] אימות מילים/ניקוד בצד שרת (Cloud Functions) למשחק מול חברים.
- [ ] בדיקת נגישות והגדלת טקסט.
