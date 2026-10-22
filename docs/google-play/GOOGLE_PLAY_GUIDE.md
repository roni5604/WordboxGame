# מדריך העלאה ל-Google Play - מצא ת׳מילה

## ✅ מה כבר מוכן (Claude)
- קובץ האפליקציה החתום: `build/app/outputs/bundle/release/app-release.aab` (76MB).
  לבנייה מחדש: `flutter build appbundle --release`.
- מפתח העלאה (upload key): `~/upload-keystore.jks`, והסיסמה ב-`android/key.properties`.
  שני הקבצים **לא** נשמרים ב-git.
- אייקון 512×512: `docs/google-play/icon-512.png`
- תמונה ראשית (Feature graphic) 1024×500: `docs/google-play/feature-graphic-1024x500.png`
- 7 צילומי מסך 1080×1920: `docs/google-play/screenshots/` (נוצרו מצילומי ה-App Store, בלי חפיפת טקסט)
- כל הטקסטים למטה, מוכנים להעתקה.

> ⚠️ **גיבוי חובה:** להעתיק את `~/upload-keystore.jks` ואת `android/key.properties`
> למקום בטוח (iCloud Drive / דיסק חיצוני). בלעדיהם אי אפשר להעלות עדכונים
> (אפשר לשחזר מול Google, אבל זה לוקח ימים).

---

## 🔴 שלב 1: פתיחת חשבון מפתח (רק את/ה, כ-20 דקות + המתנה)
1. https://play.google.com/console/signup
2. לבחור **עבורך** (Yourself / Personal).
3. למלא פרטים ולשלם **25$** (חד-פעמי).
4. אימות זהות: צילום תעודה מזהה. האישור לוקח בדרך כלל יום-יומיים.
5. אימות טלפון ממכשיר אנדרואיד (Google תבקש להתקין את אפליקציית Play Console בטלפון אנדרואיד).

> **חשוב לחשבון אישי:** לפני שמותר לפרסם לכולם, Google דורשת
> **בדיקה סגורה עם 12 בודקים לפחות, במשך 14 יום ברצף**.
> כדאי להתחיל לאסוף עכשיו 12 חברים עם Gmail ומכשיר אנדרואיד.

---

## 🟡 שלב 2: יצירת האפליקציה (Claude יכול לעשות את רוב זה אחרי שהחשבון מאושר)

**Create app** (יצירת אפליקציה):
| באנגלית | מה לבחור |
|---|---|
| App name | `מצא ת׳מילה` |
| Default language | Hebrew – עברית |
| App or game | **Game** |
| Free or paid | **Free** |

**Main store listing** (דף החנות):

שם (עד 30): `מצא ת׳מילה`

תיאור קצר (עד 80):
```
משחק מילים ממכר בעברית: גררו אצבע על אותיות ומצאו כמה שיותר מילים!
```

תיאור מלא (עד 4000) - גרסת אנדרואיד (Google במקום Apple):
```
מצא ת׳מילה הוא משחק מילים ממכר בעברית. מחברים אותיות שכנות על הלוח (לרוחב, לאורך או באלכסון), מוצאים כמה שיותר מילים לפני שהזמן נגמר, ומתקדמים משלב לשלב.

איך משחקים?
גוררים אצבע על אותיות סמוכות כדי ליצור מילה. כל מילה נכונה מוסיפה נקודות, ומילים ארוכות שוות יותר. אותיות סופיות? אין צורך לחפש אותן: המשחק ממיר לבד ך, ם, ן, ף, ץ בסוף המילה.

מה מחכה לכם:
• 100 שלבים בעולמות צבעוניים, והלוח גדל משלב לשלב מ-3×3 ועד 7×7
• מילון עברי עשיר עם עשרות אלפי מילים: שמות עצם, פעלים בכל הבניינים, תארים, נטיות וסלנג
• אותיות קשות (ז, ט, צ, ג, ס, ק, פ) בסגול, שוות נקודה נוספת
• שלושה כוכבים לכל שלב, תיבות מזל, גלגל מזל ופרסים
• תחרות נגד המחשב: מרוץ מול 1-3 יריבים עם שעון רץ
• משחק נגד חברים בזמן אמת: חדר פרטי, הזמנה בוואטסאפ, ודירוג חברים
• אתגר יומי: לוח אחד לכל השחקנים, ניסיון אחד ביום, ורצף ימים עם בונוס
• רמזים, בונוס יומי ועיצובים לאריחים
• הבלש מילולי מלווה אתכם עם הדרכה קצרה וחוקים פשוטים

מתאים לכל מי שאוהב תשבצים, חידות ומשחקי מילים, ורוצה לאמן את המוח בעברית.

אפשר לשחק כאורחים בלי להירשם, ולהתחבר בכל רגע עם Google או מייל כדי לשמור את ההתקדמות ולשחק עם חברים.

המשחק חינמי. יש בו רכישות אופציונליות של מטבעות ורמזים.

משחקו של רוני מיכאלי.
```

