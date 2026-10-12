import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../game_engine/rewards/rarity.dart';
import 'rarity_style.dart';

/// מנוע החגיגות של המשחק: זיקוקים, קונפטי, ניצוצות, גלי הלם ומטבעות נופלים.
///
/// מצויר כולו על Canvas אחד עם Ticker יחיד (ולא עשרות ווידג'טים מונפשים),
/// כך שגם חגיגה "אגדית" עם מאות חלקיקים רצה חלק בטלפון. הרעיונות לקוחים
/// מ-ClickSpark / Particles של React Bits ומ-Physics2D של GSAP (מהירות,
/// כבידה, חיכוך), ומומרים לפיזיקה פשוטה ב-Dart.
///
/// שימוש: `final key = GlobalKey<CelebrationLayerState>();` ואז
/// `key.currentState?.celebrate(Rarity.epic, center)`.
class CelebrationLayer extends StatefulWidget {
  /// נקרא בכל פיצוץ זיקוק (כדי להשמיע צליל / רטט קטן).
  final VoidCallback? onFireworkPop;

  const CelebrationLayer({super.key, this.onFireworkPop});

  @override
  State<CelebrationLayer> createState() => CelebrationLayerState();
}

enum _Kind { spark, confetti, rocket, ring, flash, coin, glitter }

class _Particle {
  _Kind kind;
  double x, y, vx, vy;
  double life = 0;
  final double maxLife;
  final double size;
  final Color color;
  double rot;
  final double vrot;
  final double gravity;
  final double drag;
  final double targetY;
  final List<Color> palette;
  final double phase;

  _Particle({
    required this.kind,
    required this.x,
    required this.y,
    this.vx = 0,
    this.vy = 0,
    required this.maxLife,
    required this.size,
    required this.color,
    this.rot = 0,
    this.vrot = 0,
    this.gravity = 0,
    this.drag = 0,
    this.targetY = 0,
    this.palette = const [],
    this.phase = 0,
  });

  double get t => (life / maxLife).clamp(0.0, 1.0);
  bool get dead => life >= maxLife;
}

class CelebrationLayerState extends State<CelebrationLayer> with SingleTickerProviderStateMixin {
  final _particles = <_Particle>[];
  final _rnd = math.Random();
  final _frame = ValueNotifier<int>(0);
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _scheduled = <({double at, VoidCallback run})>[];
  double _clock = 0;

  static const _maxParticles = 900;

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
  double get _density => _reduced ? 0.35 : 1.0;

  Size get _size => (context.findRenderObject() as RenderBox?)?.size ?? MediaQuery.sizeOf(context);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_tick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  void _ensureRunning() {
    if (!_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    }
  }

  void _after(double seconds, VoidCallback run) {
    _scheduled.add((at: _clock + seconds, run: run));
    _ensureRunning();
  }

  void _add(_Particle p) {
    if (_particles.length >= _maxParticles) return;
    _particles.add(p);
  }

  void _tick(Duration elapsed) {
    final dt = _last == Duration.zero ? 1 / 60 : ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 1 / 20);
    _last = elapsed;
    _clock += dt;

    if (_scheduled.isNotEmpty) {
      final due = _scheduled.where((s) => s.at <= _clock).toList();
      _scheduled.removeWhere((s) => s.at <= _clock);
      for (final s in due) {
        s.run();
      }
    }

    final spawned = <_Particle>[];
    for (final p in _particles) {
      p.life += dt;
      if (p.kind == _Kind.ring || p.kind == _Kind.flash) continue;
      p.vy += p.gravity * dt;
      if (p.drag > 0) {
        final k = math.exp(-p.drag * dt);
        p.vx *= k;
        p.vy *= k;
      }
      if (p.kind == _Kind.confetti) {
        // "רפרוף" - קונפטי נע מצד לצד כשהוא נופל.
        p.vx += math.sin(_clock * 6 + p.phase) * 60 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      p.rot += p.vrot * dt;
      if (p.kind == _Kind.rocket && _rnd.nextDouble() < 0.8) {
        // שובל של גצים קטנים מאחורי הטיל.
        spawned.add(_Particle(
          kind: _Kind.spark,
          x: p.x + (_rnd.nextDouble() - 0.5) * 4,
          y: p.y + 6,
          vx: (_rnd.nextDouble() - 0.5) * 40,
          vy: 40 + _rnd.nextDouble() * 60,
          maxLife: 0.35 + _rnd.nextDouble() * 0.25,
          size: 1.4 + _rnd.nextDouble(),
          color: _rnd.nextBool() ? const Color(0xFFFFE9A8) : p.color,
          drag: 3,
          gravity: 120,
        ));
      }
      if (p.kind == _Kind.rocket && (p.vy >= -60 || p.y <= p.targetY)) {
        p.life = p.maxLife;
        spawned.addAll(_explosion(p.x, p.y, p.palette, big: p.size > 1));
      }
    }
    _particles.removeWhere((p) => p.dead);
    var popped = false;
    for (final p in spawned) {
      if (p.kind == _Kind.flash) popped = true;
      _add(p);
    }
    if (popped) widget.onFireworkPop?.call();

    _frame.value++;
    if (_particles.isEmpty && _scheduled.isEmpty) _ticker.stop();
  }

