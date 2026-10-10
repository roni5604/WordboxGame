import 'dart:math' as math;
import 'dart:ui';

import '../models/grid_position.dart';

/// מתרגם תנועת אצבע רציפה על הלוח לנתיב של תאים שכנים - הלב של "החלקה
/// נוחה", במיוחד באלכסון.
///
/// ## למה אלכסון היה לא נוח
///
/// בגישה הקודמת כל נקודה על הלוח הייתה שייכת לתא שמרכזו הכי קרוב
/// (Voronoi מלא). אבל בדרך מתא (0,0) לתא (1,1) האצבע עוברת בדיוק דרך הפינה
/// המשותפת לארבעה תאים - נקודה שנמצאת באותו מרחק גם מ-(0,1) וגם מ-(1,0).
/// סטייה קטנה (ואצבע אמיתית תמיד סוטה) "תפסה" את התא האורתוגונלי שבאמצע,
/// והמילה התקלקלה - "תופס אותיות באמצע".
///
/// ## מה עושים כאן (הגישה של משחקי חיבור-אותיות מובילים)
///
/// 1. **מגע ראשון - שטח מלא.** הלחיצה הראשונה בוחרת את התא שנלחץ, כך
///    שקל להתחיל מכל מקום בתוך התא.
/// 2. **אחרי שהתחלנו - "עיגולי פגיעה" קטנים.** תא חדש נוסף רק כשהאצבע
///    נכנסת לעיגול ברדיוס [hitRadiusFactor] מגודל התא סביב מרכזו (כגודל
///    האות המצוירת). הפינות והמרווחים בין העיגולים הם "שטח מת" שלא בוחר
///    כלום - ובדיוק דרכם עובר המסדרון האלכסוני.
/// 3. **זיהוי כוונה אלכסונית.** כשהאצבע בזווית אלכסונית (30°-60°) ביחס
///    לתא האחרון, והתא האלכסוני שבכיוון הזה פנוי, העיגול של התאים
///    האורתוגונליים "שבדרך" מתכווץ ל-[strictOrthogonalFactor].
/// 4. **תיקון "חיתוך פינה".** אם בכל זאת נבחר תא אורתוגונלי רק בנגיעה
///    שולית (האצבע לא התקרבה למרכזו יותר מ-[grazeFactor]) והאצבע ממשיכה
///    לתא האלכסוני - התא השולי מוסר מיד מהנתיב.
/// 5. **אימות לפי מילון.** בשחרור האצבע [candidatePaths] מחזיר גם
///    חלופות: בלי תאים שנבחרו בנגיעה שולית, או עם תא שהוסר בטעות. המסך
///    בוחר את החלופה הראשונה שהיא מילה חוקית - כך מילה שהשחקן/ית
///    התכוון/ה אליה כמעט תמיד נקלטת, גם בהחלקה רשלנית.
/// 6. **דגימה צפופה וחזרה לאחור.** בין שני עדכוני מגע דוגמים נקודות
///    ביניים, כדי שהחלקה מהירה לא תדלג על תא; וחזרה לתא הקודם מבטלת את
///    האחרון.
///
/// המחלקה טהורה (בלי widgets) כדי שאפשר יהיה לבדוק אותה ביסודיות עם
/// תנועות אצבע מדומות - ראו test/game_engine/swipe_path_tracker_test.dart.
class SwipePathTracker {
  /// רדיוס הכניסה לתא חדש, כשבר מגודל התא. העיגול הוויזואלי של אריח הוא
  /// 0.4 - כלומר הכניסה לתא מתרחשת כשהאצבע נוגעת באות עצמה.
  static const double hitRadiusFactor = 0.40;

  /// רדיוס הכניסה לתא אורתוגונלי כשהאצבע בבירור בדרך לאלכסון.
  static const double strictOrthogonalFactor = 0.25;

  /// תא שהאצבע לא התקרבה למרכזו יותר מזה נחשב "נגיעה שולית".
  static const double grazeFactor = 0.27;

  /// מתחת למרחק הזה מהמרכז, התא נבחר "בכוונה" ולא יוסר גם באימות המילון.
  static const double confidentFactor = 0.12;

  /// רדיוס החזרה לתא הקודם (ביטול האות האחרונה).
  static const double backtrackRadiusFactor = 0.42;

  /// מרווח הדגימה בין שתי נקודות מגע, כשבר מגודל התא.
  static const double sampleStepFactor = 0.1;

