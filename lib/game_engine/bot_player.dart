import 'dart:math';

import 'board_generator.dart';
import 'word_finder.dart';

enum BotDifficulty { easy, normal, hard }

extension BotDifficultyX on BotDifficulty {
  String get labelHe {
    switch (this) {
      case BotDifficulty.easy:
        return 'קליל';
      case BotDifficulty.normal:
        return 'בינוני';
      case BotDifficulty.hard:
        return 'מומחה';
    }
  }

  /// טווח (מינימום, מקסימום) שניות בין מציאת מילה למילה - כך "בוט מומחה"
  /// מוצא מילים בתדירות גבוהה יותר מ"בוט קליל", בלי להיות דטרמיניסטי מדי.
  (double, double) get secondsBetweenFinds {
    switch (this) {
      case BotDifficulty.easy:
        return (7, 16);
      case BotDifficulty.normal:
        return (4, 10);
      case BotDifficulty.hard:
        return (2, 6);
    }
  }
}

/// מדמה שחקן/ית וירטואלי/ת במצב "תחרות מקומית" (ראה
/// lib/features/multiplayer) - "מוצא" מילים מתוך רשימת המילים האפשריות
/// בלוח בקצב אקראי-מבוקר לפי רמת קושי, כדי לאפשר תחרות 2-4 משתתפים
/// גם ללא שרת רב-משתתפים אמיתי (ראו docs/FIREBASE_SETUP.md להרחבה עתידית
/// לרשת אמיתית בין מכשירים).
class BotPlayer {
  final String name;
  final BotDifficulty difficulty;
  final Random _random;

  final List<FoundWord> _remainingWords;
  final Set<String> foundNormalizedWords = <String>{};
  int score = 0;

  Duration _sinceLastFind = Duration.zero;
  late Duration _nextFindIn;

  BotPlayer({
    required this.name,
    required this.difficulty,
    required GeneratedBoard board,
    Random? random,
  })  : _random = random ?? Random(),
        _remainingWords = List<FoundWord>.of(board.possibleWords) {
    _remainingWords.shuffle(_random);
    _nextFindIn = _rollNextInterval();
  }

  Duration _rollNextInterval() {
    final (min, max) = difficulty.secondsBetweenFinds;
    final seconds = min + _random.nextDouble() * (max - min);
    return Duration(milliseconds: (seconds * 1000).round());
  }

  /// יש לקרוא בכל "טיק" של הטיימר עם הזמן שחלף. מחזיר מילה חדשה שנמצאה
  /// בטיק הזה (אם נמצאה), אחרת null.
  FoundWord? tick(Duration delta) {
    if (_remainingWords.isEmpty) return null;

    _sinceLastFind += delta;
    if (_sinceLastFind < _nextFindIn) return null;

    _sinceLastFind = Duration.zero;
    _nextFindIn = _rollNextInterval();

    final word = _remainingWords.removeAt(0);
    foundNormalizedWords.add(word.normalizedWord);
    score += scoreForWordLength(word.normalizedWord.length);
    return word;
  }
}
