import 'dart:convert';

import 'package:flutter/foundation.dart' show compute;
import 'package:flutter/services.dart' show rootBundle;

import 'hebrew_trie.dart';

/// אחראי על טעינת מילון המשחק העברי מתוך ה-assets ובנייתו ל-Trie
/// לצורך ולידציה מהירה ואופליין של מילים במהלך המשחק.
///
/// המילון נבנה מהמאגר הפתוח hebrew-words-db (CC0) + tool/seed_words_raw.txt
/// על ידי tool/build_dictionary.py (ראו docs/DICTIONARY_LICENSING.md).
/// לעדכון: tool/sync_hebrew_words_db.py ואז tool/build_dictionary.py.
class DictionaryService {
  DictionaryService._();

  static final DictionaryService instance = DictionaryService._();

  HebrewTrie? _trie;
  List<String>? _allWords;
  bool get isLoaded => _trie != null;

  /// טוען את המילון פעם אחת (idempotent - קריאות נוספות לא יעשו כלום).
  Future<void> load({
    String assetPath = 'assets/dictionaries/he_words.json',
  }) async {
    if (_trie != null) return;
    final raw = await rootBundle.loadString(assetPath);
    // פענוח ה-JSON ובניית ה-Trie (~190 אלף מילים) לוקחים כמה מאות מילי-שניות
    // במכשיר - עושים את זה ב-isolate נפרד כדי שאנימציית מסך הפתיחה לא תיתקע.
    final built = await compute(_buildDictionary, raw);
    _trie ??= built.trie;
    _allWords ??= built.words;
  }

  HebrewTrie get trie {
    final t = _trie;
    if (t == null) {
      throw StateError(
        'Dictionary not loaded yet. Call DictionaryService.instance.load() first.',
      );
    }
    return t;
  }

  List<String> get allWords => _allWords ?? const <String>[];

  bool isValidNormalizedWord(String normalized) => trie.isWord(normalized);
}

/// רץ ב-isolate נפרד (דרך [compute]) - חייב להיות פונקציה ברמה העליונה.
({HebrewTrie trie, List<String> words}) _buildDictionary(String raw) {
  final words = (jsonDecode(raw) as List<dynamic>).cast<String>().toList(growable: false);
  final trie = HebrewTrie()..insertAll(words);
  return (trie: trie, words: words);
}