  /// טווח הזוויות (במעלות, בתוך כל רביע) שנחשב "כוונה אלכסונית".
  static const double diagonalIntentMinDeg = 30;
  static const double diagonalIntentMaxDeg = 60;

  final int size;
  double cellSize;

  final List<GridPosition> _path = [];

  /// המרחק הקטן ביותר (בפיקסלים) בין האצבע למרכז כל תא בנתיב.
  final List<double> _closest = [];

  /// תאים שהוסרו כ"חיתוך פינה": (התא שלפני, התא שהוסר, התא שאחרי).
  final List<(GridPosition, GridPosition, GridPosition)> _droppedCorners = [];

  Offset? _lastPoint;

  SwipePathTracker({required this.size, required this.cellSize});

  List<GridPosition> get path => List.unmodifiable(_path);
  bool get isActive => _path.isNotEmpty;

  /// התאים שאפשר להוסיף כרגע לנתיב (שכנים פנויים של התא האחרון) - לשימוש
  /// ה-UI כדי לרמוז בעדינות לאן אפשר להמשיך.
  Set<GridPosition> get candidates {
    if (_path.isEmpty) return const {};
    final last = _path.last;
    return {
      for (final n in last.rawNeighbors)
        if (_inBounds(n) && !_path.contains(n)) n,
    };
  }

  Offset centerOf(GridPosition pos) =>
      Offset(pos.col * cellSize + cellSize / 2, pos.row * cellSize + cellSize / 2);

  bool _inBounds(GridPosition p) =>
      p.row >= 0 && p.row < size && p.col >= 0 && p.col < size;

  /// התא שנלחץ (חלוקה ריבועית פשוטה) - משמש רק למגע הראשון.
  GridPosition nearestCell(Offset point) {
    final col = (point.dx / cellSize).floor().clamp(0, size - 1);
    final row = (point.dy / cellSize).floor().clamp(0, size - 1);
    return GridPosition(row, col);
  }

  /// תחילת החלקה. מחזיר את התא שנבחר.
  GridPosition start(Offset point) {
    _reset();
    final cell = nearestCell(point);
    _path.add(cell);
    _closest.add((point - centerOf(cell)).distance);
    _lastPoint = point;
    return cell;
  }

  /// עדכון מיקום האצבע. מחזיר true אם הנתיב השתנה.
  bool move(Offset point) {
    if (_path.isEmpty) return false;
    final from = _lastPoint ?? point;
    _lastPoint = point;

    final distance = (point - from).distance;
    final step = cellSize * sampleStepFactor;
    final steps = math.max(1, (distance / step).ceil());
    var changed = false;
    for (int i = 1; i <= steps; i++) {
      final sample = Offset.lerp(from, point, i / steps)!;
      if (_processSample(sample)) changed = true;
    }
    return changed;
  }

  /// הנתיב הראשי ואחריו חלופות סבירות (ללא כפילויות), לפי סדר עדיפות.
  /// המסך מגיש את הראשונה שמתקבלת כמילה חוקית, ואם אף אחת לא - את הראשית.
  List<List<GridPosition>> candidatePaths({int minLength = 2}) {
    final results = <List<GridPosition>>[];
    final keys = <String>{};
    void add(List<GridPosition> p) {
      if (p.length < minLength) return;
      for (int i = 1; i < p.length; i++) {
        if (!p[i].isAdjacentTo(p[i - 1])) return;
      }
      if (p.toSet().length != p.length) return;
      if (keys.add(p.join())) results.add(p);
    }

    final primary = List<GridPosition>.from(_path);
    add(primary);

    // תאים שנבחרו רק בנגיעה שולית - אפשר לוותר עליהם אם השכנים שלהם
    // עדיין מחוברים (או אם זה התא האחרון שנכנס "בטעות" לפני השחרור).
    final optional = <int>[];
    for (int i = 1; i < primary.length; i++) {
      if (_closest[i] <= cellSize * confidentFactor) continue;
      final isLast = i == primary.length - 1;
      if (isLast) {
        if (_closest[i] > cellSize * 0.2) optional.add(i);
      } else if (primary[i - 1].isAdjacentTo(primary[i + 1])) {
        optional.add(i);
      }
    }
    // מוותרים קודם על התאים השוליים ביותר, ולכל היותר על 3 מהם.
    optional.sort((a, b) => _closest[b].compareTo(_closest[a]));
    final limited = optional.take(3).toList();
    for (int mask = 1; mask < (1 << limited.length); mask++) {
      final remove = <int>{
        for (int b = 0; b < limited.length; b++)
          if (mask & (1 << b) != 0) limited[b],
      };
      add([
        for (int i = 0; i < primary.length; i++)
          if (!remove.contains(i)) primary[i],
      ]);
    }

    // חלופות שמחזירות תא שהוסר כ"חיתוך פינה" - למקרה שהשחקן/ית באמת
    // התכוון/ה לעבור דרכו.
    for (final (before, dropped, after) in _droppedCorners) {
      for (int i = 0; i + 1 < primary.length; i++) {
        if (primary[i] == before && primary[i + 1] == after && !primary.contains(dropped)) {
          add([...primary.sublist(0, i + 1), dropped, ...primary.sublist(i + 1)]);
        }
      }
    }
    return results;
  }

