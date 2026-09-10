/// מאגר "מילים נוחות/מוכרות" - תת-קבוצה קטנה ומאוצרת (curated) של מילון
/// המשחק (ראו tool/build_common_words.py + tool/seed_words_raw.txt), המשמש
/// את [LevelBoardBuilder] (lib/game_engine/level_board_builder.dart) כדי:
///
/// 1. לעגן (anchor) מילים ידועות בלוחות של שלבים מוקדמים, כך שהלוח מכיל
///    בכטוח כמה מילים מוכרות וקלות למציאה, ולא רק "כמה שיהיה" מילים
///    כלשהן מהמילון המלא (65K, שמכיל גם הרבה נטיות/צורות נדירות).
/// 2. לדרג איכות לוח - יחס המילים המוכרות מתוך כל המילים הניתנות למצוא.
///
/// מחלקה טהורה ב-Dart בלבד (בלי תלות ב-Flutter) כדי שתהיה שמישה גם
/// מסקריפט build-time טהור (tool/generate_level_boards.dart) וגם מהאפליקציה
/// (דרך lib/providers/common_word_pool_provider.dart).
class CommonWordPool {
  final Set<String> _normalizedWords;

  const CommonWordPool(this._normalizedWords);

  bool isCommon(String normalizedWord) => _normalizedWords.contains(normalizedWord);

  int get size => _normalizedWords.length;

  /// כל המילים המוכרות, מסוננות לפי טווח אורך נתון - שימושי לבחירת מילות
  /// "עוגן" שסביר להצליח למקם על לוח בגודל נתון.
  List<String> wordsWithLengthBetween(int minLength, int maxLength) {
    return _normalizedWords
        .where((w) => w.length >= minLength && w.length <= maxLength)
        .toList()
      ..sort();
  }
}