  Color _pick(List<Color> colors) => colors[_rnd.nextInt(colors.length)];

  // ---------------------------------------------------------------- פעולות

  /// התפרצות ניצוצות מנקודה (כמו ClickSpark) - משוב ללחיצה.
  void sparks(Offset at, List<Color> colors, {int count = 14, double speed = 420, double life = 0.55}) {
    final n = (count * _density).round().clamp(4, 200);
    for (var i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + _rnd.nextDouble() * 0.4;
      final v = speed * (0.55 + _rnd.nextDouble() * 0.6);
      _add(_Particle(
        kind: _Kind.spark,
        x: at.dx,
        y: at.dy,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
        maxLife: life * (0.7 + _rnd.nextDouble() * 0.5),
        size: 2.2 + _rnd.nextDouble() * 1.6,
        color: _pick(colors),
        drag: 4.2,
        gravity: 260,
      ));
    }
    _ensureRunning();
  }

  /// גל הלם - טבעת מתרחבת.
  void shockwave(Offset at, Color color, {double radius = 220, double life = 0.6, double width = 10}) {
    _add(_Particle(kind: _Kind.ring, x: at.dx, y: at.dy, maxLife: life, size: radius, color: color, drag: width));
    _ensureRunning();
  }

  /// הבזק אור מעגלי.
  void flash(Offset at, Color color, {double radius = 260, double life = 0.45}) {
    _add(_Particle(kind: _Kind.flash, x: at.dx, y: at.dy, maxLife: life, size: radius, color: color));
    _ensureRunning();
  }

  /// "תותחי קונפטי" משני צדי המסך התחתונים.
  void confettiCannons(List<Color> colors, {int count = 90}) {
    final size = _size;
    final n = (count * _density).round();
    for (var side = 0; side < 2; side++) {
      for (var i = 0; i < n ~/ 2; i++) {
        final left = side == 0;
        final a = (left ? -math.pi / 2 + 0.25 : -math.pi / 2 - 0.25) + (_rnd.nextDouble() - 0.5) * 0.7;
        final v = 900 + _rnd.nextDouble() * 650;
        _add(_Particle(
          kind: _Kind.confetti,
          x: left ? -10 : size.width + 10,
          y: size.height * 0.92,
          vx: math.cos(a) * v * (left ? 1 : 1) + (left ? 120 : -120),
          vy: math.sin(a) * v,
          maxLife: 2.6 + _rnd.nextDouble() * 1.4,
          size: 7 + _rnd.nextDouble() * 6,
          color: _pick(colors),
          rot: _rnd.nextDouble() * math.pi,
          vrot: (_rnd.nextDouble() - 0.5) * 18,
          gravity: 900,
          drag: 2.2,
          phase: _rnd.nextDouble() * 10,
        ));
      }
    }
    _ensureRunning();
  }

  /// קונפטי שנופל מלמעלה (גשם חגיגי).
  void confettiRain(List<Color> colors, {int count = 60, double duration = 1.6}) {
    final size = _size;
    final n = (count * _density).round();
    for (var i = 0; i < n; i++) {
      _after(_rnd.nextDouble() * duration, () {
        _add(_Particle(
          kind: _Kind.confetti,
          x: _rnd.nextDouble() * size.width,
          y: -20,
          vx: (_rnd.nextDouble() - 0.5) * 80,
          vy: 120 + _rnd.nextDouble() * 160,
          maxLife: 3.5,
          size: 7 + _rnd.nextDouble() * 5,
          color: _pick(colors),
          rot: _rnd.nextDouble() * math.pi,
          vrot: (_rnd.nextDouble() - 0.5) * 14,
          gravity: 90,
          drag: 0.6,
          phase: _rnd.nextDouble() * 10,
        ));
      });
    }
  }

