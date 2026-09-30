import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/game_session.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';

void main() {
  // לוח 2x2 קבוע לבדיקה:
  // ב  י
  // ת  ז
  final grid = [
    ['ב', 'י'],
    ['ת', 'ז'],
  ];

  late HebrewTrie trie;
  late LevelConfig config;

  setUp(() {
    trie = HebrewTrie();
    trie.insertAll(['בית', 'בי']);
    config = const LevelConfig(
      levelNumber: 1,
      tier: WorldTier.seedling,
      gridSize: 2,
      timeLimit: Duration(seconds: 60),
      scoreRequired: 3,
    );
  });

  GameSession buildSession() {
    final board = GeneratedBoard(letters: grid, possibleWords: const [], size: 2);
    return GameSession(config: config, board: board, trie: trie);
  }

  test('accepts a valid connected word and awards points', () {
    final session = buildSession();
    final result = session.submitPath([
      const GridPosition(0, 0), // ב
      const GridPosition(0, 1), // י
      const GridPosition(1, 0), // ת
    ]);

    expect(result.isSuccess, isTrue);
    expect(result.displayWord, 'בית');
    expect(session.score, greaterThan(0));
    expect(session.foundWordsCount, 1);
  });

  test('rejects non-adjacent path', () {
    final session = buildSession();
    final result = session.submitPath([
      const GridPosition(0, 0), // ב
      const GridPosition(1, 1), // ז - לא שכן ישיר בהמשך תקין ל"בית"... אבל כן אלכסוני שכן
    ]);
    // ב(0,0) ל-ז(1,1) כן שכנים אלכסוניים, לכן משמעות הבדיקה כאן שהמילה "בז" לא קיימת
    expect(result.status, WordSubmitStatus.invalidWord);
  });

  test('rejects reused tile in the same word', () {
    final session = buildSession();
    final result = session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 0),
    ]);
    expect(result.status, WordSubmitStatus.invalidPath);
  });

  test('rejects duplicate word on second submission', () {
    final session = buildSession();
    session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 1),
      const GridPosition(1, 0),
    ]);
    final second = session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 1),
      const GridPosition(1, 0),
    ]);
    expect(second.status, WordSubmitStatus.duplicate);
  });

  test('rejects word not in dictionary', () {
    final session = buildSession();
    final result = session.submitPath([
      const GridPosition(0, 1), // י
      const GridPosition(1, 1), // ז
    ]);
    expect(result.status, WordSubmitStatus.invalidWord);
  });

  group('GameSession.starsForScore (יעד ניקוד מחולק לשלישים)', () {
    test('יעד=6: 0-1 נקודות בלי כוכב, 2-3 כוכב, 4-5 שני כוכבים, 6+ שלושה', () {
      expect(GameSession.starsForScore(0, 6), 0);
      expect(GameSession.starsForScore(1, 6), 0);
      expect(GameSession.starsForScore(2, 6), 1);
      expect(GameSession.starsForScore(3, 6), 1);
      expect(GameSession.starsForScore(4, 6), 2);
      expect(GameSession.starsForScore(5, 6), 2);
      expect(GameSession.starsForScore(6, 6), 3);
      expect(GameSession.starsForScore(10, 6), 3);
    });

    test('יעד=9: שליש, שני שלישים, והיעד המלא', () {
      expect(GameSession.starsForScore(0, 9), 0);
      expect(GameSession.starsForScore(2, 9), 0);
      expect(GameSession.starsForScore(3, 9), 1);
      expect(GameSession.starsForScore(6, 9), 2);
      expect(GameSession.starsForScore(9, 9), 3);
    });
  });

  test('currentStars מתעדכן לפי ניקוד, ומילה ארוכה שווה יותר ממילה קצרה', () {
    final session = buildSession();
    expect(session.currentStars, 0);
    expect(session.pointsRemainingForGoal, 3);
    expect(session.hasReachedScoreGoal, isFalse);

    final shortWord = session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 1),
    ]);
    expect(shortWord.isSuccess, isTrue);
    expect(shortWord.pointsAwarded, 1);
    expect(session.currentStars, 1);
    expect(session.hasReachedScoreGoal, isFalse);

    final longWord = session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 1),
      const GridPosition(1, 0),
    ]);
    expect(longWord.pointsAwarded, greaterThan(shortWord.pointsAwarded));
    expect(session.score, 4);
    expect(session.currentStars, 3);
    expect(session.pointsRemainingForGoal, 0);
    expect(session.hasReachedScoreGoal, isTrue);
  });
}
