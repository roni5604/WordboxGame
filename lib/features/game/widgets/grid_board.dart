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

  /// מוצא את התא שמרכזו הכי קרוב לנקודת המגע (Voronoi - "השכן הקרוב
  /// ביותר"), מבין התא שהחלוקה המלבנית הפשוטה (floor) מציעה ושמונת
  /// שכניו. בניגוד לגישה קודמת שבדקה רק "האם המרחק מהמרכז המועמד קטן
  /// מסף קבוע" - וכך השאירה "אזור מת" ליד הפינות המשותפות בין 4 תאים,
  /// במיוחד לאורך אלכסונים (שבהם המרחק בין מרכזי תאים סמוכים גדול פי
  /// √2 מהמרחק האורתוגונלי) - הגישה הזו תמיד מחזירה תא כלשהו, בלי
  /// "לדחות" נקודות: כל נקודה בתוך הלוח שייכת בדיוק לתא אחד (התא שמרכזו
  /// הקרוב ביותר), כך שהמעבר בין תאים קורה בדיוק בחצי המרחק בין
  /// מרכזיהם - סימטרי גם לאורתוגונלי וגם לאלכסוני, בלי אזור "דביק".
  GridPosition _nearestPosition(Offset localOffset, double cellSize) {
    final col = (localOffset.dx / cellSize).floor().clamp(0, _size - 1);
    final row = (localOffset.dy / cellSize).floor().clamp(0, _size - 1);
    final candidate = GridPosition(row, col);

    var best = candidate;
    var bestDistanceSq = (localOffset - _centerForPosition(candidate, cellSize)).distanceSquared;

    for (final n in candidate.rawNeighbors) {
      if (n.row < 0 || n.row >= _size || n.col < 0 || n.col >= _size) continue;
      final distanceSq = (localOffset - _centerForPosition(n, cellSize)).distanceSquared;
      if (distanceSq < bestDistanceSq) {
        bestDistanceSq = distanceSq;
        best = n;
      }
    }
    return best;
  }

  Offset _centerForPosition(GridPosition pos, double cellSize) {
    return Offset(
      pos.col * cellSize + cellSize / 2,
      pos.row * cellSize + cellSize / 2,
    );
  }

  void _handleStart(Offset localOffset, double cellSize) {
    final pos = _nearestPosition(localOffset, cellSize);
    setState(() {
      _path = [pos];
      _dragPosition = localOffset;
      _isError = false;
    });
    HapticFeedback.selectionClick();
  }

  /// מעבד נקודת מגע בודדת: מטפל ב"ביטול תא אחרון" (חזרה לאחור), התעלמות
  /// מתא שכבר בנתיב, והוספת תא שכן חדש. מחזיר true אם הנתיב השתנה.
  bool _processPoint(Offset point, double cellSize) {
    final pos = _nearestPosition(point, cellSize);

    if (_path.length >= 2 && pos == _path[_path.length - 2]) {
      _path.removeLast();
      return true;
    }
    if (_path.contains(pos)) return false;

    final last = _path.last;
    if (pos.isAdjacentTo(last)) {
      _path.add(pos);
      return true;
    }
    return false;
  }

  void _handleUpdate(Offset localOffset, double cellSize) {
    if (_path.isEmpty) return;
    final previous = _dragPosition;
    var changed = false;

    if (previous != null && previous != localOffset) {
      // דוגמים נקודות ביניים בין עדכון הגרירה הקודם לנוכחי: בגרירה
      // מהירה (או FPS נמוך) המרחק בין שתי דגימות עוקבות של onPanUpdate
      // יכול לגדול מ-cellSize, ואז נקודת המגע "מדלגת" מעל תא שכן נדרש
      // בלי לעבור בו כלל - מה שבעבר היה משתיק את הגרירה עד סוף המחווה
      // (כי אין נתיב חוקי לתא הרחוק). הדגימה כאן פותרת את זה.
      final distance = (localOffset - previous).distance;
      final steps = (distance / (cellSize * 0.4)).ceil().clamp(1, 12);
      for (int i = 1; i <= steps; i++) {
        final point = Offset.lerp(previous, localOffset, i / steps)!;
        if (_processPoint(point, cellSize)) changed = true;
      }
    } else {
      if (_processPoint(localOffset, cellSize)) changed = true;
    }

    setState(() => _dragPosition = localOffset);
    if (changed) HapticFeedback.selectionClick();
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

  /// מציג רמז: מדגיש (בזהב זוהר) את הנתיב של מילה שטרם נמצאה, כדי
  /// ש"מציג את המילה עוד לפני שהיא נמצאה" - השחקן/ית עדיין צריך/ה לגרור
  /// בעצמו/ה מעל האותיות המודגשות כדי לזכות בניקוד. כברירת מחדל נעלם
  /// אוטומטית אחרי [duration]; אפשר להעביר null כדי שיישאר מודגש עד
  /// קריאה מפורשת ל-[clearHint] (למשל בטוטוריאל המוטבע של שלב 1).
  void showHint(List<GridPosition> path, {Duration? duration = const Duration(milliseconds: 2600)}) {
    _hintTimer?.cancel();
    setState(() => _hintPath = path);
    if (duration != null) {
      _hintTimer = Timer(duration, () {
        if (mounted) setState(() => _hintPath = []);
      });
    }
  }

  /// מנקה רמז מוצג (בעיקר לרמז "דביק" - persistent - שהוצג עם duration null).
  void clearHint() {
    _hintTimer?.cancel();
    if (mounted) setState(() => _hintPath = []);
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
                          // אריחים "צמודים" יותר (היו 0.82) - כך שהמרווח
                          // הוויזואלי בין תאים סמוכים קטן ותנועת האצבע
                          // בין אריחים (ובמיוחד באלכסון) מרגישה טבעית יותר.
                          size: cellSize * 0.94,
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
