import 'board_generator.dart';
import 'dictionary/hebrew_trie.dart';
import 'models/grid_position.dart';
import 'models/level_config.dart';

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
  final GeneratedBoard board;
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

  /// מספר הכוכבים (0-3) שהושגו לפי הניקוד הנוכחי.
  int starsForScore(int score) {
    if (score >= config.threeStarScore) return 3;
    if (score >= config.twoStarScore) return 2;
    if (score >= config.oneStarScore) return 1;
    return 0;
  }

  int get currentStars => starsForScore(_score);
}