  /// זיקוק: טיל שעולה מלמטה ומתפוצץ בגובה [targetY].
  void firework({double? x, double? targetY, List<Color>? colors, bool big = false}) {
    final size = _size;
    final fx = x ?? size.width * (0.15 + _rnd.nextDouble() * 0.7);
    final ty = targetY ?? size.height * (0.12 + _rnd.nextDouble() * 0.3);
    final palette = colors ?? const [Color(0xFFFFE066), Color(0xFFFF7A45), Color(0xFFFFFFFF)];
    final dist = size.height + 20 - ty;
    // מהירות התחלתית כך שיגיע בדיוק לגובה היעד (v² = 2gh).
    const g = 900.0;
    final vy = -math.sqrt(2 * g * dist);
    _add(_Particle(
      kind: _Kind.rocket,
      x: fx,
      y: size.height + 20,
      vx: (_rnd.nextDouble() - 0.5) * 60,
      vy: vy,
      maxLife: 4,
      size: big ? 2 : 1,
      color: palette.first,
      gravity: g,
      targetY: ty,
      palette: palette,
    ));
    _ensureRunning();
  }

  List<_Particle> _explosion(double x, double y, List<Color> palette, {bool big = false}) {
    final out = <_Particle>[];
    final n = ((big ? 90 : 60) * _density).round();
    final speed = big ? 420.0 : 330.0;
    final main = _pick(palette);
    out.add(_Particle(kind: _Kind.flash, x: x, y: y, maxLife: 0.3, size: big ? 150 : 100, color: main));
    for (var i = 0; i < n; i++) {
      final a = _rnd.nextDouble() * math.pi * 2;
      // פיזור "כדורי" - יותר ניצוצות בקצה החיצוני.
      final v = speed * math.sqrt(_rnd.nextDouble()) * (0.75 + _rnd.nextDouble() * 0.35);
      final color = _rnd.nextDouble() < 0.65 ? main : _pick(palette);
      out.add(_Particle(
        kind: _rnd.nextDouble() < 0.25 ? _Kind.glitter : _Kind.spark,
        x: x,
        y: y,
        vx: math.cos(a) * v,
        vy: math.sin(a) * v,
        maxLife: 1.1 + _rnd.nextDouble() * 0.7,
        size: 2 + _rnd.nextDouble() * 1.8,
        color: color,
        drag: 2.1,
        gravity: 150,
        phase: _rnd.nextDouble() * 20,
      ));
    }
    return out;
  }

  /// גשם מטבעות זהב (פרסים גדולים).
  void coinShower({int count = 40, double duration = 1.4}) {
    final size = _size;
    final n = (count * _density).round();
    for (var i = 0; i < n; i++) {
      _after(_rnd.nextDouble() * duration, () {
        _add(_Particle(
          kind: _Kind.coin,
          x: 20 + _rnd.nextDouble() * (size.width - 40),
          y: -30,
          vx: (_rnd.nextDouble() - 0.5) * 60,
          vy: 200 + _rnd.nextDouble() * 200,
          maxLife: 3,
          size: 11 + _rnd.nextDouble() * 7,
          color: const Color(0xFFFFC93C),
          rot: _rnd.nextDouble() * math.pi * 2,
          vrot: 6 + _rnd.nextDouble() * 8,
          gravity: 700,
          drag: 0.3,
        ));
      });
    }
  }

  /// החגיגה המלאה של פתיחת פרס - עוצמה לפי הדרגה.
  void celebrate(Rarity rarity, Offset center) {
    final style = RarityStyle.of(rarity);
    final colors = style.particles;
    flash(center, style.light, radius: 220 + 260 * style.intensity, life: 0.5);
    shockwave(center, style.glow, radius: 200 + 260 * style.intensity, width: 14);
    sparks(center, colors, count: (26 + 60 * style.intensity).round(), speed: 520 + 420 * style.intensity, life: 0.9);
    if (rarity.index >= Rarity.uncommon.index) {
      _after(0.12, () => shockwave(center, style.light, radius: 160 + 200 * style.intensity, life: 0.7, width: 6));
    }
    if (rarity.index >= Rarity.rare.index) {
      confettiCannons(colors, count: (60 + 120 * style.intensity).round());
    }
    final size = _size;
    for (var i = 0; i < style.fireworks; i++) {
      final delay = 0.25 + i * (rarity == Rarity.legendary ? 0.22 : 0.32) + _rnd.nextDouble() * 0.12;
      _after(delay, () {
        firework(
          x: size.width * (0.12 + _rnd.nextDouble() * 0.76),
          targetY: size.height * (0.1 + _rnd.nextDouble() * 0.32),
          colors: colors,
          big: rarity == Rarity.legendary || _rnd.nextDouble() < 0.3,
        );
      });
    }
    if (rarity.index >= Rarity.epic.index) {
      _after(0.5, () => confettiRain(colors, count: rarity == Rarity.legendary ? 110 : 60));
    }
    if (rarity == Rarity.legendary) {
      _after(0.35, () => coinShower(count: 46));
      _after(1.4, () => confettiCannons(colors, count: 120));
    }
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _CelebrationPainter(_particles, _frame, () => _clock),
        ),
      ),
    );
  }
}