  /// סיום החלקה - מחזיר את הנתיב הראשי ומאפס.
  List<GridPosition> end() {
    final result = List<GridPosition>.from(_path);
    _reset();
    return result;
  }

  void cancel() => _reset();

  void _reset() {
    _path.clear();
    _closest.clear();
    _droppedCorners.clear();
    _lastPoint = null;
  }

  bool _processSample(Offset q) {
    final lastIndex = _path.length - 1;
    final last = _path[lastIndex];
    final dLast = (q - centerOf(last)).distance;
    if (dLast < _closest[lastIndex]) _closest[lastIndex] = dLast;

    // חזרה לאחור: האצבע חזרה אל התא הקודם בנתיב.
    if (_path.length >= 2) {
      final previous = _path[lastIndex - 1];
      if ((q - centerOf(previous)).distance <= cellSize * backtrackRadiusFactor) {
        _path.removeLast();
        _closest.removeLast();
        return true;
      }
    }

    final fromLast = q - centerOf(last);
    final diagonalIntent = _diagonalDirection(fromLast);

    GridPosition? best;
    var bestRatio = double.infinity;
    var bestDistance = 0.0;
    for (final n in last.rawNeighbors) {
      if (!_inBounds(n) || _path.contains(n)) continue;
      final isOrthogonal = n.row == last.row || n.col == last.col;
      var radius = cellSize * hitRadiusFactor;
      if (isOrthogonal && diagonalIntent != null) {
        final target = GridPosition(last.row + diagonalIntent.$1, last.col + diagonalIntent.$2);
        // מחמירים רק אם התא האורתוגונלי הזה "בדרך" לאלכסון המיועד ואם
        // האלכסון עצמו זמין - אחרת אין סיבה להקשות.
        final onTheWay = n.row == target.row || n.col == target.col;
        if (onTheWay && _inBounds(target) && !_path.contains(target)) {
          radius = cellSize * strictOrthogonalFactor;
        }
      }
      final d = (q - centerOf(n)).distance;
      final ratio = d / radius;
      if (ratio <= 1 && ratio < bestRatio) {
        bestRatio = ratio;
        best = n;
        bestDistance = d;
      }
    }

    if (best == null) return false;

    // תיקון "חיתוך פינה": A → O (נגיעה שולית) → D, כש-A ו-D שכנים
    // באלכסון. השחקן/ית כמעט בוודאות רצה A → D.
    if (_path.length >= 2) {
      final a = _path[lastIndex - 1];
      final o = last;
      final grazed = _closest[lastIndex] > cellSize * grazeFactor;
      final isDiagonalFromA = best.row != a.row && best.col != a.col;
      if (grazed && isDiagonalFromA && best.isAdjacentTo(a)) {
        _path.removeLast();
        _closest.removeLast();
        _droppedCorners.add((a, o, best));
      }
    }

    _path.add(best);
    _closest.add(bestDistance);
    return true;
  }

  /// אם הווקטור מצביע בזווית אלכסונית ומספיק רחוק מהמרכז - מחזיר את
  /// כיוון האלכסון (dRow, dCol) כ-±1, אחרת null.
  (int, int)? _diagonalDirection(Offset v) {
    if (v.distance < cellSize * 0.3) return null;
    final angle = math.atan2(v.dy.abs(), v.dx.abs()) * 180 / math.pi; // 0..90
    if (angle < diagonalIntentMinDeg || angle > diagonalIntentMaxDeg) return null;
    return (v.dy.sign.toInt(), v.dx.sign.toInt());
  }
}
