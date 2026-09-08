# מילה־קסם (Wordbox-IL) 🇮🇱🔤

משחק מילים בעברית בסגנון Boggle/Wordbox: מחברים אותיות שכנות על לוח שגדל
משלב לשלב, אוספים כוכבים ומטבעות, ומתקדמים דרך "עולמות" צבעוניים. נבנה עם
**Flutter** מקוד אחד יחיד עבור **iPhone, Android ואתר ציבורי (Web)**.

> תוכנית העבודה המלאה (ניתוח המשחק, מסמך העיצוב, ארכיטקטורה) נמצאת ב-
> [`docs/GAME_DESIGN.md`](docs/GAME_DESIGN.md).

## הרצה מקומית

```bash
flutter pub get
flutter run -d chrome      # אתר (הכי מהיר לפיתוח/בדיקה)
flutter run -d macos       # macOS desktop
flutter run                # מכשיר/אמולטור iOS או Android מחובר
```

## בדיקות

```bash
flutter test
```

## מבנה הפרויקט

```
lib/
  core/            # theme, routing, config, קבועים
  game_engine/     # לוגיקה טהורה (ללא Flutter): מילון, יצירת לוח, ניקוד
  data/            # מודלים + repositories (מקומי / Firebase)
  features/        # מסכי האפליקציה, לפי פיצ'ר
  providers/       # Riverpod providers גלובליים
assets/
  dictionaries/    # מילון עברי מאוצר (JSON)
  config/          # תדירויות אותיות ליצירת לוחות
tool/
  seed_words_raw.txt  # מקור רשימת המילים הגולמית (ראו docs/DICTIONARY_LICENSING.md)
docs/              # מסמכי תכנון, הקמת Firebase, רישוי, השקה
```

## מצב נוכחי

- ✅ **משחק יחיד-שחקן מלא**: קמפיין עם עשרות שלבים, לוח שגדל מ-3×3 עד 7×7,
  יצירת לוחות "פתירים" אוטומטית, ניקוד, 3 כוכבים לשלב, שמירת התקדמות
  מקומית (עובד לגמרי אופליין).
- ✅ **עיצוב ואנימציות**: מפת שלבים, מעברים, קונפטי, מסקוט מצויר-קוד,
  משוב חזותי (קו מחבר, רטט, צלילי הצלחה/כישלון).
- 🧪 **Backend (Firebase)**: קוד מוכן ומוכן להפעלה (Auth, Firestore
  לסנכרון התקדמות) - כבוי כברירת מחדל. ראו
  [`docs/FIREBASE_SETUP.md`](docs/FIREBASE_SETUP.md).
- 🧪 **רב-משתתפים**: מודלים + repository מבוססי Firestore קיימים כשלד,
  מוצגים במסך "בקרוב" באפליקציה. ראו "נושאים פתוחים" בתוכנית לפני מימוש מלא.
- ⚠️ **מילון**: רשימת מילים מאוצרת (821 מילים) שנכתבה במיוחד לפרויקט כדי
  להימנע מבעיות רישוי. ראו [`docs/DICTIONARY_LICENSING.md`](docs/DICTIONARY_LICENSING.md)
  להרחבה עתידית.

## רישיון גופנים

הטקסטים משתמשים בגופן [Heebo](https://fonts.google.com/specimen/Heebo)
(רישיון OFL) דרך חבילת `google_fonts`.
