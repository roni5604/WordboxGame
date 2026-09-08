import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'hebrew_trie.dart';

/// אחראי על טעינת מילון המשחק העברי מתוך ה-assets ובנייתו ל-Trie
/// לצורך ולידציה מהירה ואופליין של מילים במהלך המשחק.
///
/// המילון הנוכחי הוא רשימה מאוצרת (curated) של מילים עבריות נפוצות,
/// שנבנתה במיוחד עבור הפרויקט הזה כדי להימנע מבעיות רישוי (ראו
/// docs/DICTIONARY_LICENSING.md). ניתן להחליף/להרחיב אותה בעתיד בקובץ
/// גדול יותר על ידי עדכון assets/dictionaries/he_words.json.
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
    final List<dynamic> decoded = jsonDecode(raw) as List<dynamic>;
    final words = decoded.cast<String>();
    final trie = HebrewTrie();
    trie.insertAll(words);
    _trie = trie;
    _allWords = words;
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
