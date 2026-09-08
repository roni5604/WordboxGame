import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';

void main() {
  group('normalizeHebrewWord', () {
    test('replaces sofit letters with base form', () {
      expect(normalizeHebrewWord('מלך'), 'מלכ');
      expect(normalizeHebrewWord('שלום'), 'שלומ');
      expect(normalizeHebrewWord('אמא'), 'אמא');
    });
  });

  group('HebrewTrie', () {
    late HebrewTrie trie;

    setUp(() {
      trie = HebrewTrie();
      trie.insertAll([
        normalizeHebrewWord('בית'),
        normalizeHebrewWord('מלך'),
        normalizeHebrewWord('שלום'),
      ]);
    });

    test('isWord finds inserted words', () {
      expect(trie.isWord('בית'), isTrue);
      expect(trie.isWord('מלכ'), isTrue); // normalized form
    });

    test('isWord returns false for unknown words', () {
      expect(trie.isWord('זזזז'), isFalse);
    });

    test('hasPrefix finds valid prefixes', () {
      expect(trie.hasPrefix('בי'), isTrue);
      expect(trie.hasPrefix('שלו'), isTrue);
      expect(trie.hasPrefix('קק'), isFalse);
    });

    test('toDisplayWord restores sofit form at the end', () {
      expect(HebrewTrie.toDisplayWord('מלכ'), 'מלך');
      expect(HebrewTrie.toDisplayWord('שלומ'), 'שלום');
      expect(HebrewTrie.toDisplayWord('בית'), 'בית');
    });
  });
}
