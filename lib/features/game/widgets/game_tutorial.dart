import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/ui/candy_button.dart';
import '../../../core/ui/pressable.dart';
import '../../../game_engine/models/grid_position.dart';

/// שלבי ההדרכה של שלב 1 (בפעם הראשונה בלבד).
enum TutorialStep {
  /// מנסים בעצמכם: גוררים על האותיות הזוהרות כדי לכתוב את המילה.
  drag,

  /// הנקודות והכוכבים - זרקור על פס היעד (שכבר התמלא קצת מהמילה הראשונה).
  score,

  /// השעון והעזרה - זרקור על הטיימר ועל כפתורי העזרה, ואז מתחילים.
  timer,
}

/// הדרכה אינטראקטיבית בתוך המשחק: "זרקור" שמחשיך את המסך סביב מה שמסבירים,
/// כרטיס הסבר עם הבלש שתמיד עומד *מחוץ* לאזור המוסבר, ו"אצבע רפאים" שמדגימה
/// את הגרירה על הלוח. בשלב הגרירה הלוח עצמו פתוח למגע - לומדים תוך כדי משחק.
///
/// הזרקור גולש בין המטרות, הכרטיסים מתהפכים פנימה בתלת-ממד, ובהצלחה יש
/// פיצוץ ניצוצות. בכל שלב אפשר לדלג.
class GameTutorialOverlay extends StatefulWidget {
  final TutorialStep step;

  /// המילה להדגמה (בכתיב תצוגה), והנתיב שלה על הלוח.
  final String word;
  final List<GridPosition> path;
  final int gridSize;

  final GlobalKey boardKey;
  final GlobalKey goalKey;
  final GlobalKey timerKey;
  final GlobalKey powersKey;

  /// השחקן/ית גורר/ת עכשיו - מסתירים את אצבע ההדגמה.
  final bool userDragging;

  /// עולה בכל ניסיון שלא הצליח בשלב הגרירה (מנער את הכרטיס ומשנה ניסוח).
  final int nudge;

  /// נמצאה מילה בשלב הגרירה - חגיגה קצרה לפני המעבר לשלב הבא.
  final bool celebrating;

  final VoidCallback onNext;
  final VoidCallback onSkip;

  const GameTutorialOverlay({
    super.key,
    required this.step,
    required this.word,
    required this.path,
    required this.gridSize,
    required this.boardKey,
    required this.goalKey,
    required this.timerKey,
    required this.powersKey,
    required this.userDragging,
    required this.nudge,
    required this.celebrating,
    required this.onNext,
    required this.onSkip,
  });

  @override
  State<GameTutorialOverlay> createState() => _GameTutorialOverlayState();
}

