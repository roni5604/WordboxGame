import 'dictionary/hebrew_trie.dart';

/// "אותיות קשות" - אותיות שמופיעות בפחות מילים, ולכן קשה יותר לשלב אותן
/// במילה. הן נצבעות בצבע שונה על הלוח, וכל שימוש בהן במילה שווה נקודה
/// נוספת ([bonusPerLetter]).
///
/// הבחירה מבוססת על המילון של המשחק (assets/dictionaries/common_words.json):
/// אחוז המילים המוכרות שמכילות כל אות -
/// ז 4.6%, ט 6.9%, צ 7.7%, ג 9.4%, ס 9.7%, ק 12.2%, פ 13.8%,
/// לעומת י 44.6%, ו 42%, מ 40.6%, ר 28.7%. ק ו-פ נפוצות מעט יותר מהשאר,
/// אבל רוב המילים שלהן ארוכות ולא נוחות על לוח קטן, אז גם הן בפנים.
///
/// הבונוס קטן בכוונה: בערך 6%-7% מהניקוד שאפשר להשיג בלוח טיפוסי. הוא לא
/// משנה את הקושי של השלב, אבל נותן סיבה לחפש מילה עם ק/צ/ז במקום עוד
/// מילה קצרה עם י/ו.
class HardLetters {
  HardLetters._();

  static const Set<String> letters = {'ז', 'ט', 'צ', 'ג', 'ס', 'ק', 'פ'};

  static const int bonusPerLetter = 1;

  /// האם [letter] היא אות קשה. מקבל גם צורה סופית (ץ/ף).
  static bool isHard(String letter) => letters.contains(kSofitToBase[letter] ?? letter);

  /// הבונוס של מילה (מנורמלת או בצורת תצוגה): נקודה לכל אות קשה בה.
  static int bonusFor(String word) {
    var count = 0;
    for (final ch in word.split('')) {
      if (isHard(ch)) count++;
    }
    return count * bonusPerLetter;
  }
}

/// ניקוד למילה לפי אורכה - ככל שהמילה ארוכה יותר כך שווה יותר נקודות,
/// עם בונוס מוגבר (לא ליניארי) למילים ארוכות כדי לתגמל חשיבה יצירתית.
int scoreForWordLength(int length) {
  switch (length) {
    case 0:
    case 1:
      return 0;
    case 2:
      return 1;
    case 3:
      return 3;
    case 4:
      return 6;
    case 5:
      return 10;
    case 6:
      return 15;
    case 7:
      return 21;
    default:
      return 21 + (length - 7) * 8;
  }
}

/// הניקוד המלא של מילה: לפי האורך, ועוד בונוס על אותיות קשות. זה הניקוד
/// בכל מצבי המשחק (קמפיין, אתגר יומי, מול המחשב ומול חברים).
int scoreForWord(String normalizedWord) =>
    scoreForWordLength(normalizedWord.length) + HardLetters.bonusFor(normalizedWord);
