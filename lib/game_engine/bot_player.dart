import 'dart:math';

import 'board_generator.dart';
import 'word_finder.dart';

enum BotDifficulty { easy, normal, hard }

/// "אופי" של רמה: כמה מילים הבוט בכלל מכיר, כמה מהר הוא חושב, וכמה הוא
/// אוהב מילים ארוכות. הערכים כוילו כך שגם "מומחה" אנושי ובר-ניצוח -
/// הוא מוצא כ-40% מהמילים בלוח, לא את כולן.
class BotStyle {
  /// חלק המילים בלוח שהבוט מסוגל למצוא בכלל (שאר המילים "לא עולות לו בראש").
  final double coverage;

  /// זמן חשיבה בסיסי (שניות) למילה של 3 אותיות - חציון של התפלגות log-normal.
  final double baseSeconds;

  /// תוספת שניות לכל אות מעבר ל-3 (מילה ארוכה = יותר זמן לראות אותה).
  final double perExtraLetter;

  /// עד כמה הבוט מעדיף מילים קצרות (1 = מאוד, 0 = לא אכפת לו).
  final double shortBias;

  /// זמן "התחממות" לפני המילה הראשונה (טווח בשניות).
  final (double, double) warmup;

  /// הסתברות ל"רצף" - אחרי מילה, מילה נוספת מהר במיוחד (כמו "אה, וגם...").
  final double streakChance;

  /// הסתברות ל"תקיעה" - הפסקה ארוכה בלי מילים.
  final double stuckChance;

  const BotStyle({
    required this.coverage,
    required this.baseSeconds,
    required this.perExtraLetter,
    required this.shortBias,
    required this.warmup,
    required this.streakChance,
    required this.stuckChance,
  });
}

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

  BotStyle get style => switch (this) {
    BotDifficulty.easy => const BotStyle(
      coverage: 0.14,
      baseSeconds: 17,
      perExtraLetter: 5,
      shortBias: 0.9,
      warmup: (6, 11),
      streakChance: 0.05,
      stuckChance: 0.22,
    ),
    BotDifficulty.normal => const BotStyle(
      coverage: 0.26,
      baseSeconds: 9.5,
      perExtraLetter: 3.2,
      shortBias: 0.65,
      warmup: (4, 8),
      streakChance: 0.1,
      stuckChance: 0.15,
    ),
    BotDifficulty.hard => const BotStyle(
      coverage: 0.4,
      baseSeconds: 5,
      perExtraLetter: 1.8,
      shortBias: 0.35,
      warmup: (3, 6),
      streakChance: 0.16,
      stuckChance: 0.1,
    ),
  };
}

/// יריב וירטואלי שמתנהג כמו אדם: לא "יורה" מילים בקצב קבוע, אלא חושב.
///
/// * **מה הוא מכיר**: מתוך כל המילים בלוח הוא "רואה" רק חלק ([BotStyle.coverage]),
///   ומעדיף מילים מוכרות וקצרות - כמו שחקן/ית אמיתי/ת.
/// * **כמה זמן לוקח**: זמן החשיבה לכל מילה נדגם מהתפלגות log-normal
///   (רוב הפעמים קרוב לממוצע, לפעמים מהר מאוד, לפעמים איטי), וגדל עם
///   אורך המילה.
/// * **התנהגות**: התחממות בהתחלה, "רצפים" (מילה גוררת מילה), "תקיעות"
///   ארוכות, ועייפות קלה ככל שהמילים הקלות נגמרות.
/// * **מבין את המשתמש**: מאזין לקצב של השחקן/ית ([tick] עם humanScore) -
///   כשהבוט בורח קדימה הוא מאט, וכשהוא הרבה מאחור הוא מתאמץ קצת. כך
///   התחרות נשארת צמודה ומרגשת, בלי שהבוט ירגיש "מרומה".
class BotPlayer {
  final String name;
  final BotDifficulty difficulty;
  final Random _random;
  final BotStyle _style;

  /// המילים שהבוט "יכול" למצוא, לפי סדר הגילוי שלו.
  final List<FoundWord> _queue;

  /// כל המילים שנמצאו, לפי הסדר (לחשיפת "המילים של היריב").
  final List<FoundWord> foundWords = [];
  final Set<String> foundNormalizedWords = <String>{};
  int score = 0;

  Duration _elapsed = Duration.zero;
  Duration _sinceLastFind = Duration.zero;
  late Duration _nextFindIn;
  int _humanScore = 0;

  /// האם הבוט "תקוע" כרגע (להערות: "חושב...").
  bool get isThinkingHard => _stuck;
  bool _stuck = false;

