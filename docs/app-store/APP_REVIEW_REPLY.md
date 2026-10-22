# תשובה ל-Apple (Guideline 2.1 - Information Needed)

Apple ביקשה הקלטת מסך ממכשיר אמיתי + 6 תשובות. התשובה המלאה (באנגלית) למטה,
והיא כבר הודבקה גם בשדה Notes של App Review Information.

---

## 🎬 מדריך הקלטה (באייפון, כ-3 דקות)

### הכנה (פעם אחת, 5 דקות)
1. באייפון: להתקין את **TestFlight**: https://apps.apple.com/app/testflight/id899247664
2. לפתוח את המייל מ-TestFlight ("You're invited to test מצא ת׳מילה") ← **View in TestFlight** ← **Install**.
   (אם אין מייל: לפתוח את TestFlight באייפון, האפליקציה תופיע שם אם החשבון שלך הוא Apple ID של המפתח.)
3. להוסיף כפתור הקלטה: **הגדרות ← מרכז הבקרה** ← להוסיף **הקלטת מסך**.
4. **חבר/ה לבדיקה (בשביל הדיווח והחסימה):** במחשב, באתר https://roni5604.github.io/WordboxGame/
   להיכנס כאורח, לקבוע כינוי (למשל "בודק"), ובמסך **חברים ← הוספת חבר** להקליד את קוד החבר מהאייפון.
   (אחרי ההתחברות באייפון, קוד החבר מופיע במסך **חברים**.)

### ההקלטה (לפי הסדר, בלי לעצור)
1. ▶️ מתחילים הקלטה (מרכז הבקרה ← ⏺).
2. פותחים את **מצא ת׳מילה** מהמסך הראשי (Apple רוצה לראות את הפתיחה).
3. **הרשמה/התחברות:** במסך הראשון ← **המשך עם Apple** ← מאשרים.
4. **משחק:** **המשך משחק** ← גוררים אצבע על מילה אחת או שתיים ← יוצאים.
5. **קנייה:** **חנות** ← לשונית **כסף** ← **₪4.90** (200 מטבעות) ← מאשרים (ב-TestFlight זה בחינם) ← רואים שהמטבעות עלו.
6. **דיווח וחסימה:** **חברים** ← **בקשות** ← ⋮ ליד "בודק" ← **דיווח על משתמש/ת** ← בוחרים סיבה ← **חסימה**.
7. **רשימת חסומים:** ⚙️ **הגדרות** ← **משתמשים חסומים** (רואים את "בודק").
8. **מחיקת חשבון:** ⚙️ **הגדרות** ← **מחיקת חשבון** ← מאשרים (Apple מבקשת אישור) ← חוזרים למסך הפתיחה.
9. ⏹ עוצרים את ההקלטה. הסרטון נשמר ב**תמונות**.

### שליחה ל-Claude
- AirDrop של הסרטון למק (נשמר בתיקיית **הורדות**), ולכתוב "שלחתי".
  Claude יכווץ אותו ויעלה אותו לתשובה ל-Apple.

---

## ✉️ התשובה ל-Apple (באנגלית, Claude שולח)

Hello App Review team,

Thank you for reviewing מצא ת׳מילה ("Find the Word"). Here is the requested information. The screen recording (iPhone, latest iOS, TestFlight build 1.0.0 (5)) is attached.

**1. Screen recording** - attached. It starts from launching the app and shows: sign-in with Apple (account creation/login), gameplay, an In-App Purchase, reporting and blocking another user, the blocked-users list, and account deletion.

**2. Purpose and audience** - A Hebrew word-search puzzle game for Hebrew speakers aged 13+. Players drag a finger across adjacent letters to form Hebrew words on a grid that grows from 3×3 to 7×7 across 100 levels. It offers vocabulary practice and a daily brain challenge in Hebrew, a language with very few quality word games, plus a daily challenge and friendly real-time matches with friends.

**3. Setup and access** - No account or credentials are needed. On the first screen tap "המשך כאורח/ת בלי להתחבר" (Continue as guest). Home screen: "המשך משחק" (Continue) starts the next level; "שחק נגד המחשב" (vs computer); "שחק נגד חברים" (vs friends); "אתגר יומי" (daily challenge); "חנות" (Store); gear icon = Settings. Optional sign-in: Settings → "התחברות / הרשמה" (Apple, Google or email). Account deletion: Settings → "מחיקת חשבון". Report/Block: the ⋮ button next to any other user (friends list, friend requests, game invites, room lobby). Blocked users: Settings → "משתמשים חסומים".

**4. External services** - Firebase by Google (Authentication: anonymous/Apple/Google/email; Cloud Firestore: progress, friends, game rooms; Analytics; Crashlytics), Sign in with Apple, Google Sign-In, Apple StoreKit for In-App Purchase. The Google Mobile Ads SDK is included but ads are disabled in this version. No AI services. The Hebrew dictionary is bundled in the app (an open CC0 word list maintained by the developer).

**5. Regional differences** - None. The app works the same in all regions; the interface is in Hebrew.

**6. Regulated industry / protected material** - Not applicable. The app is a casual game, not in a regulated industry, and contains no third-party protected material (dictionary: CC0; font: Heebo, SIL Open Font License).

**7. In-App Purchases** - Six consumable packs: 200 / 600 / 1500 coins and 5 / 15 / 40 hints. Coins buy hints, level skips and letter-tile themes; a hint reveals a word on the board. Path: Home → "חנות" (Store) → "כסף" (Money) tab → tap a price.

**User-generated content** - Limited to display names, friend requests and game invites (no chat or free text between users). Display names are filtered for profanity; users must accept community rules (zero tolerance for objectionable content or abusive users) before using social features; every user can be reported or blocked; blocked users cannot send friend requests or invites (enforced server-side); reports are reviewed within 24 hours and offending content/accounts are removed.

Thank you,
Roni Michaeli