class _CelebrationPainter extends CustomPainter {
  final List<_Particle> particles;
  final double Function() clock;

  _CelebrationPainter(this.particles, Listenable repaint, this.clock) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (particles.isEmpty) return;
    final add = Paint()..blendMode = BlendMode.plus;
    final normal = Paint();
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..blendMode = BlendMode.plus;
    final now = clock();

    for (final p in particles) {
      final t = p.t;
      switch (p.kind) {
        case _Kind.flash:
          final a = (1 - t) * (1 - t);
          final r = p.size * (0.6 + 0.4 * Curves.easeOut.transform(t));
          add.shader = ui.Gradient.radial(
            Offset(p.x, p.y),
            r,
            [p.color.withValues(alpha: 0.85 * a), p.color.withValues(alpha: 0)],
          );
          canvas.drawCircle(Offset(p.x, p.y), r, add);
          add.shader = null;
        case _Kind.ring:
          final e = const Cubic(0.23, 1, 0.32, 1).transform(t);
          stroke
            ..color = p.color.withValues(alpha: (1 - t) * 0.9)
            ..strokeWidth = math.max(0.5, p.drag * (1 - t));
          canvas.drawCircle(Offset(p.x, p.y), p.size * e, stroke);
        case _Kind.spark:
        case _Kind.glitter:
        case _Kind.rocket:
          var alpha = p.kind == _Kind.rocket ? 1.0 : (1 - t * t);
          if (p.kind == _Kind.glitter && t > 0.45) {
            // נצנוץ מהבהב בסוף החיים של הניצוץ.
            alpha *= (math.sin(now * 40 + p.phase) > 0) ? 1 : 0.15;
          }
          // שובל: קו מהמיקום הקודם (לפי המהירות) למיקום הנוכחי.
          final tail = p.kind == _Kind.rocket ? 0.05 : 0.035;
          stroke
            ..color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0))
            ..strokeWidth = p.size * (p.kind == _Kind.rocket ? 1.8 : 1);
          canvas.drawLine(Offset(p.x - p.vx * tail, p.y - p.vy * tail), Offset(p.x, p.y), stroke);
          if (p.kind == _Kind.rocket) {
            add.color = const Color(0xFFFFFFFF);
            canvas.drawCircle(Offset(p.x, p.y), 3, add);
          }
        case _Kind.confetti:
          final alpha = t > 0.8 ? (1 - t) / 0.2 : 1.0;
          normal.color = p.color.withValues(alpha: alpha.clamp(0.0, 1.0));
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.rotate(p.rot);
          // "היפוך" תלת-ממדי - הרוחב מתכווץ ומתרחב כאילו הפתית מסתובב באוויר.
          canvas.scale(1, math.cos(p.rot * 1.7 + p.phase).abs() * 0.8 + 0.2);
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: p.size, height: p.size * 0.6), const Radius.circular(1.5)),
            normal,
          );
          canvas.restore();
        case _Kind.coin:
          final alpha = t > 0.85 ? (1 - t) / 0.15 : 1.0;
          final flip = math.cos(p.rot);
          canvas.save();
          canvas.translate(p.x, p.y);
          canvas.scale(flip.abs() * 0.9 + 0.1, 1);
          normal.color = const Color(0xFFE08A00).withValues(alpha: alpha);
          canvas.drawCircle(Offset.zero, p.size, normal);
          normal.color = (flip > 0 ? const Color(0xFFFFD84D) : const Color(0xFFFFC21A)).withValues(alpha: alpha);
          canvas.drawCircle(Offset.zero, p.size * 0.82, normal);
          normal.color = const Color(0xFFFFF4B5).withValues(alpha: alpha * 0.9);
          canvas.drawRect(Rect.fromCenter(center: Offset(-p.size * 0.15, 0), width: p.size * 0.22, height: p.size * 0.9), normal);
          canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant _CelebrationPainter oldDelegate) => true;
}
