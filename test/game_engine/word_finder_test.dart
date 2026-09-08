import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/word_finder.dart';

void main() {
  test('findAllWords finds every valid word reachable on the grid', () {
    final trie = HebrewTrie();
    trie.insertAll(['בית', 'בי', 'תז', 'זי']);

    final grid = [
      ['ב', 'י'],
      ['ת', 'ז'],
    ];

    final finder = WordFinder(trie);
    final found = finder.findAllWords(grid).map((f) => f.normalizedWord).toSet();

    expect(found, containsAll(['בית', 'בי']));
  });

  test('does not find words that are not contiguous/adjacent', () {
    final trie = HebrewTrie();
    trie.insertAll(['בז']); // ב ו-ז אינם שכנים בלוח הבא
    final grid = [
      ['ב', 'א', 'ז'],
    ];
    final finder = WordFinder(trie);
    final found = finder.findAllWords(grid);
    expect(found, isEmpty);
  });
}
