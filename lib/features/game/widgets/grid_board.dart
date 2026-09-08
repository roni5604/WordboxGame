import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../game_engine/models/grid_position.dart';
import 'connector_painter.dart';
import 'letter_tile.dart';

/// לוח האותיות האינטראקטיבי: מזהה גרירה בין תאים שכנים, מצייר קו מחבר
/// בזמן אמת, ומדווח את הנתיב הסופי כאשר האצבע משתחררת.
class GridBoard extends StatefulWidget {
  final List<List<String>> letters;
  final ValueChanged<List<GridPosition>> onPathSubmitted;
  final bool showErrorFlash;

  const GridBoard({
    super.key,
    required this.letters,
    required this.onPathSubmitted,
    this.showErrorFlash = false,
  });

  @override
  State<GridBoard> createState() => GridBoardState();
}

class GridBoardState extends State<GridBoard> {
  List<GridPosition> _path = [];
  Offset? _dragPosition;
  bool _isError = false;
  List<GridPosition> _hintPath = [];
  Timer? _hintTimer;

  int get _size => widget.letters.length;

  GridPosition? _positionFromOffset(Offset localOffset, double cellSize) {
    final col = (localOffset.dx / cellSize).floor();
    final row = (localOffset.dy / cellSize).floor();
    if (row < 0 || row >= _size || col < 0 || col >= _size) return null;

    // תיקון לבאג "האלכסון נתפס": חלוקה מלבנית פשוטה (floor) גורמת לכך
    // שבגרירה אלכסונית מהירה, נקודת המגע יכולה לחצות רגעית את הגבול של
    // התא השכן האורתוגונלי (לא זה שבאלכסון) ליד הפינה המשותפת בין 4
    // תאים - וכך "נתפסת" בטעות בתא הלא-נכון. הפתרון: דורשים שהנקודה
    // תהיה קרובה מספיק (במרחק אוקלידי) למרכז התא המועמד; ליד הפינות
    // (המרוחקות ~0.71*cellSize מהמרכז) הנקודה תיפסל ותיחשב "אזור מת",
    // ואילו ליד אמצע הצלעות (מרוחק לכל היותר 0.5*cellSize) היא תמיד
    // תתקבל - כך שהתגובתיות הרגילה לא נפגעת, רק פינות אמביגואליות.
    final candidate = GridPosition(row, col);
    final center = _centerForPosition(candidate, cellSize);
    final distance = (localOffset - center).distance;
    if (distance > cellSize * 0.62) return null;

    return candidate;
  }

  Offset _centerForPosition(GridPosition pos, double cellSize) {
    return Offset(
      pos.col * cellSize + cellSize / 2,
      pos.row * cellSize + cellSize / 2,
    );
  }

  void _handleStart(Offset localOffset, double cellSize) {
    final pos = _positionFromOffset(localOffset, cellSize);
    if (pos == null) return;
    setState(() {
      _path = [pos];
      _dragPosition = localOffset;
      _isError = false;
    });
    HapticFeedback.selectionClick();
  }

  void _handleUpdate(Offset localOffset, double cellSize) {
    if (_path.isEmpty) return;
    setState(() => _dragPosition = localOffset);

    final pos = _positionFromOffset(localOffset, cellSize);
    if (pos == null) return;

    if (_path.length >= 2 && pos == _path[_path.length - 2]) {
      // חזרה לאחור - מבטלת את התא האחרון (מאפשר "לתקן" נתיב).
      setState(() => _path.removeLast());
      HapticFeedback.selectionClick();
      return;
    }

    if (_path.contains(pos)) return;

    final last = _path.last;
    if (pos.isAdjacentTo(last)) {
      setState(() => _path.add(pos));
      HapticFeedback.selectionClick();
    }
  }

  void _handleEnd() {
    if (_path.isNotEmpty) {
      widget.onPathSubmitted(List<GridPosition>.from(_path));
    }
    setState(() {
      _path = [];
      _dragPosition = null;
    });
  }

  /// מאפשר למסך המשחק להבהב את הלוח באדום כשמתגלה שגיאה, מבלי לשנות state חיצוני.
  void flashError() {
    setState(() => _isError = true);
    Future.delayed(const Duration(milliseconds: 260), () {
      if (mounted) setState(() => _isError = false);
    });
  }

  /// מציג רמז: מדגיש זמנית (בזהב זוהר) את הנתיב של מילה שטרם נמצאה, כדי
  /// ש"מציג את המילה עוד לפני שהיא נמצאה" - השחקן/ית עדיין צריך/ה לגרור
  /// בעצמו/ה מעל האותיות המודגשות כדי לזכות בניקוד.
  void showHint(List<GridPosition> path) {
    _hintTimer?.cancel();
    setState(() => _hintPath = path);
    _hintTimer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _hintPath = []);
    });
  }

  @override
  void dispose() {
    _hintTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // הלוח תמיד ריבועי ומוגבל לצלע הקטנה מבין הרוחב/הגובה הזמינים,
        // כדי שלעולם לא "ייחתך" מחוץ למסך (למשל במסכים נמוכים/רחבים).
        final maxW = constraints.maxWidth.isFinite ? constraints.maxWidth : 400.0;
        final maxH = constraints.maxHeight.isFinite ? constraints.maxHeight : maxW;
        final boardSize = maxW < maxH ? maxW : maxH;
        final cellSize = boardSize / _size;

        final linePoints = [
          for (final p in _path) _centerForPosition(p, cellSize),
          if (_dragPosition != null) _dragPosition!,
        ];

        return SizedBox(
          width: boardSize,
          height: boardSize,
          child: GestureDetector(
            onPanStart: (details) => _handleStart(details.localPosition, cellSize),
            onPanUpdate: (details) => _handleUpdate(details.localPosition, cellSize),
            onPanEnd: (_) => _handleEnd(),
            onPanCancel: _handleEnd,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: ConnectorPainter(points: linePoints, isError: _isError),
                  ),
                ),
                for (int r = 0; r < _size; r++)
                  for (int c = 0; c < _size; c++)
                    Positioned(
                      left: c * cellSize,
                      top: r * cellSize,
                      width: cellSize,
                      height: cellSize,
                      child: Center(
                        child: LetterTile(
                          letter: widget.letters[r][c],
                          size: cellSize * 0.82,
                          // דפוס פסאודו-אקראי אך יציב לפי מיקום, כדי שהלוח
                          // ייראה כמו פסיפס צבעוני (כמו אייקון האפליקציה)
                          // ולא יתחלף מחדש בכל build.
                          paletteIndex: (r * 31 + c * 17) % 4,
                          state: _isError && _path.contains(GridPosition(r, c))
                              ? TileVisualState.error
                              : _path.contains(GridPosition(r, c))
                                  ? TileVisualState.selected
                                  : _hintPath.contains(GridPosition(r, c))
                                      ? TileVisualState.hint
                                      : TileVisualState.idle,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        );
      },
    );
  }
}
