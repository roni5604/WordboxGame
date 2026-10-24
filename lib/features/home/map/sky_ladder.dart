import 'dart:math' as math;

import 'package:flutter/material.dart';

/// הסולם לשמיים בסוף מפת השלבים: אחרי השלב האחרון השביל מגיע לרחבה
/// זוהרת, וממנה סולם עץ עם שליבות שנדלקות אחת אחרי השנייה כלפי מעלה,
/// גפנים, ניצוצות עולים, ועננים שמסתירים את ה"אי המרחף" - העולם הבא.
/// מצויר כולו בקוד (בלי נכסי אמנות) ומונפש לפי שעון האווירה של המפה.
class SkyLadder extends StatelessWidget {
  static const double width = 250;
  static const double height = 450;

  final Animation<double> ambient;
  final VoidCallback? onTap;

  const SkyLadder({super.key, required this.ambient, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'סולם לשמיים - העולם הבא בדרך',
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: onTap,
        child: SizedBox(
          width: width,
          height: height,
          child: AnimatedBuilder(
            animation: ambient,
            builder: (context, _) {
              final t = ambient.value * 40;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(child: CustomPaint(painter: _SkyLadderPainter(t))),
                  // תגית "העולם הבא" שמרחפת על הענן העליון.
                  Positioned(
                    top: 58 + math.sin(t * 1.3) * 4,
                    left: 0,
                    right: 0,
                    child: const Center(
                      child: FittedBox(fit: BoxFit.scaleDown, child: _NextWorldBadge()),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _NextWorldBadge extends StatelessWidget {
  const _NextWorldBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 5, 12, 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFA62B)]),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB300).withValues(alpha: 0.6), blurRadius: 14)],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_clock_rounded, size: 15, color: Color(0xFF6B3A00)),
          SizedBox(width: 4),
          Text(
            'העולם הבא · בקרוב',
            style: TextStyle(color: Color(0xFF6B3A00), fontSize: 13, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _SkyLadderPainter extends CustomPainter {
  final double t;

  _SkyLadderPainter(this.t);

  static const _wood = Color(0xFFB9774A);
  static const _woodLight = Color(0xFFE2A774);
  static const _woodDark = Color(0xFF6E3F1E);
  static const _gold = Color(0xFFFFD54F);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    const top = 120.0; // קצה הסולם נבלע בענן.
    final bottom = h - 6;

    _paintIsland(canvas, Offset(cx, 70), w);
    _paintStars(canvas, size);

    // הילה זהובה לאורך הסולם.
    final glowRect = Rect.fromLTRB(cx - 80, top, cx + 80, bottom);
    canvas.drawRect(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          radius: 0.9,
          colors: [_gold.withValues(alpha: 0.28), _gold.withValues(alpha: 0)],
        ).createShader(glowRect)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // שני מסילות שמתקרבות זו לזו למעלה (פרספקטיבה של גובה).
    Offset rail(double side, double k) {
      final y = bottom - (bottom - top) * k;
      final half = 44 - 22 * k;
      return Offset(cx + side * half, y);
    }

    // שליבות - כל שליבה נדלקת כשגל האור "מטפס" דרכה.
    const rungs = 13;
    final wave = (t * 0.32) % 1.4 - 0.2;
    for (var i = 0; i < rungs; i++) {
      final k = (i + 0.6) / (rungs + 0.4);
      final a = rail(-1, k);
      final b = rail(1, k);
      final lit = math.max(0.0, 1 - (k - wave).abs() * 6);
      final thickness = 9 - 4 * k;
      final rect = Rect.fromLTRB(a.dx - 2, a.dy - thickness / 2, b.dx + 2, a.dy + thickness / 2);
      final rr = RRect.fromRectAndRadius(rect, Radius.circular(thickness / 2));
      canvas.drawRRect(rr.shift(const Offset(0, 2.5)), Paint()..color = _woodDark.withValues(alpha: 0.6));
      canvas.drawRRect(rr, Paint()..color = Color.lerp(_wood, _gold, lit)!);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(rect.left + 3, rect.top + 1, rect.right - 3, rect.top + thickness * 0.4),
          Radius.circular(thickness / 2),
        ),
        Paint()..color = Color.lerp(_woodLight, Colors.white, lit)!.withValues(alpha: 0.85),
      );
      if (lit > 0.05) {
        canvas.drawRRect(
          rr.inflate(4),
          Paint()
            ..color = _gold.withValues(alpha: lit * 0.55)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }

    // המסילות עצמן.
    for (final side in const [-1.0, 1.0]) {
      final path = Path();
      const steps = 24;
      for (var i = 0; i <= steps; i++) {
        final p = rail(side, i / steps);
        i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path.shift(const Offset(2, 3)),
        Paint()
          ..color = _woodDark.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = _wood
          ..style = PaintingStyle.stroke
          ..strokeWidth = 12
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        path.shift(Offset(-side * 2.5, 0)),
        Paint()
          ..color = _woodLight
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round,
      );
      _paintVine(canvas, side, rail);
    }

    _paintRisingSparkles(canvas, rail);
    _paintClouds(canvas, Offset(cx, top + 6), w);
  }

  /// אי מרחף זוהר מאחורי העננים - רמז לעולם הבא.
  void _paintIsland(Canvas canvas, Offset c, double w) {
    final glow = Rect.fromCircle(center: c, radius: 120);
    canvas.drawCircle(
      c,
      120,
      Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFF3B0).withValues(alpha: 0.75),
            const Color(0xFFB39DFF).withValues(alpha: 0.25),
            const Color(0xFFB39DFF).withValues(alpha: 0),
          ],
          stops: const [0, 0.5, 1],
        ).createShader(glow),
    );
    final bob = math.sin(t * 0.9) * 3;
    final base = c.translate(0, bob - 6);
    // סלע האי.
    final rock = Path()
      ..moveTo(base.dx - 70, base.dy)
      ..quadraticBezierTo(base.dx - 40, base.dy + 46, base.dx, base.dy + 58)
      ..quadraticBezierTo(base.dx + 40, base.dy + 46, base.dx + 70, base.dy)
      ..close();
    canvas.drawPath(rock, Paint()..color = const Color(0xFF8D7BD8));
    canvas.drawPath(
      rock,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFB7A8FF), Color(0xFF5B4AB0)],
        ).createShader(Rect.fromLTWH(base.dx - 70, base.dy, 140, 58)),
    );
    // דשא וטירה קטנה על האי.
    canvas.drawOval(Rect.fromCenter(center: base, width: 146, height: 18), Paint()..color = const Color(0xFF7DE3A0));
    final castle = Paint()..color = const Color(0xFFF3EEFF);
    canvas.drawRect(Rect.fromLTWH(base.dx - 18, base.dy - 34, 36, 30), castle);
    for (final dx in const [-24.0, 18.0]) {
      canvas.drawRect(Rect.fromLTWH(base.dx + dx, base.dy - 46, 10, 42), castle);
      final roof = Path()
        ..moveTo(base.dx + dx - 3, base.dy - 46)
        ..lineTo(base.dx + dx + 5, base.dy - 60)
        ..lineTo(base.dx + dx + 13, base.dy - 46)
        ..close();
      canvas.drawPath(roof, Paint()..color = const Color(0xFFFF7AA8));
    }
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(base.dx - 6, base.dy - 18, 12, 14),
        topLeft: const Radius.circular(6),
        topRight: const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFFFFC93C),
    );
  }

  void _paintStars(Canvas canvas, Size size) {
    final rng = math.Random(11);
    for (var i = 0; i < 16; i++) {
      final p = Offset(rng.nextDouble() * size.width, rng.nextDouble() * 150);
      final tw = 0.5 + 0.5 * math.sin(t * 2.4 + i * 1.7);
      _star(canvas, p, 2.5 + tw * 3.5, Colors.white.withValues(alpha: 0.35 + tw * 0.65));
    }
  }

  void _star(Canvas canvas, Offset c, double r, Color color) {
    final path = Path();
    for (var i = 0; i < 8; i++) {
      final a = i * math.pi / 4;
      final rr = i.isEven ? r : r * 0.32;
      final p = c + Offset(math.cos(a) * rr, math.sin(a) * rr);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    path.close();
    canvas.drawPath(path, Paint()..color = color);
  }

  void _paintVine(Canvas canvas, double side, Offset Function(double side, double k) rail) {
    final stem = Paint()
      ..color = const Color(0xFF3FAE5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final path = Path();
    const steps = 40;
    for (var i = 0; i <= steps; i++) {
      final k = i / steps * 0.62;
      final p = rail(side, k) + Offset(math.sin(k * 26 + side) * 7, 0);
      i == 0 ? path.moveTo(p.dx, p.dy) : path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(path, stem);
    final leaf = Paint()..color = const Color(0xFF5BD36F);
    for (var i = 1; i < 9; i++) {
      final k = i / 9 * 0.6;
      final p = rail(side, k) + Offset(math.sin(k * 26 + side) * 7, 0);
      final sway = math.sin(t * 1.6 + i) * 0.2;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate((i.isEven ? 0.9 : -0.9) * side + sway);
      canvas.drawOval(Rect.fromLTWH(0, -3.5, 13, 7), leaf);
      canvas.restore();
      if (i % 3 == 0) {
        canvas.drawCircle(p + Offset(side * 6, -4), 3.2, Paint()..color = const Color(0xFFFF8FC0));
        canvas.drawCircle(p + Offset(side * 6, -4), 1.3, Paint()..color = const Color(0xFFFFF59D));
      }
    }
  }

  void _paintRisingSparkles(Canvas canvas, Offset Function(double side, double k) rail) {
    for (var i = 0; i < 12; i++) {
      final k = ((t * 0.12 + i / 12) % 1.0);
      final side = math.sin(i * 2.3);
      final p = rail(side, k) + Offset(math.sin(t * 2 + i) * 10, 0);
      final a = math.sin(k * math.pi);
      _star(canvas, p, 3 + 3 * a, _gold.withValues(alpha: a * 0.9));
    }
  }

  /// ענני שמיים שמסתירים את קצה הסולם, זזים לאט.
  void _paintClouds(Canvas canvas, Offset c, double w) {
    final drift = math.sin(t * 0.5) * 8;
    final shade = Paint()..color = const Color(0xFFD9DEFF);
    final white = Paint()..color = Colors.white;
    final puffs = <(double, double, double)>[
      (-78, 10, 30),
      (-44, -6, 38),
      (-6, -14, 44),
      (36, -4, 38),
      (74, 10, 30),
      (-30, 18, 32),
      (22, 20, 34),
    ];
    for (final puff in puffs) {
      canvas.drawCircle(c + Offset(puff.$1 + drift, puff.$2 + 7), puff.$3, shade);
    }
    for (final puff in puffs) {
      canvas.drawCircle(c + Offset(puff.$1 + drift, puff.$2), puff.$3, white);
    }
    // ענן קטן שני, נע בכיוון ההפוך.
    final c2 = c + Offset(-drift * 1.6 + 60, 70);
    for (final puff in const [(-18.0, 0.0, 16.0), (0.0, -6.0, 20.0), (20.0, 0.0, 15.0)]) {
      canvas.drawCircle(c2 + Offset(puff.$1, puff.$2 + 4), puff.$3, shade);
      canvas.drawCircle(c2 + Offset(puff.$1, puff.$2), puff.$3, white);
    }
  }

  @override
  bool shouldRepaint(_SkyLadderPainter old) => old.t != t;
}

/// שלט עץ ליד בסיס הסולם: "שלבים חדשים בדרך!".
class LadderSign extends StatelessWidget {
  static const double width = 190;
  static const double height = 132;

  final Animation<double> ambient;

  const LadderSign({super.key, required this.ambient});

  @override
  Widget build(BuildContext context) {
    const wood = Color(0xFFB9774A);
    const woodDark = Color(0xFF7A4B26);
    return AnimatedBuilder(
      animation: ambient,
      builder: (context, child) => Transform.rotate(
        angle: math.sin(ambient.value * 40 * 1.1) * 0.025,
        alignment: Alignment.bottomCenter,
        child: child,
      ),
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          alignment: Alignment.bottomCenter,
          children: [
            for (final dx in const [-48.0, 48.0])
              Positioned(
                bottom: 0,
                left: width / 2 + dx - 4,
                child: Container(
                  width: 8,
                  height: 60,
                  decoration: BoxDecoration(color: woodDark, borderRadius: BorderRadius.circular(3)),
                ),
              ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFD9955F), wood],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: woodDark, width: 2.5),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 5)),
                  ],
                ),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFE27A), size: 18),
                          SizedBox(width: 4),
                          Text(
                            'שלבים חדשים בדרך!',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 1.5), blurRadius: 2)],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 3),
                    Text(
                      'העולם הבא מחכה בשמיים -\nאחרי הטיפוס בסולם ☁️',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Color(0xFFFFF3E0),
                        fontSize: 12,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
