import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/game_session.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/game_engine/scoring.dart';

void main() {
  group('HardLetters', () {
    test('the rare letters are hard, common ones are not', () {
      for (final l in ['ז', 'ט', 'צ', 'ג', 'ס', 'ק', 'פ']) {
        expect(HardLetters.isHard(l), isTrue, reason: l);
      }
      for (final l in ['י', 'ו', 'מ', 'ר', 'ת', 'נ', 'א', 'ה', 'ל', 'ב']) {
        expect(HardLetters.isHard(l), isFalse, reason: l);
      }
    });

    test('final forms count like their base letter', () {
      expect(HardLetters.isHard('ץ'), isTrue);
      expect(HardLetters.isHard('ף'), isTrue);
      expect(HardLetters.isHard('ם'), isFalse);
    });

    test('bonus is one point per hard letter', () {
      expect(HardLetters.bonusFor('בית'), 0);
      expect(HardLetters.bonusFor('זה'), 1);
      expect(HardLetters.bonusFor('קפה'), 2);
      expect(HardLetters.bonusFor('קפצ'), 3);
    });
  });

  group('scoreForWord', () {
    test('adds the hard-letter bonus on top of the length score', () {
      expect(scoreForWord('בית'), scoreForWordLength(3));
      expect(scoreForWord('קפה'), scoreForWordLength(3) + 2);
      expect(scoreForWord('זה'), scoreForWordLength(2) + 1);
    });

    test('the bonus is small next to a longer word', () {
      // מילה קצרה עם אות קשה לא שווה יותר ממילה ארוכה באות אחת בלי אותיות קשות.
      expect(scoreForWord('קפה'), lessThan(scoreForWord('אבנימ')));
    });
  });

  test('GameSession awards and reports the hard-letter bonus', () {
    final trie = HebrewTrie()..insertAll(['קפה', 'בית']);
    final board = GeneratedBoard(
      letters: const [
        ['ק', 'פ'],
        ['ב', 'ה'],
      ],
      possibleWords: const [],
      size: 2,
    );
    final session = GameSession(
      config: const LevelConfig(
        levelNumber: 1,
        tier: WorldTier.seedling,
        gridSize: 2,
        timeLimit: Duration(seconds: 60),
        scoreRequired: 30,
      ),
      board: board,
      trie: trie,
    );

    final result = session.submitPath(const [GridPosition(0, 0), GridPosition(0, 1), GridPosition(1, 1)]);
    expect(result.isSuccess, isTrue);
    expect(result.pointsAwarded, 5);
    expect(result.hardLetterBonus, 2);
    expect(result.bannerText, contains('💎'));
    expect(session.score, 5);
  });
}