class _GameTutorialOverlayState extends State<GameTutorialOverlay> with TickerProviderStateMixin {
  /// מעבר הזרקור בין מטרות.
  late final AnimationController _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 520))
    ..value = 1;

  /// דופק הטבעת הזוהרת סביב הזרקור + האצבע המדגימה (לולאה).
  late final AnimationController _loop = AnimationController(vsync: this, duration: const Duration(milliseconds: 2800))
    ..repeat();

  /// פיצוץ הניצוצות בהצלחה.
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );

  List<Rect> _from = const [];
  List<Rect> _to = const [];
  Rect? _board;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure(animate: false));
  }

  @override
  void didUpdateWidget(GameTutorialOverlay old) {
    super.didUpdateWidget(old);
    if (old.step != widget.step) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(animate: true));
    }
    if (widget.celebrating && !old.celebrating) _burst.forward(from: 0);
  }

  @override
  void dispose() {
    _morph.dispose();
    _loop.dispose();
    _burst.dispose();
    super.dispose();
  }

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    final me = context.findRenderObject() as RenderBox?;
    if (box == null || me == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero, ancestor: me);
    return topLeft & box.size;
  }

  List<Rect> _targetsFor(TutorialStep step) {
    final keys = switch (step) {
      TutorialStep.drag => [widget.boardKey],
      TutorialStep.score => [widget.goalKey],
      TutorialStep.timer => [widget.timerKey, widget.powersKey],
    };
    return [
      for (final k in keys)
        if (_rectOf(k) case final r?) r.inflate(step == TutorialStep.drag ? 6 : 8),
    ];
  }

  void _measure({required bool animate}) {
    if (!mounted) return;
    final next = _targetsFor(widget.step);
    final board = _rectOf(widget.boardKey);
    if (next.isEmpty) {
      // עוד לא נפרס - מנסים שוב בפריים הבא.
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure(animate: animate));
      return;
    }
    setState(() {
      _from = animate && _to.isNotEmpty ? _currentHoles() : next;
      _to = next;
      _board = board;
    });
    if (animate) {
      _morph.forward(from: 0);
    } else {
      _morph.value = 1;
    }
  }

  List<Rect> _currentHoles() {
    final t = Curves.easeOutCubic.transform(_morph.value);
    final n = math.max(_from.length, _to.length);
    if (n == 0) return const [];
    Rect at(List<Rect> list, int i) => list.isEmpty ? _to.first : list[math.min(i, list.length - 1)];
    return [for (int i = 0; i < n; i++) Rect.lerp(at(_from, i), at(_to, i), t)!];
  }

  @override
  Widget build(BuildContext context) {
    // מודדים מחדש אחרי כל בנייה (סיבוב מסך, שינוי גודל) - בלי אנימציה.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _morph.isAnimating) return;
      final next = _targetsFor(widget.step);
      if (next.isNotEmpty && !_sameRects(next, _to)) _measure(animate: false);
    });

    final interactiveHoles = widget.step == TutorialStep.drag && !widget.celebrating;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return Stack(
          children: [
            // ההחשכה + הזרקור. בשלב הגרירה החור "פתוח" למגע.
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_morph, _loop]),
                builder: (context, _) {
                  final holes = _currentHoles();
                  return _HoleBarrier(
                    holes: interactiveHoles ? holes : const [],
                    child: CustomPaint(
                      painter: _SpotlightPainter(holes: holes, pulse: _loop.value),
                    ),
                  );
                },
              ),
            ),
            if (widget.step == TutorialStep.drag && _board != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 200),
                    opacity: widget.userDragging || widget.celebrating ? 0 : 1,
                    child: AnimatedBuilder(
                      animation: _loop,
                      builder: (context, _) => CustomPaint(
                        painter: _GhostFingerPainter(
                          board: _board!,
                          gridSize: widget.gridSize,
                          path: widget.path,
                          t: _loop.value,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            if (_board != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: _burst,
                    builder: (context, _) => CustomPaint(
                      painter: _BurstPainter(center: _board!.center, t: _burst.value, radius: _board!.width * 0.55),
                    ),
                  ),
                ),
              ),
            if (_to.isNotEmpty) _card(size),
          ],
        );
      },
    );
  }

  bool _sameRects(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if ((a[i].topLeft - b[i].topLeft).distance > 1 ||
          (a[i].width - b[i].width).abs() > 1 ||
          (a[i].height - b[i].height).abs() > 1) {
        return false;
      }
    }
    return true;
  }

  /// הכרטיס תמיד מחוץ לאזור המוסבר: מעל הלוח בשלב הגרירה, ומתחת למטרות בשאר.
  Widget _card(Size size) {
    final targets = _to;
    final top = targets.map((r) => r.top).reduce(math.min);
    final bottom = targets.map((r) => r.bottom).reduce(math.max);
    final above = widget.step == TutorialStep.drag;
    final card = _CoachCard(
      key: ValueKey('${widget.step}-${widget.celebrating}-${widget.nudge > 0}'),
      step: widget.step,
      word: widget.word,
      nudge: widget.nudge,
      celebrating: widget.celebrating,
      onNext: widget.onNext,
      onSkip: widget.onSkip,
    );
    final switcher = AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutBack,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) => AnimatedBuilder(
        animation: animation,
        child: child,
        builder: (context, child) {
          // היפוך תלת-ממדי: הכרטיס "נופל" פנימה סביב הציר האופקי.
          final v = animation.value;
          return Opacity(
            opacity: v.clamp(0.0, 1.0),
            child: Transform(
              alignment: above ? Alignment.bottomCenter : Alignment.topCenter,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.0016)
                ..rotateX((1 - v) * (above ? -1.1 : 1.1))
                ..scaleByDouble(0.86 + 0.14 * v, 0.86 + 0.14 * v, 1, 1),
              child: child,
            ),
          );
        },
      ),
      layoutBuilder: (current, previous) =>
          Stack(alignment: above ? Alignment.bottomCenter : Alignment.topCenter, children: [...previous, ?current]),
      child: card,
    );
    final safeTop = MediaQuery.paddingOf(context).top + 8;
    return Positioned(
      left: 14,
      right: 14,
      top: above ? null : math.min(bottom + 14, size.height - 230),
      bottom: above ? math.max(size.height - top + 12, 0) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: above ? math.max(120, top - safeTop) : 260),
        child: Align(alignment: above ? Alignment.bottomCenter : Alignment.topCenter, child: switcher),
      ),
    );
  }
}

