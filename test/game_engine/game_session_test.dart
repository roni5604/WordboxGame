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
      wordsRequired: 1,
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

  group('GameSession.starsForWordCount (יעד מילים מחולק לשלישים, לא ניקוד)', () {
    // הדוגמה המפורשת: יעד של 6 מילים -> כל 2 מילים שווה כוכב.
    test('דוגמת יעד=6: 0/1 מילים -> 0 כוכבים, 2/3 -> כוכב, 4/5 -> 2 כוכבים, 6+ -> 3 כוכבים', () {
      expect(GameSession.starsForWordCount(0, 6), 0);
      expect(GameSession.starsForWordCount(1, 6), 0);
      expect(GameSession.starsForWordCount(2, 6), 1);
      expect(GameSession.starsForWordCount(3, 6), 1);
      expect(GameSession.starsForWordCount(4, 6), 2);
      expect(GameSession.starsForWordCount(5, 6), 2);
      expect(GameSession.starsForWordCount(6, 6), 3);
      expect(GameSession.starsForWordCount(10, 6), 3);
    });

    test('שלב 1 (יעד=3): כל מילה שווה כוכב', () {
      expect(GameSession.starsForWordCount(0, 3), 0);
      expect(GameSession.starsForWordCount(1, 3), 1);
      expect(GameSession.starsForWordCount(2, 3), 2);
      expect(GameSession.starsForWordCount(3, 3), 3);
    });

    test('שלב 2 (יעד=4): כל מילה וקצת שווה כוכב', () {
      expect(GameSession.starsForWordCount(0, 4), 0);
      expect(GameSession.starsForWordCount(1, 4), 0);
      expect(GameSession.starsForWordCount(2, 4), 1);
      expect(GameSession.starsForWordCount(3, 4), 2);
      expect(GameSession.starsForWordCount(4, 4), 3);
    });
  });

  test('currentStars/wordsRemainingForGoal מתעדכנים לפי מילים שנמצאו לעומת יעד השלב', () {
    // config בטסט הזה מוגדר עם wordsRequired: 1, כך שמילה אחת = היעד המלא (3 כוכבים).
    final session = buildSession();
    expect(session.currentStars, 0);
    expect(session.wordsRemainingForGoal, 1);
    expect(session.hasReachedWordsGoal, isFalse);

    session.submitPath([
      const GridPosition(0, 0),
      const GridPosition(0, 1),
      const GridPosition(1, 0),
    ]);

    expect(session.currentStars, 3);
    expect(session.wordsRemainingForGoal, 0);
    expect(session.hasReachedWordsGoal, isTrue);
  });
}
