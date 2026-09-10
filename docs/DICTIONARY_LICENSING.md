# רישוי מילון המילים העברי

## המצב הנוכחי (מעודכן)

מילון המשחק [`assets/dictionaries/he_words.json`](../assets/dictionaries/he_words.json)
נבנה כעת משני מקורות:

1. **[`roni5604/hebrew-words-db`](https://github.com/roni5604/hebrew-words-db)**
   - מאגר עברי חדש, נפרד ופתוח שהקמנו במיוחד כדי לפתור את בעיית הרישוי
   (ראו הסבר מלא למטה). המאגר ברישיון **CC0 1.0** (נחלת הכלל - חופשי
   לשימוש מסחרי, בלי ייחוס, בלי הגבלות), מכיל שמות עצם (יחיד+רבים),
   פעלים (בכל הבניינים/הזמנים), תארים (עם הטיות), תוארי פועל, מילות
   יחס/חיבור וסלנג ישראלי - **הרבה יותר מילים** מהרשימה המקורית הקטנה.
   עותק מוקפא שלו נשמר ב-`tool/vendor/hebrew_words_db_words.txt`
   (סונכרן באמצעות `tool/sync_hebrew_words_db.py`).
2. **[`tool/seed_words_raw.txt`](../tool/seed_words_raw.txt)** - הרשימה
   המקורית של הפרויקט הזה (878 מילים), נשמרת כמקור משני/היסטורי ולתוספות
   ספציפיות למשחק שעדיין לא הועלו למאגר הכללי.

`tool/build_dictionary.py` מאחד את שני המקורות, מסנן, מנרמל אותיות
סופיות ובונה את `assets/dictionaries/he_words.json` ואת
`assets/config/letter_frequency.json`.

## למה יצרנו מאגר משלנו (hebrew-words-db) במקום להשתמש ב-Hspell/DICTA?

בעת המחקר לפרויקט נבדקו מספר מילונים עבריים פתוחים קיימים:

| מקור | רישיון | בעיה לפרויקט מסחרי/סגור-קוד |
|---|---|---|
| [`eyaler/hebrew_wordlists`](https://github.com/eyaler/hebrew_wordlists) (מבוסס Hspell) | **AGPLv3** | AGPL "מדביק" - שילוב שלו עלול לחייב פתיחת קוד המשחק כולו |
| [`dicta-il/wordlist`](https://huggingface.co/datasets/dicta-il/wordlist) | **CC-BY-NC-4.0** | אסור שימוש מסחרי ללא רישיון נפרד מ-DICTA |
| MILA (טכניון) | רישיון מחקרי מוגבל | לא ברור/מתאים לשימוש מסחרי חופשי |

כדי לא להיות תלויים באף אחד מהמקורות האלה (וכדי לא "לשלם" מבחינה
משפטית או כספית), יצרנו **מאגר נפרד משלנו** -
[`hebrew-words-db`](https://github.com/roni5604/hebrew-words-db) - שמילותיו
נכתבו/הורכבו מחדש (בעזרת AI, מהידע הכללי על השפה העברית) ולא הועתקו
ממאגר קיים כלשהו, ופורסם תחת **CC0** כדי שיהיה חופשי לשימוש בלי שום
מגבלה - גם לנו, גם לכל מי שירצה להשתמש בו (כולל מודלי AI אחרים). ראו
[`docs/SOURCES.md`](https://github.com/roni5604/hebrew-words-db/blob/main/docs/SOURCES.md)
בריפו החדש להסבר המלא על המתודולוגיה.

## איך מרחיבים את המילון מעכשיו

1. **תוספות כלליות (מילים בעבריות שלא קשורות ספציפית למשחק הזה)** -
   הוסיפו אותן ל-`raw/*_raw.txt` בריפו
   [`hebrew-words-db`](https://github.com/roni5604/hebrew-words-db),
   הריצו שם `python3 scripts/build.py`, פתחו PR. אחרי שהמאגר מתעדכן,
   הריצו כאן `python3 tool/sync_hebrew_words_db.py` ואז
   `python3 tool/build_dictionary.py`.
2. **תוספות ספציפיות למשחק הזה בלבד** - הוסיפו ל-`tool/seed_words_raw.txt`
   כאן, ואז הריצו `python3 tool/build_dictionary.py`.
3. הריצו `flutter test` כדי לוודא שהכול עדיין תקין.
