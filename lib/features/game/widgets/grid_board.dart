import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/cosmetics/cosmetic_catalog.dart';
import '../../../core/theme/app_colors.dart';
import '../../../game_engine/input/swipe_path_tracker.dart';
import '../../../game_engine/models/grid_position.dart';
import 'connector_painter.dart';
import 'letter_tile.dart';

/// לוח האותיות האינטראקטיבי: מזהה גרירה בין תאים שכנים, מצייר קו מחבר
/// בזמן אמת, ומדווח את הנתיב הסופי כאשר האצבע משתחררת.
class GridBoard extends StatefulWidget {
  final List<List<String>> letters;
  final ValueChanged<List<GridPosition>> onPathSubmitted;

  /// נקרא בכל שינוי של הנתיב הנוכחי תוך כדי גרירה (המילה שנבנית כרגע),
  /// כדי שהמסך שמכיל את הלוח יוכל להציג אותה למעלה בזמן אמת - "בועת
  /// המילה" שרואים במשחקי חיבור-אותיות מוכרים. מקבל מחרוזת ריקה כשאין
  /// גרירה פעילה.
  final ValueChanged<String>? onWordChanged;
  final bool showErrorFlash;

  /// בודק (בלי לשנות מצב) אם נתיב הוא מילה חדשה וחוקית - מאפשר ללוח לבחור
  /// בין הנתיב הגולמי לבין חלופה "מתוקנת" אחרי החלקה רשלנית.
  final bool Function(List<GridPosition> path)? isPathAcceptable;

  /// false = הלוח לא מגיב למגע (למשל כשהמשחק מושהה).
  final bool enabled;
  final BoardSkin? boardSkin;
  final LetterSkin? letterSkin;
  final MarkerSkin? markerSkin;