/// כרטיס ההסבר: הבלש, כותרת, טקסט קצר, נקודות התקדמות, "דלג" וכפתור המשך.
class _CoachCard extends StatelessWidget {
  final TutorialStep step;
  final String word;
  final int nudge;
  final bool celebrating;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  const _CoachCard({
    super.key,
    required this.step,
    required this.word,
    required this.nudge,
    required this.celebrating,
    required this.onNext,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final first = word.characters.isEmpty ? '' : word.characters.first;
    final (title, body, pose) = switch (step) {
      TutorialStep.drag when celebrating => (
        'מעולה! מצאתם מילה 🎉',
        'ככה משחקים - עוד שני דברים קטנים ומתחילים.',
        'assets/avatar/detective_celebrate.png',
      ),
      TutorialStep.drag when nudge > 0 => (
        'כמעט! 💪',
        'עקבו אחרי האצבע: מתחילים ב-"$first" ומחליקים בלי להרים עד סוף המילה "$word".',
        'assets/avatar/detective_explain.png',
      ),
      TutorialStep.drag => (
        'בואו ננסה! 👆',
        'גררו אצבע על האותיות הזוהרות, בלי להרים, כדי לכתוב "$word".',
        'assets/avatar/detective_default.png',
      ),
      TutorialStep.score => (
        'צוברים נקודות ⭐',
        'כל מילה שווה נקודות, ומילה ארוכה שווה יותר. מלאו את הפס כדי לזכות ב-3 כוכבים.',
        'assets/avatar/detective_explain.png',
      ),
      TutorialStep.timer => (
        'השעון והעזרה ⏱️',
        'לכל שלב יש זמן - השעון מתחיל כשממשיכים. נתקעתם? כאן מגלים אות או מערבבים, ו-💡 למעלה נותן רמז.',
        'assets/avatar/detective_explain.png',
      ),
    };

    Widget content = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF6F1FF)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: AppColors.accent.withValues(alpha: 0.35), blurRadius: 26, spreadRadius: 1),
          const BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image.asset(pose, height: 74, gaplessPlayback: true)
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .moveY(begin: 0, end: -4, duration: 900.ms, curve: Curves.easeInOut),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 19, color: AppColors.textDark),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      body,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14.5,
                        height: 1.3,
                        color: AppColors.textDark.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _StepDots(current: step.index),
              const Spacer(),
              if (step != TutorialStep.timer)
                Pressable(
                  onTap: onSkip,
                  semanticLabel: 'דילוג על ההדרכה',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(
                      'דלג',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textDark.withValues(alpha: 0.55),
                      ),
                    ),
                  ),
                ),
              if (step != TutorialStep.drag) ...[
                const SizedBox(width: 6),
                SizedBox(
                  width: step == TutorialStep.timer ? 190 : 120,
                  child: CandyButton(
                    label: step == TutorialStep.timer ? 'יאללה, משחקים!' : 'הבא',
                    icon: step == TutorialStep.timer ? Icons.play_arrow_rounded : Icons.arrow_back_rounded,
                    palette: CandyPalette.green,
                    height: 46,
                    fontSize: 16,
                    onPressed: onNext,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (nudge > 0 && step == TutorialStep.drag && !celebrating) {
      content = content.animate(key: ValueKey(nudge)).shakeX(hz: 5, amount: 6, duration: 420.ms);
    }
    if (celebrating) {
      content = content.animate().scaleXY(begin: 0.92, end: 1, duration: 500.ms, curve: Curves.elasticOut);
    }
    return content;
  }
}

class _StepDots extends StatelessWidget {
  final int current;

  const _StepDots({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < TutorialStep.values.length; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            curve: Curves.easeOutBack,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == current ? 22 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: i <= current ? AppColors.accent : AppColors.accent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// שכבה שבולעת מגע בכל המסך חוץ מה"חורים" (שם המגע עובר ללוח שמתחת).
class _HoleBarrier extends SingleChildRenderObjectWidget {
  final List<Rect> holes;

  const _HoleBarrier({required this.holes, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderHoleBarrier(holes);

  @override
  void updateRenderObject(BuildContext context, _RenderHoleBarrier renderObject) => renderObject.holes = holes;
}

class _RenderHoleBarrier extends RenderProxyBox {
  _RenderHoleBarrier(this.holes);

  List<Rect> holes;

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    if (!size.contains(position) || holes.any((h) => h.contains(position))) return false;
    result.add(BoxHitTestEntry(this, position));
    return true;
  }
}

/// החשכה עם "חורים" מעוגלים וטבעת זוהרת פועמת סביבם.
class _SpotlightPainter extends CustomPainter {
  final List<Rect> holes;
  final double pulse;

  _SpotlightPainter({required this.holes, required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    // even-odd (ולא Path.combine) - עובד זהה גם באתר וגם באפליקציה.
    final rrects = [for (final h in holes) RRect.fromRectAndRadius(h, const Radius.circular(22))];
    final dim = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(Offset.zero & size);
    for (final r in rrects) {
      dim.addRRect(r);
    }
    canvas.drawPath(dim, Paint()..color = const Color(0xFF120A2E).withValues(alpha: 0.68));

    final wave = 0.5 + 0.5 * math.sin(pulse * 2 * math.pi * 2);
    for (final r in rrects) {
      canvas.drawRRect(
        r.inflate(2 + wave * 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = AppColors.star.withValues(alpha: 0.18 + 0.22 * (1 - wave))
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawRRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = Colors.white.withValues(alpha: 0.9),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SpotlightPainter old) => true;
}

/// אצבע רפאים שמדגימה גרירה לאורך נתיב המילה, עם שובל זוהר וגל לחיצה.
class _GhostFingerPainter extends CustomPainter {
  final Rect board;
  final int gridSize;
  final List<GridPosition> path;
  final double t;

  _GhostFingerPainter({required this.board, required this.gridSize, required this.path, required this.t});

  Offset _center(GridPosition p) {
    final cell = board.width / gridSize;
    return board.topLeft + Offset((p.col + 0.5) * cell, (p.row + 0.5) * cell);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (path.isEmpty) return;
    final points = [for (final p in path) _center(p)];
    // 0-0.14 לחיצה, 0.14-0.72 תנועה, 0.72-0.86 הרמה, ואז הפסקה קצרה.
    const pressEnd = 0.14;
    const moveEnd = 0.72;
    const liftEnd = 0.86;
    double progress;
    double alpha;
    double press;
    if (t < pressEnd) {
      progress = 0;
      alpha = t / pressEnd;
      press = t / pressEnd;
    } else if (t < moveEnd) {
      progress = Curves.easeInOut.transform((t - pressEnd) / (moveEnd - pressEnd));
      alpha = 1;
      press = 1;
    } else if (t < liftEnd) {
      progress = 1;
      alpha = 1 - (t - moveEnd) / (liftEnd - moveEnd);
      press = alpha;
    } else {
      return;
    }

    final segments = points.length - 1;
    final pos = segments == 0 ? 0.0 : progress * segments;
    final seg = math.min(pos.floor(), math.max(0, segments - 1));
    final local = pos - seg;
    final tip = segments == 0 ? points.first : Offset.lerp(points[seg], points[seg + 1], local)!;

    // שובל: מהאות הראשונה עד מיקום האצבע.
    final trail = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i <= seg; i++) {
      trail.lineTo(points[i].dx, points[i].dy);
    }
    trail.lineTo(tip.dx, tip.dy);
    final cell = board.width / gridSize;
    canvas.drawPath(
      trail,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = cell * 0.22
        ..color = Colors.white.withValues(alpha: 0.45 * alpha),
    );

    // גל לחיצה בתחילת הגרירה.
    if (t < pressEnd + 0.08) {
      final r = cell * (0.25 + 0.4 * (t / (pressEnd + 0.08)));
      canvas.drawCircle(
        points.first,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = Colors.white.withValues(alpha: 0.7 * (1 - t / (pressEnd + 0.08))),
      );
    }

    // קצה האצבע + כף יד מאוירת קטנה.
    final fingerR = cell * (0.17 - 0.03 * press);
    canvas.drawCircle(tip, fingerR + 6, Paint()..color = Colors.white.withValues(alpha: 0.25 * alpha));
    canvas.drawCircle(tip, fingerR, Paint()..color = Colors.white.withValues(alpha: 0.95 * alpha));
    final icon = Icons.touch_app_rounded;
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: cell * 0.62,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white.withValues(alpha: alpha),
          shadows: [Shadow(color: Colors.black.withValues(alpha: 0.45 * alpha), blurRadius: 8)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    // האייקון מצביע עם האצבע למעלה-שמאלה: מזיזים כך שהקצה ייפול על הנקודה.
    tp.paint(canvas, tip - Offset(tp.width * 0.36, tp.height * 0.08));
  }

  @override
  bool shouldRepaint(covariant _GhostFingerPainter old) => old.t != t || old.board != board;
}

/// פיצוץ ניצוצות וכוכבים כשמוצאים את המילה הראשונה.
class _BurstPainter extends CustomPainter {
  final Offset center;
  final double t;
  final double radius;

  _BurstPainter({required this.center, required this.t, required this.radius});

  static const _colors = [Color(0xFFFFC93C), Color(0xFFFF6F91), Color(0xFF7C4DFF), Color(0xFF4CD97B), Colors.white];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    final ease = Curves.easeOutCubic.transform(t);
    final fade = 1 - Curves.easeIn.transform(t);
    for (int i = 0; i < 26; i++) {
      final rng = math.Random(i * 97 + 3);
      final angle = rng.nextDouble() * math.pi * 2;
      final dist = radius * (0.35 + rng.nextDouble() * 0.75) * ease;
      final fall = 60 * t * t;
      final p = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist + fall);
      final color = _colors[i % _colors.length].withValues(alpha: fade);
      final s = 4 + rng.nextDouble() * 5;
      if (i.isEven) {
        _star(canvas, p, s * 1.4, angle + t * 4, color);
      } else {
        canvas.save();
        canvas.translate(p.dx, p.dy);
        canvas.rotate(angle + t * 6);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: s * 1.6, height: s * 0.8),
            const Radius.circular(2),
          ),
          Paint()..color = color,
        );
        canvas.restore();
      }
    }
  }

  void _star(Canvas canvas, Offset c, double r, double rot, Color color) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final a = rot + i * math.pi / 5;
      final rr = i.isEven ? r : r * 0.45;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path..close(), Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _BurstPainter old) => old.t != t || old.center != center;
}
