import 'dart:math';

import 'board_generator.dart';
import 'dictionary/common_word_pool.dart';
import 'dictionary/hebrew_trie.dart';
import 'models/grid_position.dart';
import 'models/level_config.dart';
import 'word_finder.dart';

/// מילה שהוצבה בהצלחה על הלוח בזמן הבנייה (מתוך מאגר המילים הנוחות) -
/// כולל הנתיב שלה, כדי שנוכל להשתמש בה מאוחר יותר להדגמת טוטוריאל
/// (ראו tutorialWord/tutorialPath ב-tool/generate_level_boards.dart).
class PlacedWord {
  final String normalizedWord;
  final List<GridPosition> path;

  const PlacedWord(this.normalizedWord, this.path);
}

/// תוצאת בניית לוח לשלב בודד: הלוח עצמו (כולל כל המילים האפשריות שנמצאו
/// בו), וכל המילים המוכרות שהוצבו בו בכוונה (anchors) לצורך טוטוריאל/דיבוג.
class LevelBoardResult {
  final GeneratedBoard board;
  final List<PlacedWord> anchors;

  const LevelBoardResult({required this.board, required this.anchors});
}

/// פרופיל הקושי של בניית לוח לשלב נתון - נגזר אוטומטית מהמיקום של השלב
/// בתוך "עשיריית" העולם שלו (ראו [CampaignLevels.positionWithinTier]):
/// 0 = השלב הראשון/הכי-קל של העולם (הרבה עוגני מילים מוכרות, יחס גבוה
/// של מילים מוכרות), ועד 1.0 = השלב האחרון/הכי-קשה (מעט עוגנים, מותר
/// יחס גבוה יותר של מילים לא-מוכרות מהמילון המורחב).
class BoardDifficultyProfile {
  final int anchorWordCount;
  final double targetCommonRatio;
  final int minWordsRequired;

  const BoardDifficultyProfile({
    required this.anchorWordCount,
    required this.targetCommonRatio,
    required this.minWordsRequired,
  });

  factory BoardDifficultyProfile.forLevel(LevelConfig config) {
    final blockSize = CampaignLevels.tierBlockSize(config.levelNumber);
    final position = CampaignLevels.positionWithinTier(config.levelNumber);
    final t = blockSize <= 1 ? 0.0 : position / (blockSize - 1);

    // 5 עוגנים בשלב הראשון של העולם -> 2 עוגנים בשלב האחרון.
    final anchorWordCount = (5 - t * 3).round().clamp(2, 5);
    // 90% מילים מוכרות בשלב הראשון -> 50% בשלב האחרון (רצפת יעד, לא חובה מוחלטת).
    final targetCommonRatio = 0.9 - t * 0.4;

    return BoardDifficultyProfile(
      anchorWordCount: anchorWordCount,
      targetCommonRatio: targetCommonRatio,
      minWordsRequired: 5 + config.gridSize,
    );
  }
}

/// בונה לוחות "פתירים ונוחים" לשלבי הקמפיין, בשיטה היברידית:
///
/// 1. **עיגון (constructive)** - בוחר מילות-מטרה ממאגר המילים הנוחות
///    ([CommonWordPool]) בטווח אורך שמתאים לגודל הלוח, ומנסה להציב אותן
///    על הלוח בנתיב שכנים תקין (8 כיוונים, בלי חזרה על תא) - בדומה
///    לבניית פאזל "תשבץ מילים" (word search), כולל חפיפה בין מילים
///    שחולקות אותיות במקומות משותפים.
/// 2. **ניקוד איכות (scored)** - שאר התאים מתמלאים באותיות משוקללות לפי
///    תדירות טבעית, ולאחר מכן מריצים [WordFinder] כדי לספור את כל
///    המילים שבאמת ניתן למצוא בלוח הסופי (כולל מילים "בונוס" שלא תוכננו
///    בכוונה). מריצים כמה ניסיונות (מזורעים דטרמיניסטית לפי מספר השלב)
///    ובוחרים את הלוח בעל יחס-המילים-המוכרות/כמות-המילים הגבוה ביותר.
///
/// כל הפעולה דטרמיניסטית לחלוטין: אותו [LevelConfig.levelNumber] מייצר
/// תמיד בדיוק את אותו לוח, על כל מכשיר/פלטפורמה - ראו
/// tool/generate_level_boards.dart שמריץ את זה מראש (build-time) ושומר
/// את התוצאה כ-asset קבוע (assets/boards/level_boards.json).
class LevelBoardBuilder {
  final HebrewTrie trie;
  final Map<String, double> letterWeights;
  final CommonWordPool commonWords;

  LevelBoardBuilder({
    required this.trie,
    required this.letterWeights,
    required this.commonWords,
  });

  late final WordFinder _finder = WordFinder(trie);
  late final List<String> _letters = letterWeights.keys.toList();
  late final List<double> _cumulativeWeights = _buildCumulativeWeights();

  List<double> _buildCumulativeWeights() {
    double running = 0;
    final list = <double>[];
    for (final l in _letters) {
      running += letterWeights[l] ?? 0.01;
      list.add(running);
    }
    return list;
  }

  String _randomLetter(Random random) {
    final total = _cumulativeWeights.isEmpty ? 0 : _cumulativeWeights.last;
    final r = random.nextDouble() * total;
    for (int i = 0; i < _cumulativeWeights.length; i++) {
      if (r <= _cumulativeWeights[i]) return _letters[i];
    }
    return _letters.isNotEmpty ? _letters.last : 'א';
  }

