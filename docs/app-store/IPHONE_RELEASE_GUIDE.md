# מדריך העלאה ל-App Store: צעד אחר צעד

הקוד, הגדרות ה-iOS, צילומי המסך והטקסטים לחנות כבר מוכנים. המדריך הזה
מכסה רק את מה שדורש אותך: סיסמה, תשלום, חשבון Apple או לחיצה בקונסולה.
הסדר חשוב, כי חלק מהשלבים לוקחים זמן (אישור חשבון המפתח לוקח עד 48 שעות),
אז כדאי להתחיל אותם מוקדם.

| # | שלב | מי | זמן |
|---|---|---|---|
| 1 | פינוי מקום בדיסק | את/ה (פקודה אחת) | 5 דק' |
| 2 | חשבון Apple Developer (99$) | את/ה | 15 דק' + עד 48 שעות המתנה |
| 3 | עדכון macOS | את/ה | כשעה |
| 4 | התקנת Xcode | את/ה | 30-60 דק' |
| 5 | בנייה, בדיקה בסימולטור והכנת הקובץ | Claude | אוטומטי |
| 6 | יצירת האפליקציה ב-App Store Connect | את/ה (העתק-הדבק) | 30 דק' |
| 7 | העלאה, TestFlight ושליחה לבדיקה | ביחד | 20 דק' + 1-2 ימי בדיקה |

---

## 1. פינוי מקום בדיסק

עדכון macOS ו-Xcode צריכים יחד כ-**80GB פנויים**, ויש כרגע כ-38GB.
אלה תיקיות זמניות שנבנות מחדש לבד כשצריך:

| תיקייה | גודל | מה זה |
|---|---|---|
| `~/Library/Caches` | ~19GB | מטמון של אפליקציות |
| `~/.gradle` | ~10GB | מטמון בנייה של אנדרואיד |
| `WordboxGame/build` | ~1.4GB | קבצי בנייה של הפרויקט |

אפשר גם לרוקן את סל המחזור ולעבור על `~/Downloads` (‏5GB).

## 2. חשבון Apple Developer

