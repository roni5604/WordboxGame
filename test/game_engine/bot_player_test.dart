import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/bot_player.dart';
import 'package:wordbox_hebrew/game_engine/word_finder.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';

void main() {
  test('BotPlayer finds words over simulated time and accumulates score', () {
    final board = GeneratedBoard(
      letters: const [
        ['ב', 'י'],
        ['ת', 'ז'],
      ],
      possibleWords: [
        FoundWord('בית', const [GridPosition(0, 0), GridPosition(0, 1), GridPosition(1, 0)]),
        FoundWord('בי', const [GridPosition(0, 0), GridPosition(0, 1)]),
      ],
      size: 2,
    );

    final bot = BotPlayer(name: 'בוט', difficulty: BotDifficulty.hard, board: board);

    FoundWord? found;
    // מדמים 30 שניות בקפיצות של חצי שנייה - בקושי "hard" (2-6 שנ' בין מציאות)
    // אמור למצוא את שתי המילים במסגרת הזמן הזה.
    for (int i = 0; i < 60; i++) {
      found = bot.tick(const Duration(milliseconds: 500)) ?? found;
    }

    expect(bot.foundNormalizedWords, isNotEmpty);
    expect(bot.score, greaterThan(0));
  });
}
