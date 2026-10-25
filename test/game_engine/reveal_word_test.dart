import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/game_session.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/game_engine/word_finder.dart';

void main() {
  const bit = [GridPosition(0, 0), GridPosition(0, 1), GridPosition(1, 0)];
  const bi = [GridPosition(0, 0), GridPosition(0, 1)];

  GameSession build() {
    final trie = HebrewTrie()..insertAll(['בית', 'בי']);
    final board = GeneratedBoard(
      letters: const [
        ['ב', 'י'],
        ['ת', 'ז'],
      ],
      possibleWords: const [FoundWord('בית', bit), FoundWord('בי', bi)],
      size: 2,
    );
    return GameSession(
      config: const LevelConfig(
        levelNumber: 1,
        tier: WorldTier.seedling,
        gridSize: 2,
        timeLimit: Duration(seconds: 60),
        scoreRequired: 3,
      ),
      board: board,
      trie: trie,
    );
  }

  test('"גלה מילה" בוחר רק מילה שעוד לא נמצאה', () {
    final session = build();
    session.submitPath(bit);
    for (var seed = 0; seed < 30; seed++) {
      expect(session.revealWordCandidate(random: Random(seed))!.normalizedWord, 'בי');
    }
  });

  test('לא חוזר על המילה שכבר מוצגת, ואין מילה כשהכל נמצא', () {
    final session = build();
    expect(session.revealWordCandidate(random: Random(1), except: 'בית')!.normalizedWord, 'בי');
    session.submitPath(bit);
    session.submitPath(bi);
    expect(session.revealWordCandidate(), isNull);
  });

  test('לפעמים קלה ולפעמים ארוכה (אקראי)', () {
    final session = build();
    final picks = {for (var seed = 0; seed < 40; seed++) session.revealWordCandidate(random: Random(seed))!.normalizedWord};
    expect(picks, containsAll(['בית', 'בי']));
  });

  test('isFound / isOnBoard', () {
    final session = build();
    expect(session.isOnBoard('בית'), isTrue);
    expect(session.isOnBoard('שלום'), isFalse);
    expect(session.isFound('בית'), isFalse);
    session.submitPath(bit);
    expect(session.isFound('בית'), isTrue);
  });
}
