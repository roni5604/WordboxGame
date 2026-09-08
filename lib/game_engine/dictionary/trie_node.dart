/// צומת בודד בעץ ה-Trie המשמש לאחסון ולחיפוש מהיר של מילות המילון העברי.
class TrieNode {
  final Map<String, TrieNode> children = <String, TrieNode>{};
  bool isWord = false;
}
