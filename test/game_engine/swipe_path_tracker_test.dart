import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/input/swipe_path_tracker.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';

/// בדיקות "אצבע אנושית": במקום קווים ישרים ומושלמים, מדמים החלקות עם
/// רעד, עקמומיות וסטייה הצידה - בדיוק מה שקורה בטלפון אמיתי, ושגרם בעבר
/// לבחירת אותיות "באמצע" בזמן החלקה אלכסונית.
void main() {
  const cell = 80.0;

  Offset center(GridPosition p) => Offset(p.col * cell + cell / 2, p.row * cell + cell / 2);

  /// מדמה החלקה עוברת דרך מרכזי [cells], עם סטייה ניצבת אקראית עד
  /// [jitter] (כשבר מגודל התא), "קשת" עקומה בכל מקטע, וקצב דגימה לא אחיד.
  List<GridPosition> swipe(
    List<GridPosition> cells, {
    int size = 5,
    double jitter = 0,
    double bow = 0,
    math.Random? random,
    int samplesPerSegment = 14,
  }) {
    final rnd = random ?? math.Random(1);
    final tracker = SwipePathTracker(size: size, cellSize: cell);
    tracker.start(center(cells.first));
    for (int s = 1; s < cells.length; s++) {
      final a = center(cells[s - 1]);
      final b = center(cells[s]);
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final segmentBow = (rnd.nextDouble() * 2 - 1) * bow * cell;
      for (int i = 1; i <= samplesPerSegment; i++) {
        final t = i / samplesPerSegment;
        // קשת חלקה (מקסימלית באמצע המקטע) + רעד אקראי, ושני הקצוות עוברים
        // קרוב למרכז האות (כמו אצבע שמכוונת לאות).
        final arc = math.sin(t * math.pi) * segmentBow;
        final noise = (rnd.nextDouble() * 2 - 1) * jitter * cell * math.sin(t * math.pi);
        tracker.move(Offset.lerp(a, b, t)! + normal * (arc + noise));
      }
    }
    return tracker.end();
  }

  /// כמו [swipe], אבל מדמה את בחירת המסך בין החלופות לפי מילון: מתקבלת
  /// החלופה הראשונה שהיא המילה המיועדת (בפועל: הראשונה שהיא מילה חוקית).
  List<GridPosition> swipeWithDictionary(
    List<GridPosition> cells, {
    double jitter = 0,
    double bow = 0,
    required math.Random random,
  }) {
    final tracker = SwipePathTracker(size: 5, cellSize: cell);
    tracker.start(center(cells.first));
    for (int s = 1; s < cells.length; s++) {
      final a = center(cells[s - 1]);
      final b = center(cells[s]);
      final dir = b - a;
      final normal = Offset(-dir.dy, dir.dx) / dir.distance;
      final segmentBow = (random.nextDouble() * 2 - 1) * bow * cell;
      for (int i = 1; i <= 14; i++) {
        final t = i / 14;
        final arc = math.sin(t * math.pi) * segmentBow;
        final noise = (random.nextDouble() * 2 - 1) * jitter * cell * math.sin(t * math.pi);
        tracker.move(Offset.lerp(a, b, t)! + normal * (arc + noise));
      }
    }
    final candidates = tracker.candidatePaths();
    return candidates.firstWhere(
      (c) => c.toString() == cells.toString(),
      orElse: () => candidates.first,
    );
  }

  group('אלכסון', () {
    test('אלכסון ישר נבחר בדיוק', () {
      const cells = [GridPosition(0, 0), GridPosition(1, 1), GridPosition(2, 2), GridPosition(3, 3)];
      expect(swipe(cells), cells);
    });

    test('אלכסון הפוך (מימין לשמאל) נבחר בדיוק', () {
      const cells = [GridPosition(0, 4), GridPosition(1, 3), GridPosition(2, 2), GridPosition(3, 1)];
      expect(swipe(cells), cells);
    });

    test('רגרסיה: אלכסון ישר "עולה" (מלמטה-שמאל ללמעלה-ימין) לא תופס אותיות בצדדים', () {
      // באלגוריתם הקודם התנועה הזו בחרה (2,0)→(1,0)→(1,1)→(0,1)→(0,2).
      const cells = [GridPosition(2, 0), GridPosition(1, 1), GridPosition(0, 2)];
      expect(swipe(cells), cells);
    });

    test('500 החלקות אלכסוניות רשלניות - אף אחת לא תופסת אות באמצע', () {
      final rnd = math.Random(42);
      const patterns = [
        [GridPosition(0, 0), GridPosition(1, 1), GridPosition(2, 2)],
        [GridPosition(2, 0), GridPosition(1, 1), GridPosition(0, 2)],
        [GridPosition(4, 4), GridPosition(3, 3), GridPosition(2, 2), GridPosition(1, 1)],
        [GridPosition(1, 3), GridPosition(2, 2), GridPosition(3, 1), GridPosition(4, 0)],
      ];
      var failures = 0;
      for (int i = 0; i < 500; i++) {
        final cells = patterns[i % patterns.length];
        final result = swipe(cells, jitter: 0.2, bow: 0.2, random: rnd);
        if (result.toString() != cells.toString()) failures++;
      }
      expect(failures, 0);
    });

    test('החלקות רשלניות מאוד - האימות מול המילון משלים את התיקון', () {
      final rnd = math.Random(9);
      const patterns = [
        [GridPosition(0, 0), GridPosition(1, 1), GridPosition(2, 2)],
        [GridPosition(3, 0), GridPosition(2, 1), GridPosition(1, 2), GridPosition(0, 3)],
        [GridPosition(0, 0), GridPosition(1, 1), GridPosition(1, 2), GridPosition(0, 3), GridPosition(1, 4)],
      ];
      var failures = 0;
      for (int i = 0; i < 600; i++) {
        final cells = patterns[i % patterns.length];
        final result = swipeWithDictionary(cells, jitter: 0.27, bow: 0.27, random: rnd);
        if (result.toString() != cells.toString()) failures++;
      }
      expect(failures, lessThanOrEqualTo(3));
    });

    test('החלקה מהירה מאוד (מעט דגימות) לא מדלגת על אף אות', () {
      const cells = [GridPosition(0, 0), GridPosition(1, 1), GridPosition(2, 2)];
      expect(swipe(cells, samplesPerSegment: 1), cells);
    });
  });

  group('אורתוגונלי ומעורב', () {
    test('שורה עם סטייה הצידה עדיין נבחרת', () {
      final rnd = math.Random(7);
      const cells = [GridPosition(2, 0), GridPosition(2, 1), GridPosition(2, 2), GridPosition(2, 3)];
      for (int i = 0; i < 200; i++) {
        expect(swipe(cells, jitter: 0.2, bow: 0.15, random: rnd), cells);
      }
    });

    test('צורת L ו"זיגזג" שמשלבים אלכסון ואורתוגונלי', () {
      final rnd = math.Random(3);
      const zigzag = [
        GridPosition(0, 0),
        GridPosition(1, 1),
        GridPosition(1, 2),
        GridPosition(0, 3),
        GridPosition(1, 4),
        GridPosition(2, 4),
        GridPosition(3, 3),
      ];
      const lShape = [GridPosition(0, 1), GridPosition(1, 1), GridPosition(2, 1), GridPosition(2, 2)];
      for (int i = 0; i < 200; i++) {
        expect(swipe(zigzag, jitter: 0.18, bow: 0.18, random: rnd), zigzag);
        expect(swipe(lShape, jitter: 0.18, bow: 0.18, random: rnd), lShape);
      }
    });

    test('חזרה לאות הקודמת מבטלת את האחרונה', () {
      final tracker = SwipePathTracker(size: 4, cellSize: cell);
      tracker.start(center(const GridPosition(0, 0)));
      tracker.move(center(const GridPosition(1, 1)));
      tracker.move(center(const GridPosition(1, 2)));
      expect(tracker.path, const [GridPosition(0, 0), GridPosition(1, 1), GridPosition(1, 2)]);
      tracker.move(center(const GridPosition(1, 1)));
      expect(tracker.path, const [GridPosition(0, 0), GridPosition(1, 1)]);
    });

    test('המרווח בין האותיות לא בוחר כלום', () {
      final tracker = SwipePathTracker(size: 3, cellSize: cell);
      tracker.start(center(const GridPosition(0, 0)));
      // הפינה המשותפת ל-4 התאים - בדיוק המקום שבו בעבר "נתפסה" אות באמצע.
      tracker.move(const Offset(cell, cell));
      expect(tracker.path, const [GridPosition(0, 0)]);
    });

    test('התחלה בקצה התא בוחרת את התא שנלחץ', () {
      final tracker = SwipePathTracker(size: 3, cellSize: cell);
      expect(tracker.start(const Offset(cell * 1.95, cell * 0.05)), const GridPosition(0, 1));
    });

    test('מועמדים להמשך הם השכנים הפנויים בלבד', () {
      final tracker = SwipePathTracker(size: 3, cellSize: cell);
      tracker.start(center(const GridPosition(0, 0)));
      expect(tracker.candidates, {
        const GridPosition(0, 1),
        const GridPosition(1, 0),
        const GridPosition(1, 1),
      });
    });
  });
}
