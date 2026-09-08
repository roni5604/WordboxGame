import 'trie_node.dart';

/// מיפוי בין אותיות סופיות (ך ם ן ף ץ) לצורתן הרגילה (כ מ נ פ צ).
///
/// הלוח מציג תמיד את הצורה הרגילה של האות (כך שאין בלבול חזותי), ואילו
/// המילון מנרמל את כל המילים לאותה צורה. כאשר מילה חוקית מוצגת למשתמש,
/// יש להחזיר את האות האחרונה לצורתה הסופית (ראו [HebrewTrie.toDisplayWord]).
const Map<String, String> kSofitToBase = {
  'ך': 'כ',
  'ם': 'מ',
  'ן': 'נ',
  'ף': 'פ',
  'ץ': 'צ',
};

const Map<String, String> kBaseToSofit = {
  'כ': 'ך',
  'מ': 'ם',
  'נ': 'ן',
  'פ': 'ף',
  'צ': 'ץ',
};

/// ממיר מילה לצורתה המנורמלת (ללא אותיות סופיות) - כפי שהיא מיוצגת על הלוח.
String normalizeHebrewWord(String word) {
  final buffer = StringBuffer();
  for (final ch in word.split('')) {
    buffer.write(kSofitToBase[ch] ?? ch);
  }
  return buffer.toString();
}

/// עץ Trie (עץ קידומות) המכיל את מילון המשחק העברי, מנורמל לאותיות רגילות
/// (ללא צורות סופיות) כדי להתאים בדיוק לאותיות המוצגות על הלוח.
///
/// מבנה זה מאפשר:
/// - בדיקת תקינות מילה ב-O(אורך המילה).
/// - חיפוש כל המילים האפשריות מתוך לוח נתון (DFS עם חיתוך מוקדם לפי קידומת).
class HebrewTrie {
  final TrieNode _root = TrieNode();
  int _wordCount = 0;

  int get wordCount => _wordCount;

  /// מוסיף מילה למילון (המילה צריכה להיות כבר מנורמלת - ראו [normalizeHebrewWord]).
  void insert(String normalizedWord) {
    if (normalizedWord.isEmpty) return;
    var node = _root;
    for (final ch in normalizedWord.split('')) {
      node = node.children.putIfAbsent(ch, () => TrieNode());
    }
    if (!node.isWord) {
      node.isWord = true;
      _wordCount++;
    }
  }

  void insertAll(Iterable<String> normalizedWords) {
    for (final w in normalizedWords) {
      insert(w);
    }
  }

  /// בודק אם המחרוזת (מנורמלת) היא מילה שלמה במילון.
  bool isWord(String normalizedWord) {
    final node = _nodeForPrefix(normalizedWord);
    return node != null && node.isWord;
  }

  /// בודק אם קיימת במילון מילה כלשהי שמתחילה בקידומת הנתונה.
  /// שימושי כדי להפסיק (לחתוך) חיפוש DFS על הלוח מוקדם ככל האפשר.
  bool hasPrefix(String normalizedPrefix) {
    return _nodeForPrefix(normalizedPrefix) != null;
  }

  TrieNode? _nodeForPrefix(String prefix) {
    var node = _root;
    for (final ch in prefix.split('')) {
      final next = node.children[ch];
      if (next == null) return null;
      node = next;
    }
    return node;
  }

  /// ממיר מילה מנורמלת (כפי שמוצגת על הלוח) לצורת התצוגה הדקדוקית הנכונה,
  /// כלומר עם אות סופית באות האחרונה אם רלוונטי.
  static String toDisplayWord(String normalizedWord) {
    if (normalizedWord.isEmpty) return normalizedWord;
    final chars = normalizedWord.split('');
    final last = chars.last;
    final sofit = kBaseToSofit[last];
    if (sofit != null) {
      chars[chars.length - 1] = sofit;
    }
    return chars.join();
  }
}