1. להיכנס ל-https://developer.apple.com/programs/enroll/ עם ה-Apple ID שלך.
   - ה-Apple ID חייב **אימות דו-שלבי** פעיל.
   - הכי מהיר: להוריד את אפליקציית **Apple Developer** באייפון
     (https://apps.apple.com/app/apple-developer/id640199958), ללחוץ שם
     **Account → Enroll now** ולסרוק תעודה מזהה.
2. לבחור **Individual / Sole Proprietor** (אדם פרטי; לא צריך חברה).
   השם שלך יופיע בחנות כ"מפתח".
3. לשלם 99$ (חיוב שנתי).
4. לחכות למייל "Welcome to the Apple Developer Program" (בדרך כלל כמה
   שעות, לפעמים עד 48).

## 3. עדכון macOS

Xcode 27 (הגרסה ב-App Store) דורש **macOS Tahoe 26.6 ומעלה**, והמחשב
כרגע על macOS 15.5.

1. ** > System Settings > General > Software Update**.
2. לבחור **macOS 27.0.1** → Upgrade Now (כ-13GB, ואחר כך הפעלה מחדש).
3. לגבות קודם ב-Time Machine (מומלץ).

> **חלופה בלי שדרוג גדול:** להתקין רק את **macOS Sequoia 15.8.1** (עדכון
> קטן), ולהוריד **Xcode 26.3** מ-https://developer.apple.com/download/all/
> (צריך את חשבון המפתח). Apple מקבלת בנייה מ-Xcode 26 לפחות עד אפריל 2027.

## 4. התקנת Xcode

1. App Store → **Xcode** (https://apps.apple.com/app/xcode/id497799835) → Get.
2. לפתוח את Xcode פעם אחת, לאשר את הרישיון, ובחלון ההתקנה לסמן **iOS**
   (מוריד את הסימולטור והפלטפורמה, כ-8GB).
3. **Xcode → Settings → Accounts → +** → Apple ID → להתחבר עם החשבון של
   שלב 2. אחרי האישור יופיע שם צוות (Team) עם השם שלך.
4. בטרמינל (יבקש את סיסמת המחשב):
   ```bash
   sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer && sudo xcodebuild -runFirstLaunch
   ```
5. לכתוב ל-Claude "Xcode מוכן".

## 5. מה Claude עושה מכאן (בלי צורך בך)

- `flutter doctor`, בנייה והרצה בסימולטור של אייפון ובדיקה של כל המסכים
  (התחברות כאורח, שלב, רמז, חנות, הגדרות, מחיקת חשבון).
- בחירת ה-Team בפרויקט וחתימה אוטומטית.
- בניית קובץ ההעלאה: `flutter build ipa --release --dart-define-from-file=config/release.json`.

## 6. יצירת האפליקציה ב-App Store Connect

כל הטקסטים מוכנים להעתקה ב-`docs/app-store/APP_STORE_LISTING.md`.

1. https://appstoreconnect.apple.com/apps → **+** → **New App**:
   - Platforms: **iOS**
   - Name: `מצא ת׳מילה`
   - Primary Language: **Hebrew**
   - Bundle ID: `com.wordboxil.wordboxHebrew` (אם לא מופיע ברשימה, Claude
     ייצור אותו בבנייה הראשונה, או ב-https://developer.apple.com/account/resources/identifiers/add/bundleId
     עם הסימון **Sign In with Apple**)
   - SKU: `wordbox-hebrew-ios`
   - User Access: Full Access
2. **App Information**: Subtitle, Category (Games → Word), Privacy Policy URL.
3. **Pricing and Availability**: Price **Free (0)**, זמינות בכל המדינות
   (או רק ישראל).
4. **App Privacy**: לפי הטבלה במסמך הטקסטים → Publish.
5. **Age Rating**: לפי המסמך (יוצא 13+).
6. **דף הגרסה 1.1.0**: לגרור את 7 התמונות מ-`docs/app-store/screenshots-6.9/`
   לאזור **iPhone 6.9" Display**, ולהדביק Promotional Text, Description,
   Keywords, Support URL, Copyright, ו-App Review Information (Notes).

### רכישות בתוך האפליקציה (לא חובה לגרסה הראשונה)

לפני יצירת המוצרים צריך הסכם תשלומים:

1. https://appstoreconnect.apple.com/business → **Paid Apps** → לחתום.
2. להוסיף **Bank Account** (IBAN ישראלי מתאים) ו-**Tax Forms**: טופס
   **W-8BEN** (אדם פרטי מחוץ לארה"ב; לסמן את אמנת המס ישראל-ארה"ב).
3. אחרי שההסכם Active: האפליקציה → **Monetization → In-App Purchases** →
   6 מוצרים מסוג **Consumable**, לפי הטבלה במסמך הטקסטים.
4. בגרסה: בסעיף **In-App Purchases and Subscriptions** לסמן את 6 המוצרים
   כדי שייבדקו יחד עם האפליקציה.

## 7. העלאה, TestFlight ושליחה

1. Claude בונה ומעלה (או: Xcode → Window → Organizer → Archives →
   **Distribute App → App Store Connect → Upload**).
2. אחרי כ-15 דקות הבנייה מופיעה ב-App Store Connect → **TestFlight**.
   - ב-**Export Compliance** כבר מוגדר שאין הצפנה מיוחדת, אז לא יישאל.
   - להתקין את אפליקציית **TestFlight** באייפון שלך ולבדוק את המשחק
     באמת: אורח, שלב, Apple Sign-In, רכישה (בסביבת Sandbox לא מחויבים),
     מחיקת חשבון.
3. בדף הגרסה → **Build** → לבחור את הבנייה → **Add for Review** →
   **Submit to App Review**.
4. הבדיקה לוקחת בדרך כלל 24-48 שעות. אם יש דחייה, מעתיקים את ההודעה
   ל-Claude ומתקנים.
5. אחרי אישור: **Release this version** (או שחרור אוטומטי).

---

## לפני ההגשה: לבדוק בשרת (Firebase)

- **Authentication → Sign-in method**: Anonymous, Email/Password ו-**Apple** פעילים.
- חוקי Firestore מעודכנים בשרת:
  ```bash
  firebase deploy --only firestore:rules
  ```
- פרטים מלאים ב-`docs/STORE_LAUNCH_CHECKLIST.md` (שלב 1).