  const GridBoard({
    super.key,
    required this.letters,
    required this.onPathSubmitted,
    this.onWordChanged,
    this.showErrorFlash = false,
    this.isPathAcceptable,
    this.enabled = true,
    this.boardSkin,
    this.letterSkin,
    this.markerSkin,
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
  SwipePathTracker? _tracker;

  /// האצבע שמובילה את ההחלקה הנוכחית. אצבע שנייה / כף יד שנוגעת במסך
  /// באמצע החלקה פשוט מתעלמים ממנה - אחרת המחווה "קופצת" אליה והמילה
  /// מתקלקלת.
  int? _activePointer;

  /// הנתיב הנבחר כרגע (לבדיקות בלבד).
  @visibleForTesting
  List<GridPosition> get debugCurrentPath => List.unmodifiable(_path);

  int get _size => widget.letters.length;
  bool get _isDragging => _path.isNotEmpty;

  /// כל הלוגיקה של תרגום תנועת האצבע לנתיב (כולל הטיפול באלכסונים) נמצאת
  /// ב-[SwipePathTracker] - ראו שם הסבר מלא ובדיקות שמדמות אצבע אנושית.
  SwipePathTracker _trackerFor(double cellSize) {
    final tracker = _tracker;
    if (tracker != null && tracker.size == _size) {
      tracker.cellSize = cellSize;
      return tracker;
    }
    return _tracker = SwipePathTracker(size: _size, cellSize: cellSize);
  }

  Offset _centerForPosition(GridPosition pos, double cellSize) {
    return Offset(pos.col * cellSize + cellSize / 2, pos.row * cellSize + cellSize / 2);
  }

  void _handleStart(Offset localOffset, double cellSize) {
    if (!widget.enabled) return;
    final tracker = _trackerFor(cellSize);
    tracker.start(localOffset);
    setState(() {
      _path = tracker.path;
      _dragPosition = localOffset;
      _isError = false;
    });
    HapticFeedback.selectionClick();
    _notifyWordChanged();
  }

  void _handleUpdate(Offset localOffset, double cellSize) {
    final tracker = _tracker;
    if (tracker == null || !tracker.isActive) return;
    final previousLength = _path.length;
    final changed = tracker.move(localOffset);
    setState(() {
      _dragPosition = localOffset;
      if (changed) _path = tracker.path;
    });
    if (changed) {
      if (_path.length > previousLength) {
        HapticFeedback.selectionClick();
      } else {
        HapticFeedback.lightImpact();
      }
      _notifyWordChanged();
    }
  }

  /// ביטול בלי הגשה (למשל המערכת "לקחה" את המגע, או שהמשחק הושהה).
  void _handleCancel() {
    _activePointer = null;
    _tracker?.cancel();
    if (_path.isEmpty && _dragPosition == null) return;
    setState(() {
      _path = [];
      _dragPosition = null;
    });
    _notifyWordChanged();
  }

  @override
  void didUpdateWidget(covariant GridBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _isDragging) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleCancel();
      });
    }
  }

  void _handleEnd() {
    _activePointer = null;
    final tracker = _tracker;
    if (tracker != null && tracker.isActive) {
      final candidates = tracker.candidatePaths();
      final primary = tracker.end();
      if (primary.isNotEmpty) {
        // אם הנתיב הראשי אינו מילה חוקית אבל אחת החלופות (בלי אות
        // שנתפסה בנגיעה שולית) כן - מגישים את החלופה. ראו
        // SwipePathTracker.candidatePaths.
        final accept = widget.isPathAcceptable;
        var chosen = primary;
        if (accept != null && !accept(primary)) {
          for (final candidate in candidates) {
            if (accept(candidate)) {
              chosen = candidate;
              break;
            }
          }
        }
        widget.onPathSubmitted(List<GridPosition>.from(chosen));
      }
    }
    setState(() {
      _path = [];
      _dragPosition = null;
    });
    _notifyWordChanged();
  }

  void _notifyWordChanged() {
    final word = _path.map((p) => widget.letters[p.row][p.col]).join();
    widget.onWordChanged?.call(word);
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

        TileVisualState stateFor(int r, int c) {
          final pos = GridPosition(r, c);
          if (_isError && _path.contains(pos)) return TileVisualState.error;
          if (_path.contains(pos)) return TileVisualState.selected;
          if (_hintPath.contains(pos)) return TileVisualState.hint;
          return TileVisualState.idle;
        }

        final candidates = _isDragging ? (_tracker?.candidates ?? const <GridPosition>{}) : const <GridPosition>{};

        Widget tileAt(int r, int c) {
          final state = stateFor(r, c);
          final pos = GridPosition(r, c);
          final isCandidate = candidates.contains(pos);
          // בזמן החלקה האותיות שלא נבחרו "מתכווצות" מעט: זה פותח
          // ויזואלית את המסדרונות האלכסוניים בין העיגולים, ותואם לאזורי
          // הפגיעה הקטנים של SwipePathTracker. השכנים שאפשר להמשיך אליהם
          // נשארים גדולים יותר ומקבלים טבעת עדינה - רמז לאן אפשר להמשיך.
          // הכיווץ תואם לאזורי הפגיעה של SwipePathTracker (עיגול ברדיוס
          // 0.4 מהתא): כשהעיגולים קטנים, הרווח האלכסוני בין ארבעה אריחים
          // נראה בבירור כ"מסדרון" שאפשר לעבור בו בלי לגעת באותיות שבצד.
          final scale = !_isDragging || state != TileVisualState.idle ? 1.0 : (isCandidate ? 0.92 : 0.78);
          final tileSize = cellSize * 0.8;
          return Positioned(
            key: ValueKey('tile-$r-$c'),
            left: c * cellSize,
            top: r * cellSize,
            width: cellSize,
            height: cellSize,
            child: Center(
              child: AnimatedScale(
                scale: scale,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    AnimatedOpacity(
                      opacity: isCandidate && state == TileVisualState.idle ? 1 : 0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: tileSize + 8,
                        height: tileSize + 8,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.75), width: 2.5),
                        ),
                      ),
                    ),
                    LetterTile(
                      letter: widget.letters[r][c],
                      size: tileSize,
                      paletteIndex: (r * 31 + c * 17) % 4,
                      state: state,
                      letterSkin: widget.letterSkin,
                      boardTileColor: widget.boardSkin?.tileColor,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final backdrop = widget.boardSkin?.backdropColor;
        return SizedBox(
          width: boardSize,
          height: boardSize,
          // קלט גולמי (Listener) ולא onPan*: ההחלקה מתחילה ברגע הנגיעה
          // ובנקודה המדויקת שבה האצבע נגעה (בלי "סף גרירה" של ~18-36px
          // שמזיז את נקודת ההתחלה לפינה שבין האותיות), ונצמדת לאצבע
          // הראשונה בלבד.
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (event) {
              if (_activePointer != null || !widget.enabled) return;
              _activePointer = event.pointer;
              _handleStart(event.localPosition, cellSize);
            },
            onPointerMove: (event) {
              if (event.pointer != _activePointer) return;
              _handleUpdate(event.localPosition, cellSize);
            },
            onPointerUp: (event) {
              if (event.pointer != _activePointer) return;
              _handleEnd();
            },
            onPointerCancel: (event) {
              if (event.pointer != _activePointer) return;
              _handleCancel();
            },
            child: GestureDetector(
              // "תופס" את המחווה בזירת המחוות כדי שגלילה / החלקת-חזרה של
              // מסך מכיל לעולם לא תגנוב אותה באמצע מילה.
              behavior: HitTestBehavior.opaque,
              dragStartBehavior: DragStartBehavior.down,
              onPanStart: (_) {},
              onPanUpdate: (_) {},
              // אין יותר קופסת רקע כהה/אחידה מסביב ללוח - הרקע הוא הגרדיאנט
              // של המסך המכיל עצמו (ראו game_screen.dart וכו'), כדי שהלוח
              // יתמזג חזותית עם שאר האפליקציה במקום להיראות כ"קובייה" נפרדת.
              child: Stack(
                children: [
                  if (backdrop != null)
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(color: backdrop, borderRadius: BorderRadius.circular(28)),
                      ),
                    ),
                  // רשת קווים דקה ושקופה בין מרכזי כל שתי אותיות שכנות
                  // (כולל אלכסונים) - "מלמדת" ויזואלית שגם חיבור אלכסוני
                  // חוקי לגמרי, בהשראת עיצוב משחקי חיבור-אותיות מוכרים.
                  // מצוירת מתחת לאריחים, ונראית רק במרווח שנפתח בין עיגול
                  // לעיגול (ראו tileAt לעיל).
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _GridMeshPainter(size: _size, cellSize: cellSize, color: widget.boardSkin?.meshColor),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: ConnectorPainter(
                        points: linePoints,
                        isError: _isError,
                        style: widget.markerSkin?.style ?? MarkerStyle.classic,
                        markerColor: widget.markerSkin?.color ?? AppColors.tileSelected,
                      ),
                    ),
                  ),
                  // שני מעברים: קודם כל התאים ה"רגילים" (idle), ואז
                  // התאים המודגשים (נבחר/רמז/שגיאה) - כך שתא מודגש (שגדל
                  // מעט באנימציה) לעולם לא "נבלע" ויזואלית מתחת לשכן
                  // צמוד שמצטייר אחריו ב-Stack, גם בלי רווח כלל ביניהם.
                  for (int r = 0; r < _size; r++)
                    for (int c = 0; c < _size; c++)
                      if (stateFor(r, c) == TileVisualState.idle) tileAt(r, c),
                  for (int r = 0; r < _size; r++)
                    for (int c = 0; c < _size; c++)
                      if (stateFor(r, c) != TileVisualState.idle) tileAt(r, c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// מצייר רשת קווים דקה בין מרכזי כל שתי אותיות שכנות (כולל אלכסונים) -
/// "הרשת" שנראית ברקע הלוח במשחקי חיבור-אותיות מוכרים. משודר מחדש רק אם
/// גודל הלוח/התא משתנה (למשל בסיבוב מסך), כי הקווים עצמם קבועים.
class _GridMeshPainter extends CustomPainter {
  final int size;
  final double cellSize;
  final Color? color;

  _GridMeshPainter({required this.size, required this.cellSize, this.color});

  @override
  void paint(Canvas canvas, Size canvasSize) {
    // שקיפות/עובי מוגברים לעומת קודם - בלי קופסת רקע כהה מאחורי הלוח
    // (ראו build() לעיל) הקו צריך להיות ברור בפני עצמו על גבי הגרדיאנט
    // הבהיר-יחסית של המסך, בדיוק כמו ברשת הדקה שנראית במשחקי חיבור-
    // אותיות מוכרים.
    final paint = Paint()
      ..color = color ?? Colors.white.withValues(alpha: 0.4)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;

    Offset centerOf(int row, int col) => Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);

    for (int r = 0; r < size; r++) {
      for (int c = 0; c < size; c++) {
        final from = centerOf(r, c);
        // מציירים רק לכיוון "קדימה" (ימין / מטה / שני האלכסונים הקדמיים)
        // כדי לא לצייר כל קו פעמיים.
        const forwardNeighbors = [
          [0, 1],
          [1, -1],
          [1, 0],
          [1, 1],
        ];
        for (final delta in forwardNeighbors) {
          final nr = r + delta[0];
          final nc = c + delta[1];
          if (nr < 0 || nr >= size || nc < 0 || nc >= size) continue;
          canvas.drawLine(from, centerOf(nr, nc), paint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GridMeshPainter oldDelegate) {
    return oldDelegate.size != size || oldDelegate.cellSize != cellSize || oldDelegate.color != color;
  }
}