  BotPlayer({
    required this.name,
    required this.difficulty,
    required GeneratedBoard board,
    Random? random,
    bool Function(String normalizedWord)? isFamiliar,
  }) : _random = random ?? Random(),
       _style = difficulty.style,
       _queue = [] {
    _queue.addAll(_pickWords(board.possibleWords, isFamiliar));
    // התחממות + הזמן "לראות" את המילה הראשונה (מילה ארוכה = יותר זמן).
    final (lo, hi) = _style.warmup;
    final firstLen = _queue.isEmpty ? 3 : _queue.first.normalizedWord.length;
    _nextFindIn = _seconds(lo + _random.nextDouble() * (hi - lo) + max(0, firstLen - 3) * _style.perExtraLetter);
  }

  /// בוחר אילו מילים הבוט "מכיר" ובאיזה סדר ימצא אותן: משקל לכל מילה לפי
  /// קוצר ומוכרות, ואז דגימה משוקללת בלי החזרה (Efraimidis-Spirakis).
  List<FoundWord> _pickWords(List<FoundWord> all, bool Function(String)? isFamiliar) {
    if (all.isEmpty) return [];
    final keyed = <(double, FoundWord)>[];
    for (final w in all) {
      final len = w.normalizedWord.length;
      var weight = pow(1.0 / max(1, len - 1), _style.shortBias * 1.6).toDouble();
      if (isFamiliar?.call(w.normalizedWord) ?? true) {
        weight *= 3;
      }
      final u = max(_random.nextDouble(), 1e-9);
      keyed.add((pow(u, 1 / weight).toDouble(), w));
    }
    keyed.sort((a, b) => b.$1.compareTo(a.$1));
    final take = max(2, (all.length * _style.coverage).round());
    return [for (final k in keyed.take(take)) k.$2];
  }

  Duration _seconds(double s) => Duration(milliseconds: (s * 1000).round());

  /// דגימה מהתפלגות נורמלית סטנדרטית (Box-Muller).
  double _gaussian() {
    final u1 = max(_random.nextDouble(), 1e-12);
    final u2 = _random.nextDouble();
    return sqrt(-2 * log(u1)) * cos(2 * pi * u2);
  }

  /// כמה זמן ייקח למצוא את המילה הבאה בתור.
  Duration _rollNext() {
    _stuck = false;
    if (_queue.isEmpty) return const Duration(days: 1);
    final next = _queue.first.normalizedWord.length;
    var median = _style.baseSeconds + max(0, next - 3) * _style.perExtraLetter;

    // עייפות: ככל שמצא יותר, המילים שנשארו "קשות לראות".
    median *= 1 + foundWords.length * 0.06;

    // התאמה לשחקן/ית: מאט כשהוא בורח קדימה (חזק יותר כשהשחקן/ית עוד לא
    // מצא/ה כלום - כדי לא לשבור מתחילים), מזדרז מעט כשהוא מאחור.
    final lead = score - _humanScore;
    if (lead > 4) {
      final ease = _humanScore == 0 ? 8 : 14;
      median *= 1 + min(2.0, lead / ease);
    } else if (lead < -10) {
      median *= max(0.75, 1 - (-lead - 10) / 60);
    }

    var seconds = median * exp(_gaussian() * 0.45);
    final roll = _random.nextDouble();
    if (foundWords.isNotEmpty && roll < _style.streakChance) {
      seconds = 1.2 + _random.nextDouble() * 2; // "אה, וגם..."
    } else if (roll > 1 - _style.stuckChance) {
      _stuck = true;
      seconds += 8 + _random.nextDouble() * 10; // נתקע ומסתכל על הלוח
    }
    return _seconds(seconds.clamp(1.2, 60.0));
  }

  /// יש לקרוא בכל "טיק" של הטיימר עם הזמן שחלף והניקוד הנוכחי של
  /// השחקן/ית. מחזיר מילה שנמצאה בטיק הזה (אם נמצאה), אחרת null.
  FoundWord? tick(Duration delta, {int humanScore = 0}) {
    _humanScore = humanScore;
    _elapsed += delta;
    if (_queue.isEmpty) return null;

    _sinceLastFind += delta;
    if (_sinceLastFind < _nextFindIn) return null;

    _sinceLastFind = Duration.zero;
    final word = _queue.removeAt(0);
    foundWords.add(word);
    foundNormalizedWords.add(word.normalizedWord);
    score += scoreForWord(word.normalizedWord);
    _nextFindIn = _rollNext();
    return word;
  }

  /// כמה זמן עבר מאז המילה האחרונה (להערות "שקט" מהבוט).
  Duration get sinceLastFind => _sinceLastFind;

  Duration get elapsed => _elapsed;
}
