import 'dart:math';

import 'dictionary/hebrew_trie.dart';
import 'word_finder.dart';

/// תוצאת יצירת לוח: רשת האותיות + כל המילים האפשריות שנמצאו בה מראש,
/// כדי שנוכל להציג "יעד" (למשל X מילים / Y נקודות) ומסך תוצאות מדויק.
class GeneratedBoard {
  final List<List<String>> letters;
  final List<FoundWord> possibleWords;
  final int size;

  const GeneratedBoard({
    required this.letters,
    required this.possibleWords,
    required this.size,
  });

  int get totalPossibleScore {
    return possibleWords.fold(0, (sum, w) => sum + scoreForWordLength(w.normalizedWord.length));
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

/// יוצר לוחות אותיות "פתירים" (כאלה שמכילים מספיק מילים חוקיות) עבור
/// המילון העברי המנורמל שלנו, תוך שימוש בהתפלגות תדירות אותיות אמיתית
/// כדי שהלוח ירגיש טבעי ולא אקראי לגמרי.
class BoardGenerator {
  final HebrewTrie trie;
  final Map<String, double> letterWeights;
  final Random random;

  BoardGenerator({
    required this.trie,
    required this.letterWeights,
    Random? random,
  }) : random = random ?? Random();

  late final List<String> _letters = letterWeights.keys.toList();
  late final List<double> _cumulativeWeights = _buildCumulative();

  List<double> _buildCumulative() {
    double running = 0;
    final list = <double>[];
    for (final l in _letters) {
      running += letterWeights[l] ?? 0.01;
      list.add(running);
    }
    return list;
  }

  String _randomLetter() {
    final total = _cumulativeWeights.isEmpty ? 0 : _cumulativeWeights.last;
    final r = random.nextDouble() * total;
    for (int i = 0; i < _cumulativeWeights.length; i++) {
      if (r <= _cumulativeWeights[i]) return _letters[i];
    }
    return _letters.isNotEmpty ? _letters.last : 'א';
  }

  List<List<String>> _randomGrid(int size) {
    return List.generate(
      size,
      (_) => List.generate(size, (_) => _randomLetter()),
    );
  }

  /// מייצר לוח בגודל נתון, ומוודא (בעזרת ניסיונות חוזרים) שיש בו לפחות
  /// [minWordsRequired] מילים חוקיות ונקודות פוטנציאליות מספקות.
  /// אם לא הצלחנו במספר הניסיונות המוגדר - מחזירים את הלוח הכי טוב שנמצא.
  GeneratedBoard generate({
    required int size,
    int minWordsRequired = 6,
    int maxAttempts = 60,
  }) {
    final finder = WordFinder(trie);
    GeneratedBoard? best;

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final grid = _randomGrid(size);
      final words = finder.findAllWords(grid);
      final candidate = GeneratedBoard(letters: grid, possibleWords: words, size: size);

      if (best == null || candidate.possibleWords.length > best.possibleWords.length) {
        best = candidate;
      }
      if (candidate.possibleWords.length >= minWordsRequired) {
        return candidate;
      }
    }
    return best!;
  }
}
