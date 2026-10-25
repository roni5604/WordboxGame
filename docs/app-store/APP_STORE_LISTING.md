# דף האפליקציה ב-App Store - טקסטים מוכנים להעתקה

כל שדה כאן מוכן להדבקה ב-App Store Connect כמו שהוא. המגבלות של Apple
רשומות ליד כל שדה, וכל הטקסטים כבר בתוכן.

צילומי מסך מוכנים (iPhone 6.9", ‏1320×2868): `docs/app-store/screenshots-6.9/`
(להעלות לפי הסדר 01 עד 07; Apple מקטינה אותם בעצמה לכל שאר הגדלים).

---

## App Information (פעם אחת)

| שדה | ערך |
|---|---|
| **Name** (עד 30) | `מצא ת׳מילה` |
| שם חלופי, אם השם תפוס | `מצא ת׳מילה - משחק מילים` |
| **Subtitle** (עד 30) | `משחק מילים עברי ומאתגר` |
| **Bundle ID** | `com.wordboxil.wordboxHebrew` |
| **SKU** | `wordbox-hebrew-ios` |
| **Primary language** | Hebrew |
| **Primary category** | Games → Word |
| **Secondary category** | Games → Puzzle |
| **Content rights** | No, it does not contain, show, or access third-party content |
| **Privacy Policy URL** | `https://roni5604.github.io/WordboxGame/privacy.html` |

## Version 1.0 (דף הגרסה)

**Promotional Text** (עד 170, אפשר לשנות בכל עת בלי בדיקה):

```
חדש! אותיות קשות שוות נקודה נוספת, אתגר יומי עם רצף ימים, ומשחק בזמן אמת נגד חברים. כמה מילים תמצאו?
```

**Description** (עד 4000):

```
מצא ת׳מילה הוא משחק מילים ממכר בעברית. מחברים אותיות שכנות על הלוח (לרוחב, לאורך או באלכסון), מוצאים כמה שיותר מילים לפני שהזמן נגמר, ומתקדמים משלב לשלב.

איך משחקים?
גוררים אצבע על אותיות סמוכות כדי ליצור מילה. כל מילה נכונה מוסיפה נקודות, ומילים ארוכות שוות יותר. אותיות סופיות? אין צורך לחפש אותן: המשחק ממיר לבד ך, ם, ן, ף, ץ בסוף המילה.

מה מחכה לכם:
• 100 שלבים בעולמות צבעוניים, והלוח גדל משלב לשלב מ-3×3 ועד 6×6 (ועד 7×7 במשחק מול חברים)
• מילון עברי עשיר עם עשרות אלפי מילים: שמות עצם, פעלים בכל הבניינים, תארים, נטיות וסלנג
• אותיות קשות (ז, ט, צ, ג, ס, ק, פ) בסגול, שוות נקודה נוספת
• שלושה כוכבים לכל שלב, תיבות מזל, גלגל מזל ופרסים
• תחרות נגד המחשב: מרוץ מול 1-3 יריבים עם שעון רץ
• משחק נגד חברים בזמן אמת: חדר פרטי, הזמנה בוואטסאפ, ודירוג חברים
• אתגר יומי: לוח אחד לכל השחקנים, ניסיון אחד ביום, ורצף ימים עם בונוס
• רמזים, בונוס יומי ועיצובים לאריחים
• זואי הבלשית מלווה אתכם עם הדרכה קצרה וחוקים פשוטים

מתאים לכל מי שאוהב תשבצים, חידות ומשחקי מילים, ורוצה לאמן את המוח בעברית.

אפשר לשחק כאורחים בלי להירשם, ולהתחבר בכל רגע עם Apple או מייל כדי לשמור את ההתקדמות ולשחק עם חברים.

המשחק חינמי. יש בו רכישות אופציונליות של מטבעות ורמזים.

משחקו של רוני מיכאלי.
```

**Keywords** (עד 100 תווים, מופרדים בפסיק בלי רווחים):

```
מילים,משחק מילים,תשבץ,עברית,אותיות,חידות,פאזל,מוח,אתגר יומי,חברים,אוצר מילים,חיפוש מילים,word
```

**Support URL**: `https://roni5604.github.io/WordboxGame/`
**Marketing URL** (לא חובה): `https://ronimichaeli.com/he/`
**Copyright**: `2026 Roni Michaeli`
**Version**: `1.0` (תואם ל-`version: 1.0.0` ב-pubspec)

**What's New** (לא נדרש בגרסה הראשונה; לגרסאות הבאות):

```
שיפורי יציבות ותאימות ל-iOS 27.
```

**What's New - 1.0.1** (build 16, הוגש 24.10.2026):

```
• מפת עולמות חדשה בתלת-ממד: שביל מתפתל אל האופק, נוף משלו לכל עולם, ונהר זוהר עם גשר במעבר בין עולמות
• חיות חוקרות מצטרפות לבלש: ארנבת, צפרדע, דבורה וינשוף
• הדרכה חדשה ואינטראקטיבית בשלב הראשון: מנסים בעצמכם עם אצבע מדגימה, ואפשר לדלג בכל רגע
• צלילים חדשים: בועות, קריסטל ועץ, וצליל שעולה עם כל אות במילה
• מוזיקת רקע קצבית בין המשחקים (אפשר לכבות בהגדרות) וספירה לאחור עם ג'ינגל
• רטט שמתחזק ככל שהמילה מתארכת
• תיקון: רשימת החברים וקוד החבר מתעדכנים מיד אחרי מעבר בין חשבונות
```

---

## Version 1.1.0 (build 17) - גרסת הבוטים, החברים והפרסומות

צילומי מסך: 10 תמונות חדשות מהאפליקציה האמיתית ב-`screenshots-6.9/` וב-`screenshots-6.3/`
(01 עד 10, לפי הסדר). סרטון: `app-preview/app-preview-v4-upload.mp4` (אותה רזולוציה
886×1920, דחוס ל-9.4MB כדי לעבור את מגבלת ה-10MB של Chrome).

**Promotional Text** (עד 170):

```
חדש: משחק חי נגד חברים עם קופת מטבעות, יריבים ממוחשבים שמגיבים כמו אנשים, "גלה מילה" ו-80 דמויות. כמה מילים תמצאו?
```

**What's New - 1.1.0** (עברית):

```
גרסה גדולה עם הרבה חדש:
• משחק חי נגד חברים בעיצוב חדש: יוצרים חדר בעמוד אחד, בוחרים דמי כניסה של 50 עד 500 מטבעות, והזוכה לוקח את הקופה
• במשחק מול חברים: רמז, "גלה מילה", והצצה (במטבעות) למילים שהחברים מצאו
• מרוץ נגד המחשב בעיצוב חדש: יריבים שמשחקים ומגיבים כמו אנשים, בשלוש רמות קושי
• "גלה מילה": תקועים? המשחק מראה מילה שמסתתרת בלוח, ואתם מוצאים אותה
• 80 דמויות חדשות לבחירה: כלבים, חיות, ילדים ודמויות
• חנות חדשה בתלת-ממד: מתנה יומית, רמזים, מטבעות ועיצובים לאריחים
• מפת שלבים חיה עם עולמות חדשים ותיבות מזל
• חוקי משחק אינטראקטיביים עם אצבע מדגימה
• פרסומות: אפשר לבחור לצפות בפרסומת קצרה תמורת רמז, מטבעות או הכפלת פרס, ומדי כמה שלבים מופיעה פרסומת בין שלבים. מי שרכש/ה במשחק לא רואה פרסומות בין שלבים
• תיקונים: תוצאות נכונות בסוף משחק מול חברים, והקופה מחולקת פעם אחת בלבד
```

**What's New - 1.1.0** (English (Australia) - חובה, אחרת ההגשה נכשלת):

```
A big update:
• Live games with friends, redesigned: create a room on one page, pick an entry fee of 50–500 coins, and the winner takes the pot
• In friend games: hints, "Reveal a word", and a coin-paid peek at the words your friends found
• Play vs. the computer, redesigned: opponents that play and react like real people, in three difficulty levels
• "Reveal a word": stuck? The game shows you a word hidden on the board, and you find it
• 80 new avatars to choose from
• A new 3D store: daily gift, hints, coins and tile themes
• A living level map with new worlds and lucky boxes
• Interactive rules with a demo finger
• Ads: you can choose to watch a short ad for a hint, coins or a doubled reward, and every few levels an ad appears between levels. Players who made a purchase don't see ads between levels
• Fixes: correct results at the end of friend games, and the pot is paid out only once
```

**Description** - הנוסח המלא לגרסה 1.1.0:

```
מצא ת׳מילה הוא משחק מילים ממכר בעברית. מחברים אותיות שכנות על הלוח (לרוחב, לאורך או באלכסון), מוצאים כמה שיותר מילים לפני שהזמן נגמר, ומתקדמים משלב לשלב.

איך משחקים?
גוררים אצבע על אותיות סמוכות כדי ליצור מילה. כל מילה נכונה מוסיפה נקודות, ומילים ארוכות שוות יותר. אותיות סופיות? אין צורך לחפש אותן: המשחק ממיר לבד ך, ם, ן, ף, ץ בסוף המילה.

מה מחכה לכם:
• 100 שלבים במפה חיה, והלוח גדל משלב לשלב מ-3×3 ועד 6×6
• מילון עברי עשיר עם עשרות אלפי מילים: שמות עצם, פעלים בכל הבניינים, תארים, נטיות וסלנג
• אותיות קשות (ז, ט, צ, ג, ס, ק, פ) בסגול, שוות נקודה נוספת
• שלושה כוכבים לכל שלב, תיבות מזל, גלגל מזל ופרסים
• "גלה מילה": תקועים? המשחק מראה מילה שמסתתרת בלוח, ואתם מוצאים אותה
• מרוץ נגד המחשב: 1-3 יריבים ממוחשבים שמשחקים ומגיבים כמו אנשים, בשלוש רמות קושי
• משחק חי נגד חברים: חדר פרטי, הזמנה בוואטסאפ, דמי כניסה במטבעות והזוכה לוקח את הקופה (בחדרים אפשר גם לוח 7×7)
• במשחק מול חברים: רמזים, "גלה מילה" והצצה במטבעות למילים של החברים
• אתגר יומי: לוח אחד לכל השחקנים, ניסיון אחד ביום, ורצף ימים עם בונוס
• 80 דמויות לבחירה, חנות בתלת-ממד, בונוס יומי ועיצובים לאריחים
• חוקי משחק אינטראקטיביים, וזואי הבלשית שמלווה אתכם

מתאים לכל מי שאוהב תשבצים, חידות ומשחקי מילים, ורוצה לאמן את המוח בעברית.

אפשר לשחק כאורחים בלי להירשם, ולהתחבר בכל רגע עם Apple, Google או מייל כדי לשמור את ההתקדמות ולשחק עם חברים.

המשחק חינמי. יש בו רכישות אופציונליות של מטבעות ורמזים, ופרסומות: פרסומת קצרה לבחירתכם תמורת רמז או מטבעות, ומדי כמה שלבים פרסומת בין שלבים. מי שרכש/ה במשחק לא רואה פרסומות בין שלבים. המטבעות הם מטבע וירטואלי בתוך המשחק בלבד.

משחקו של רוני מיכאלי.
```

**App Review Notes - 1.1.0** (באנגלית):

```
מצא ת׳מילה ("Find the Word") is a Hebrew word game. No login is required: on the first screen tap "המשך כאורח/ת בלי להתחבר" (Continue as guest). How to play: drag a finger across adjacent letters to form Hebrew words.

WHAT'S NEW IN 1.1.0 (build 17)
1) Ads (Google AdMob), two formats only:
- Rewarded ads, always chosen by the player: e.g. Store → "רמז חינם" (free hint), or "צפו והכפילו" (watch and double) on the level result screen.
- Interstitial ads between campaign levels (after tapping "השלב הבא" / Next level): never in levels 1-3, at most once every 3 completed levels, at least 2 minutes apart, and never for players who made an in-app purchase.
No banner or native ads, and no ads during gameplay.
2) Consent and App Tracking Transparency: on first launch the app shows Google's consent message where required (e.g. EEA/UK), then the iOS ATT prompt with our Hebrew explanation. Declining is fully supported: ads become non-personalized and every feature keeps working. App Privacy was updated (Device ID, Advertising Data, Coarse Location, used for tracking) and the age rating declares advertising.
3) Play vs. the computer (Home → "שחק נגד המחשב" → "בואו נתחרה!"): 1-3 computer opponents with short pre-written reactions. The mode is clearly labeled as playing against the computer. There is no chat.
4) Friend rooms (Home → "שחק נגד חברים" → "יצירת חדר והזמנת חברים"): private rooms with an entry fee in virtual coins (50/100/200/500); the winner receives the pot. Coins are a virtual in-game currency only: they cannot be withdrawn, transferred, exchanged or cashed out, and the result depends only on skill (finding words), with no element of chance. A second player can join with the 5-digit room code from another device or from the web version: https://roni5604.github.io/WordboxGame/
5) "גלה מילה" (Reveal a word, 45 coins) shows a word that is on the board. In friend games a player can also spend 50 coins to see the words a friend found.
6) New avatars, a redesigned store, a level map and interactive rules.

ACCOUNT: Sign in with Apple, Google and email are optional (Settings → "התחברות / הרשמה"). Account deletion: Settings (gear icon on the home screen) → "מחיקת חשבון" (Delete account).

IN-APP PURCHASES: Store. All 6 products are consumables (coins and hints).

USER SAFETY: there is no chat or free-form messaging. Display names are filtered for offensive words, players can report and block other players (Settings → "משתמשים חסומים"), and community rules are shown before the Friends screen.
```

## App Preview (סרטון בדף החנות) - הועלה בגרסה 1.1.0

הסרטון שרוני הכין: `docs/app-store/app-preview/app-preview-v4.mp4`
(886×1920 לאורך, 21.5 שניות, H.264 + AAC, 30fps, 29.5MB - עומד בדרישות של
Apple ל-iPhone 6.9"/6.5").

- **מתי:** יחד עם הגרסה הבאה (אחרי ש-1.0.1 מאושרת). לא להעלות גרסה לפני
  שרוני מאשר/ת.
- **איפה:** App Store Connect → הגרסה החדשה → Previews and Screenshots →
  iPhone 6.9" Display → גרירת הסרטון לפני צילומי המסך (עד 3 סרטונים).
  לבחור Poster Frame (התמונה שמוצגת לפני הניגון) מרגע ברור במשחק.
- להוסיף אותו גם ב-English (Australia) אם הלוקליזציה לא יורשת אותו.
- העלאה דרך Chrome מוגבלת ל-10MB לקובץ - להעלות מ-Safari או ישירות מהמחשב
  (גרירה לדף), או לדחוס עם AVAssetWriter בלי לשנות את הרזולוציה.



| שדה | ערך |
|---|---|
| Sign-in required | **No** (אפשר לשחק כאורח) |
| Contact | השם, הטלפון והמייל שלך (`roniro5604@gmail.com`) |

**Notes** (באנגלית, כי הבודקים קוראים אנגלית):

```
The app is a Hebrew word game. No login is required: on the sign-in screen tap "המשך כאורח/ת בלי להתחבר" (Continue as guest).

How to play: drag a finger across adjacent letters to form Hebrew words.

Sign in with Apple and email sign-in are optional (Settings → Account).
Account deletion: Settings (gear icon on the home screen) → "חשבון" (Account) → "מחיקת חשבון" (Delete account).

In-app purchases: Store → "כסף" tab. All 6 products are consumables (coins and hints).

Multiplayer with friends uses private rooms; there is no chat or free-form messaging between users. Display names are sanitized.
```

---

## App Privacy (שאלון "פרטיות האפליקציה")

**Do you or your third-party partners collect data from this app?** Yes

| סוג מידע ב-App Store Connect | למה (Purposes) | Linked to user | Tracking |
|---|---|---|---|
| Contact Info → **Name** | App Functionality | Yes | No |
| Contact Info → **Email Address** | App Functionality | Yes | No |
| User Content → **Photos or Videos** (תמונת פרופיל מספק ההתחברות) | App Functionality | Yes | No |
| User Content → **Other User Content** (ניקוד, חברים, חדרים) | App Functionality | Yes | No |
| Identifiers → **User ID** | App Functionality, Analytics | Yes | No |
| Identifiers → **Device ID** | Third-Party Advertising, Analytics | No | **Yes** (רק אם מפעילים פרסומות) |
| Purchases → **Purchase History** | App Functionality | Yes | No |
| Usage Data → **Product Interaction** | Analytics | Yes (Analytics מקבל את מזהה המשתמש) | No |
| Usage Data → **Advertising Data** | Third-Party Advertising | No | **Yes** (רק אם מפעילים פרסומות) |
| Diagnostics → **Crash Data** | App Functionality | Yes (Crashlytics מקבל את מזהה המשתמש) | No |
| Diagnostics → **Performance Data** | App Functionality | Yes | No |

> **מהגרסה עם הפרסומות (אחרי 1.0.1)** - לעדכן ב-App Privacy **לפני** ההגשה:
> - לסמן **Device ID** ו-**Advertising Data** (Third-Party Advertising), שניהם
>   **Used for Tracking: Yes** - הבילד מבקש ATT (`ATT_ENABLED=true` ב-`config/release.json`).
> - להוסיף **Location → Coarse Location** (Third-Party Advertising, Not linked,
>   Tracking: Yes) - AdMob מסיק מיקום כללי מכתובת ה-IP.
> - ב-Age Rating לסמן **Advertising: Yes**.
> - בהערות ל-App Review: ATT מוצג פעם אחת בהפעלה הראשונה, אחרי מסך הסבר של Google.
>
> גרסאות 1.0.0 ו-1.0.1 נבנו בלי מזהי AdMob ולכן בלי פרסומות ובלי ATT.

---

## Age Rating (שאלון הגיל)

לענות **None / No** על כל שאלות התוכן (אלימות, מין, סמים, הימורים, אימה
וכו').

- **Unrestricted Web Access**: No
- **User-Generated Content**: No (רק כינויים מסוננים, בלי צ'אט)
- **Messaging and Chat**: No
- **Advertising**: Yes רק אם מפעילים פרסומות
- **In-App Purchases**: Yes
- **Simulated Gambling**: No (גלגל המזל ותיבות המזל לא בכסף אמיתי ולא ניתנים לקנייה ישירה)

בסוף, ב-**Age Rating Override** לבחור **13+**, כדי שיתאים למדיניות
הפרטיות ולתנאי השימוש.

---

## In-App Purchases (6 מוצרים, כולם Consumable)

| Product ID | Reference Name | Display Name (עברית) | Description (עברית) | מחיר |
|---|---|---|---|---|
| `wordbox_coins_200` | Coins 200 | 200 מטבעות | חבילת 200 מטבעות למשחק | ₪3.90 |
| `wordbox_coins_600` | Coins 600 | 600 מטבעות | חבילת 600 מטבעות למשחק | ₪7.90 |
| `wordbox_coins_1500` | Coins 1500 | 1500 מטבעות | חבילת 1500 מטבעות למשחק | ₪14.90 |
| `wordbox_hints_5` | Hints 5 | 5 רמזים | 5 רמזים למציאת מילים | ₪3.90 |
| `wordbox_hints_15` | Hints 15 | 15 רמזים | 15 רמזים למציאת מילים | ₪7.90 |
| `wordbox_hints_40` | Hints 40 | 40 רמזים | 40 רמזים למציאת מילים | ₪14.90 |

לכל מוצר צריך גם **Review Screenshot**: צילום של לשונית "כסף" בחנות
מתוך האייפון (אותה תמונה לכל השישה).

> אם עוד לא רוצים רכישות בגרסה הראשונה: פשוט לא ליצור את המוצרים. האפליקציה
> מציגה רק חבילות שהחנות מחזירה, ובלי מוצרים לא יופיע אף כפתור קנייה.
