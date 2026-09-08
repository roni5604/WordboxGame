import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('generates a solvable 4x4 board using the real dictionary', () async {
    final wordsRaw = await rootBundle.loadString('assets/dictionaries/he_words.json');
    final words = (jsonDecode(wordsRaw) as List).cast<String>();
    final trie = HebrewTrie()..insertAll(words);

    final freqRaw = await rootBundle.loadString('assets/config/letter_frequency.json');
    final Map<String, dynamic> freqDecoded = jsonDecode(freqRaw) as Map<String, dynamic>;
    final weights = freqDecoded.map((k, v) => MapEntry(k, (v as num).toDouble()));

    final generator = BoardGenerator(trie: trie, letterWeights: weights);
    final board = generator.generate(size: 4, minWordsRequired: 5);

    expect(board.letters.length, 4);
    expect(board.letters[0].length, 4);
    expect(board.possibleWords, isNotEmpty);
  });
}
