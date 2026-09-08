import 'dictionary/hebrew_trie.dart';
import 'models/grid_position.dart';

/// תוצאה בודדת שנמצאה בסריקת הלוח: המילה (מנורמלת) והנתיב שמרכיב אותה.
class FoundWord {
  final String normalizedWord;
  final List<GridPosition> path;

  const FoundWord(this.normalizedWord, this.path);

  String get displayWord => HebrewTrie.toDisplayWord(normalizedWord);
}

/// מבצע חיפוש DFS ממצה על פני לוח אותיות נתון, ומוצא את כל המילים
/// החוקיות (לפי ה-Trie) שניתן להרכיב מחיבור אותיות שכנות (8 כיוונים),
/// ללא שימוש חוזר באותו תא באותה מילה.
///
/// משמש הן ל(1) בדיקת "פתירות" הלוח בעת היצירה, והן ל(2) חישוב רשימת
/// כל המילים האפשריות לצורך מסך תוצאות ("מצאת 6 מתוך 14 מילים אפשריות").
class WordFinder {
  final HebrewTrie trie;
  final int minWordLength;

  WordFinder(this.trie, {this.minWordLength = 2});

  List<FoundWord> findAllWords(List<List<String>> grid) {
    final rows = grid.length;
    final cols = grid.isEmpty ? 0 : grid[0].length;
    final results = <String, FoundWord>{};
    final visited = List.generate(rows, (_) => List<bool>.filled(cols, false));

    void dfs(int r, int c, String prefix, List<GridPosition> path) {
      if (r < 0 || r >= rows || c < 0 || c >= cols || visited[r][c]) return;
      final nextPrefix = prefix + grid[r][c];
      if (!trie.hasPrefix(nextPrefix)) return;

      visited[r][c] = true;
      path.add(GridPosition(r, c));

      if (nextPrefix.length >= minWordLength && trie.isWord(nextPrefix)) {
        results.putIfAbsent(
          nextPrefix,
          () => FoundWord(nextPrefix, List<GridPosition>.from(path)),
        );
      }

      for (final n in GridPosition(r, c).rawNeighbors) {
        dfs(n.row, n.col, nextPrefix, path);
      }

      visited[r][c] = false;
      path.removeLast();
    }

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        dfs(r, c, '', <GridPosition>[]);
      }
    }

    final list = results.values.toList()
      ..sort((a, b) => b.normalizedWord.length.compareTo(a.normalizedWord.length));
    return list;
  }
}
