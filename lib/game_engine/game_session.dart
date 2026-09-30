import 'dart:math';

import 'board_generator.dart';
import 'dictionary/hebrew_trie.dart';
import 'models/grid_position.dart';
import 'models/level_config.dart';
import 'word_finder.dart';

enum WordSubmitStatus { accepted, duplicate, tooShort, invalidWord, invalidPath }

class WordSubmitResult {
  final WordSubmitStatus status;
  final String? displayWord;
  final int pointsAwarded;

  const WordSubmitResult(this.status, {this.displayWord, this.pointsAwarded = 0});

  bool get isSuccess => status == WordSubmitStatus.accepted;
}

/// מייצג הפעלה אחת (session) של שלב במשחק היחיד-שחקן: הלוח, הניקוד,
/// והמילים שכבר נמצאו. זו לוגיקה טהורה ללא תלות ב-Flutter, כדי שתהיה
/// ניתנת לבדיקה (testable) בקלות.
class GameSession {
  final LevelConfig config;
  GeneratedBoard board;
  final HebrewTrie trie;

  final Set<String> _foundNormalizedWords = <String>{};
  int _score = 0;

  GameSession({required this.config, required this.board, required this.trie});

  int get score => _score;
  Set<String> get foundNormalizedWords => Set.unmodifiable(_foundNormalizedWords);
  int get foundWordsCount => _foundNormalizedWords.length;
  int get totalPossibleWords => board.possibleWords.length;
  int get totalPossibleScore => board.totalPossibleScore;

  bool get isFullyCompleted => _foundNormalizedWords.length >= board.possibleWords.length;

  /// מאמת נתיב שנבחר על ידי השחקן (רשימת מיקומים ברצף) ומעדכן ניקוד בהתאם.
  WordSubmitResult submitPath(List<GridPosition> path) {
    if (path.length < config.minWordLength) {
      return const WordSubmitResult(WordSubmitStatus.tooShort);
    }

    // ולידציית שרשור: כל תא חייב להיות שכן של קודמו, וללא חזרה על תא.
    final seen = <GridPosition>{};
    for (int i = 0; i < path.length; i++) {
      if (!seen.add(path[i])) {
        return const WordSubmitResult(WordSubmitStatus.invalidPath);
      }
      if (i > 0 && !path[i].isAdjacentTo(path[i - 1])) {
        return const WordSubmitResult(WordSubmitStatus.invalidPath);
      }
    }

    final word = path.map((p) => board.letters[p.row][p.col]).join();

    if (!trie.isWord(word)) {
      return const WordSubmitResult(WordSubmitStatus.invalidWord);
    }
    if (_foundNormalizedWords.contains(word)) {
      return WordSubmitResult(
        WordSubmitStatus.duplicate,
        displayWord: HebrewTrie.toDisplayWord(word),
      );
    }

    _foundNormalizedWords.add(word);
    final points = scoreForWordLength(word.length);
    _score += points;

    return WordSubmitResult(
      WordSubmitStatus.accepted,
      displayWord: HebrewTrie.toDisplayWord(word),
      pointsAwarded: points,
    );
  }

  /// מספר הכוכבים (0-3) לפי היחס בין הניקוד שנצבר ליעד השלב
  /// ([LevelConfig.scoreRequired]). שליש מהיעד = כוכב, היעד המלא = 3.
  static int starsForScore(int score, int required) {
    if (required <= 0) return score > 0 ? 3 : 0;
    final stars = (score * 3 / required).floor();
    return stars.clamp(0, 3);
  }

  int get currentStars => starsForScore(_score, config.scoreRequired);

  /// כמה נקודות עוד נותרו כדי להגיע ליעד השלב (0 אם היעד כבר הושג).
  int get pointsRemainingForGoal =>
      (config.scoreRequired - _score).clamp(0, config.scoreRequired);

  bool get hasReachedScoreGoal => _score >= config.scoreRequired;

  /// מדגיש אות אחת ממילה שטרם נמצאה, בלי לחשוף את המילה כולה.
  GridPosition? letterHintPosition({Random? random}) {
    final word = hintForUnfoundWord(random: random);
    if (word == null || word.path.isEmpty) return null;
    final rnd = random ?? Random();
    return word.path[rnd.nextInt(word.path.length)];
  }

  /// מערבב את מיקום האותיות ומחשב מחדש את המילים האפשריות.
  /// הניקוד והמילים שכבר נמצאו נשמרים.
  void reshuffleLetters(Random random) {
    final flat = [for (final row in board.letters) ...row]..shuffle(random);
    final size = board.size;
    final letters = <List<String>>[
      for (var r = 0; r < size; r++) List<String>.from(flat.sublist(r * size, (r + 1) * size)),
    ];
    final words = WordFinder(trie, minWordLength: config.minWordLength).findAllWords(letters);
    board = GeneratedBoard(letters: letters, possibleWords: words, size: size);
  }

  /// בוחר מילה שטרם נמצאה עבור מנגנון הרמזים - מעדיפים את המילים
  /// הקצרות/קלות שנותרו (כדי שהרמז יעזור אך לא "יפתור" את כל השלב),
  /// ובוחרים אקראית מתוכן כדי שלא תמיד יוצע אותו רמז.
  FoundWord? hintForUnfoundWord({Random? random}) {
    final remaining = board.possibleWords
        .where((w) => !_foundNormalizedWords.contains(w.normalizedWord))
        .toList();
    if (remaining.isEmpty) return null;

    remaining.sort((a, b) => a.normalizedWord.length.compareTo(b.normalizedWord.length));
    final shortestLength = remaining.first.normalizedWord.length;
    final easiest = remaining.where((w) => w.normalizedWord.length == shortestLength).toList();

    final rnd = random ?? Random();
    return easiest[rnd.nextInt(easiest.length)];
  }
}