  /// בונה לוח קבוע לשלב נתון. דטרמיניסטי לפי [config.levelNumber] בלבד
  /// (אלא אם מועבר [seedOffset] מפורש, שימושי רק לבדיקות/דיבוג).
  LevelBoardResult buildForLevel(
    LevelConfig config, {
    int seedOffset = 0,
    int seedAttempts = 60,
    int placementAttemptsPerWord = 50,
  }) {
    final profile = BoardDifficultyProfile.forLevel(config);

    LevelBoardResult? best;
    double bestScore = -1;

    for (int attempt = 0; attempt < seedAttempts; attempt++) {
      final random = Random(config.levelNumber * 92821 + seedOffset * 7919 + attempt);
      final result = _buildOneAttempt(config, profile, random, placementAttemptsPerWord);
      if (result == null) continue;

      final wordCount = result.board.possibleWords.length;
      if (wordCount < profile.minWordsRequired) continue;

      final score = _qualityScore(result.board, profile);
      if (score > bestScore) {
        bestScore = score;
        best = result;
      }

      final commonRatio = _commonRatio(result.board);
      if (commonRatio >= profile.targetCommonRatio) {
        return result; // מספיק טוב - אין צורך להמשיך לחפש.
      }
    }

    if (best != null) return best;

    // רשת אחרונה לבטיחות (לא אמורה לקרות בפועל עם מילון של 65K מילים):
    // בונה לוח רנדומלי טהור בשיטה הישנה, שרק סופרת כמות מילים.
    final fallback = BoardGenerator(trie: trie, letterWeights: letterWeights).generate(
      size: config.gridSize,
      minWordsRequired: profile.minWordsRequired,
    );
    return LevelBoardResult(board: fallback, anchors: const []);
  }

  double _commonRatio(GeneratedBoard board) {
    if (board.possibleWords.isEmpty) return 0;
    final common =
        board.possibleWords.where((w) => commonWords.isCommon(w.normalizedWord)).length;
    return common / board.possibleWords.length;
  }

  double _qualityScore(GeneratedBoard board, BoardDifficultyProfile profile) {
    final total = board.possibleWords.length;
    final common =
        board.possibleWords.where((w) => commonWords.isCommon(w.normalizedWord)).length;
    final rare = total - common;
    // מתגמל מילים מוכרות (משקל כפול), ורק "קונס" עודף גדול של מילים
    // נדירות (מעבר ל-12) כדי לא לתת ללוח להיות מוצף כולו במילים לא-מוכרות
    // מהמילון המורחב - בלי לפסול לוחות עם כמה מילים נדירות "בונוס".
    final rarePenalty = rare > 12 ? (rare - 12) : 0;
    return common * 3.0 + total - rarePenalty;
  }

  LevelBoardResult? _buildOneAttempt(
    LevelConfig config,
    BoardDifficultyProfile profile,
    Random random,
    int placementAttemptsPerWord,
  ) {
    final size = config.gridSize;
    final maxAnchorLen = min(size * size, size + 3);
    final candidates = commonWords.wordsWithLengthBetween(2, maxAnchorLen);
    if (candidates.isEmpty) return null;

    final shuffled = List<String>.from(candidates)..shuffle(random);
    final targetWords = <String>{};
    for (final word in shuffled) {
      if (targetWords.length >= profile.anchorWordCount) break;
      targetWords.add(word);
    }

    final grid = List.generate(size, (_) => List<String?>.filled(size, null));
    final placed = <PlacedWord>[];

    // מילים ארוכות יותר קודם - קשה יותר להציב אותן כשיש פחות מקום פנוי.
    final orderedTargets = targetWords.toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    for (final word in orderedTargets) {
      final path = _tryPlaceWord(grid, word, random, placementAttemptsPerWord);
      if (path != null) {
        placed.add(PlacedWord(word, path));
      }
    }

    final finalLetters = List.generate(
      size,
      (r) => List.generate(size, (c) => grid[r][c] ?? _randomLetter(random)),
    );

    final possibleWords = _finder.findAllWords(finalLetters);
    final board = GeneratedBoard(letters: finalLetters, possibleWords: possibleWords, size: size);
    return LevelBoardResult(board: board, anchors: placed);
  }

  /// מנסה להציב מילה בודדת על הלוח בנתיב שכנים תקין (הליכה אקראית), עם
  /// אפשרות חפיפה עם אותיות שכבר הוצבו (אם הן תואמות) - בדומה לבניית
  /// תשבץ מילים קלאסי. מחזיר את הנתיב אם הצליח, או null אם לא נמצא מקום
  /// מתאים בתוך מספר הניסיונות שהוקצב.
  List<GridPosition>? _tryPlaceWord(
    List<List<String?>> grid,
    String word,
    Random random,
    int attempts,
  ) {
    final size = grid.length;
    final letters = word.split('');

    for (int attempt = 0; attempt < attempts; attempt++) {
      final start = GridPosition(random.nextInt(size), random.nextInt(size));
      if (!_cellCompatible(grid, start, letters[0])) continue;

      final path = <GridPosition>[start];
      bool ok = true;

      for (int i = 1; i < letters.length; i++) {
        final last = path.last;
        final neighbors = last.rawNeighbors
            .where((n) =>
                n.row >= 0 &&
                n.row < size &&
                n.col >= 0 &&
                n.col < size &&
                !path.contains(n) &&
                _cellCompatible(grid, n, letters[i]))
            .toList()
          ..shuffle(random);

        if (neighbors.isEmpty) {
          ok = false;
          break;
        }
        path.add(neighbors.first);
      }

      if (ok) {
        for (int i = 0; i < letters.length; i++) {
          grid[path[i].row][path[i].col] = letters[i];
        }
        return path;
      }
    }
    return null;
  }

  bool _cellCompatible(List<List<String?>> grid, GridPosition pos, String letter) {
    final existing = grid[pos.row][pos.col];
    return existing == null || existing == letter;
  }
}