קטגוריה: **Word** (מילים). אימייל: `roniro5604@gmail.com`. אתר: `https://roni5604.github.io/WordboxGame/`
מדיניות פרטיות: `https://roni5604.github.io/WordboxGame/privacy.html`

---

## 🟢 שלב 3: App content (תוכן האפליקציה)

| סעיף | תשובה |
|---|---|
| **Privacy policy** | `https://roni5604.github.io/WordboxGame/privacy.html` |
| **Ads** (פרסומות) | **No** (בגרסה הזו אין פרסומות) |
| **Advertising ID** | **No** - הרשאת AD_ID הוסרה מה-Manifest (ראו AndroidManifest.xml) |
| **App access** | All functionality is available without special access (אפשר לשחק כאורח) |
| **Content rating** (שאלון IARC) | קטגוריה: Game. אלימות, מין, שפה, סמים, הימורים, הימורים מדומים: **No**. משתמשים מתקשרים ביניהם: **Yes** (חברים, כינויים והזמנות; אין צ'אט חופשי). שיתוף מיקום: **No**. רכישות דיגיטליות: **Yes**. Loot boxes בכסף: **No** (תיבות וגלגל מזל רק ממשחק) |
| **Target audience** | **13+** (13-15, 16-17, 18+) |
| **News app** | No |
| **Data safety** | ראו למטה |
| **Account deletion URL** | `https://roni5604.github.io/WordboxGame/delete-account.html` |
| **Government app / Financial / Health** | No |

**Data safety** (בטיחות נתונים):
- Collects data: **Yes**. Encrypted in transit: **Yes**. Users can request deletion: **Yes**.
- Personal info: **Name, Email address**: App functionality, Account management.
- Personal info: **User IDs**: App functionality, Analytics.
- Photos: **Photos**: App functionality (תמונת פרופיל מספק ההתחברות).
- Financial info: **Purchase history**: App functionality.
- App activity: **App interactions, Other user-generated content** (ניקוד, חברים): App functionality, Analytics.
- App info and performance: **Crash logs, Diagnostics**: Analytics.
- Device or other IDs: **Device or other IDs**: Analytics (מזהה ההתקנה של Firebase; לא מזהה פרסום).
- Shared with third parties: **No**. Collection is optional: Name/Email/Photos: **Optional** (אפשר לשחק כאורח).

---

## 🔵 שלב 4: בדיקה סגורה (Closed testing), 14 יום
1. **Testing → Closed testing → Create track**.
2. **Testers**: יוצרים רשימת מיילים (12+ אנשים עם Gmail).
3. **Create release** ← מעלים את `app-release.aab` ← Release notes: `גרסה ראשונה`.
4. **Review release → Start rollout**.
5. שולחים לבודקים את קישור ההצטרפות (**Join on the web**). כל אחד צריך להתקין ולהשאיר
   מותקן 14 יום.

## 🟣 שלב 5: רכישות (Monetize → Products → In-app products)
אחרי שהעלית AAB אחד אפשר ליצור את 6 המוצרים, עם אותם מזהים:
`wordbox_coins_200` · `wordbox_coins_600` · `wordbox_coins_1500` · `wordbox_hints_5` · `wordbox_hints_15` · `wordbox_hints_40`
מחירים: ₪4.90 / ₪9.90 / ₪19.90 (כמו באייפון). צריך גם **Payments profile** (פרטי בנק).

## 🏁 שלב 6: אחרי 14 יום
**Dashboard → Apply for production** ← עונים על השאלון ← Google בודקת (כמה ימים) ← **Production → Create release** ← אותו AAB ← **Start rollout**.

---

## עוד דבר טכני (Claude יטפל)
- התחברות Google באנדרואיד: טביעות ה-SHA של מפתח ההעלאה כבר ב-Firebase. אחרי ההעלאה הראשונה
  צריך להוסיף גם את SHA-1 ו-SHA-256 של **App signing key** (Play Console ← Test and release ←
  App integrity ← App signing). בלי זה Google לא יעבוד באפליקציה שהותקנה מ-Play.
- נבדק באמולטור (גרסת release): פתיחה, התחברות כאורח, משחק, חנות, כללי קהילה לפני כינוי,
  סינון כינוי פוגעני, הוספת חבר, מחיקת חשבון. targetSdk 36, Billing 9.1, ספריות 16KB.
