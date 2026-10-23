import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/ui/pressable.dart';
import 'world_theme.dart';

/// "החיות החוקרות" - חברות של זואי הבלשית, אחת לכל עולם. מצוירות בקוד
/// (בלי נכסי אמנות), עם תנועת סרק חיה (מצמוץ, נשימה, תנועת אוזניים/כנפיים)
/// וקפיצה קטנה כשנוגעים בהן.
class ExplorerCritter extends StatefulWidget {
  final ExplorerKind kind;
  final Animation<double> ambient;
  final double size;

  /// היסט פאזה, כדי ששתי חיות באותו עולם לא ינועו בדיוק יחד.
  final double phase;
  final bool interactive;

  const ExplorerCritter({
    super.key,
    required this.kind,
    required this.ambient,
    this.size = 64,
    this.phase = 0,
    this.interactive = true,
  });

  @override
  State<ExplorerCritter> createState() => _ExplorerCritterState();
}

class _ExplorerCritterState extends State<ExplorerCritter> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 620));

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final art = AnimatedBuilder(
      animation: Listenable.merge([widget.ambient, _hop]),
      builder: (context, _) => CustomPaint(
        size: Size(widget.size, widget.size * 1.15),
        painter: CritterPainter(
          kind: widget.kind,
          time: widget.ambient.value * 40 + widget.phase,
          hop: _hop.value,
        ),
      ),
    );
    if (!widget.interactive) return art;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        Haptics.selection();
        PressFeedback.trigger(haptic: false);
        _hop.forward(from: 0);
      },
      child: art,
    );
  }
}

class CritterPainter extends CustomPainter {
  final ExplorerKind kind;
  final double time;
  final double hop;

  CritterPainter({required this.kind, required this.time, this.hop = 0});

  static const _tan = Color(0xFFC8A06A);
  static const _tanDark = Color(0xFF9C7440);
  static const _ink = Color(0xFF2B2440);

  double get _blink {
    final cycle = (time + kind.index * 0.9) % 3.6;
    return cycle < 0.14 ? 1 - (cycle - 0.07).abs() / 0.07 : 0;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 100;
    canvas.translate(size.width / 2, size.height);
    canvas.scale(unit);

    final jump = math.sin(hop * math.pi);
    // צל על הקרקע (מתכווץ כשהחיה באוויר).
    final airborne = kind == ExplorerKind.bee ? 0.6 : jump;
    canvas.drawOval(
      Rect.fromCenter(center: const Offset(0, -3), width: 52 - airborne * 16, height: 10 - airborne * 3),
      Paint()..color = Colors.black.withValues(alpha: 0.18),
    );

    final breathe = math.sin(time * 2.4) * 0.025;
    canvas.translate(0, -jump * 26);
    // מעיכה קלה ברגע הנחיתה - תחושת "קפיציות" של משחקים.
    final squash = hop > 0.85 ? math.sin((hop - 0.85) / 0.15 * math.pi) * 0.12 : 0.0;
    canvas.scale(1 + squash + breathe * 0.5, 1 - squash + breathe);

    switch (kind) {
      case ExplorerKind.bunny:
        _bunny(canvas);
      case ExplorerKind.frog:
        _frog(canvas);
      case ExplorerKind.bee:
        _bee(canvas);
      case ExplorerKind.owl:
        _owl(canvas);
      case ExplorerKind.penguin:
        _penguin(canvas);
    }
  }

  // ------------------------------------------------------------ עזרים

  void _oval(Canvas canvas, Offset c, double w, double h, Color color, {double angle = 0}) {
    if (angle == 0) {
      canvas.drawOval(Rect.fromCenter(center: c, width: w, height: h), Paint()..color = color);
      return;
    }
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w, height: h), Paint()..color = color);
    canvas.restore();
  }

  void _eye(Canvas canvas, Offset c, double r) {
    final open = 1 - _blink;
    if (open < 0.15) {
      canvas.drawLine(
        c - Offset(r, 0),
        c + Offset(r, 0),
        Paint()
          ..color = _ink
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round,
      );
      return;
    }
    _oval(canvas, c, r * 2, r * 2 * open, _ink);
    canvas.drawCircle(c + Offset(-r * 0.35, -r * 0.4 * open), r * 0.38, Paint()..color = Colors.white);
  }

  void _cheeks(Canvas canvas, Offset left, Offset right, double r) {
    final blush = Paint()..color = const Color(0xFFFF8FA3).withValues(alpha: 0.55);
    canvas.drawCircle(left, r, blush);
    canvas.drawCircle(right, r, blush);
  }

  /// כובע בלשים (deerstalker) - החתימה המשותפת לזואי ולכל החוקרים.
  void _deerstalker(Canvas canvas, Offset base, double w, {double tilt = 0}) {
    canvas.save();
    canvas.translate(base.dx, base.dy);
    canvas.rotate(tilt);
    _oval(canvas, Offset(-w * 0.42, 0), w * 0.42, w * 0.14, _tanDark, angle: 0.2);
    _oval(canvas, Offset(w * 0.42, 0), w * 0.42, w * 0.14, _tanDark, angle: -0.2);
    final dome = Path()
      ..moveTo(-w / 2, 0)
      ..cubicTo(-w / 2, -w * 0.62, w / 2, -w * 0.62, w / 2, 0)
      ..close();
    canvas.drawPath(dome, Paint()..color = _tan);
    canvas.save();
    canvas.clipPath(dome);
    final check = Paint()
      ..color = _tanDark.withValues(alpha: 0.55)
      ..strokeWidth = 1.4;
    for (double x = -w; x <= w; x += w / 5) {
      canvas.drawLine(Offset(x, 0), Offset(x + w * 0.4, -w), check);
      canvas.drawLine(Offset(x, -w), Offset(x + w * 0.4, 0), check);
    }
    canvas.restore();
    canvas.drawCircle(Offset(0, -w * 0.47), w * 0.07, Paint()..color = _tanDark);
    canvas.restore();
  }

  void _magnifier(Canvas canvas, Offset lens, double r, {double angle = 0.7}) {
    final handleEnd = lens + Offset(-math.cos(angle) * r * 2.1, math.sin(angle) * r * 2.1);
    final handleStart = lens + Offset(-math.cos(angle) * r, math.sin(angle) * r);
    canvas.drawLine(
      handleStart,
      handleEnd,
      Paint()
        ..color = const Color(0xFF6D4C2F)
        ..strokeWidth = r * 0.5
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(lens, r, Paint()..color = const Color(0xFFBDE9FF).withValues(alpha: 0.75));
    canvas.drawCircle(
      lens,
      r,
      Paint()
        ..color = const Color(0xFFE0B04A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.3,
    );
    // ניצוץ זכוכית שזז לאט.
    final glint = math.sin(time * 1.6) * 0.3;
    canvas.drawCircle(lens + Offset(-r * (0.3 + glint * 0.2), -r * 0.35), r * 0.22, Paint()..color = Colors.white.withValues(alpha: 0.85));
  }

  // ------------------------------------------------------------ החיות

  void _bunny(Canvas canvas) {
    const fur = Color(0xFFF6EBDD);
    const furShade = Color(0xFFE2CDB5);
    final ear = math.sin(time * 2.8) * 0.08;
    _oval(canvas, const Offset(-12, -5), 20, 10, furShade);
    _oval(canvas, const Offset(12, -5), 20, 10, furShade);
    _oval(canvas, const Offset(0, -27), 46, 44, fur);
    _oval(canvas, const Offset(0, -22), 26, 28, Colors.white);
    // אוזניים.
    _oval(canvas, const Offset(-10, -86), 13, 38, fur, angle: -0.22 + ear);
    _oval(canvas, const Offset(-10, -86), 6, 27, const Color(0xFFFFB3C1), angle: -0.22 + ear);
    _oval(canvas, const Offset(10, -86), 13, 38, fur, angle: 0.24 - ear);
    _oval(canvas, const Offset(10, -86), 6, 27, const Color(0xFFFFB3C1), angle: 0.24 - ear);
    canvas.drawCircle(const Offset(0, -58), 22, Paint()..color = fur);
    _eye(canvas, const Offset(-8, -61), 3.6);
    _eye(canvas, const Offset(8, -61), 3.6);
    _cheeks(canvas, const Offset(-13, -53), const Offset(13, -53), 4.5);
    _oval(canvas, const Offset(0, -54), 6, 4, const Color(0xFFFF7B93));
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, -51), width: 8, height: 5),
      0.2,
      math.pi - 0.4,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    _magnifier(canvas, Offset(26, -46 + math.sin(time * 1.3) * 2), 10);
    _oval(canvas, const Offset(17, -33), 10, 12, fur);
  }

  void _frog(Canvas canvas) {
    const skin = Color(0xFF6CD36A);
    const skinShade = Color(0xFF47B04A);
    _oval(canvas, const Offset(0, -4), 76, 18, const Color(0xFF2E9A55));
    canvas.drawPath(
      Path()
        ..moveTo(0, -4)
        ..lineTo(30, -12)
        ..lineTo(34, -6)
        ..close(),
      Paint()..color = const Color(0xFF4FC3E8),
    );
    _oval(canvas, const Offset(-20, -10), 18, 10, skinShade);
    _oval(canvas, const Offset(20, -10), 18, 10, skinShade);
    _oval(canvas, const Offset(0, -26), 58, 40, skin);
    final puff = 1 + math.max(0, math.sin(time * 3.1)) * 0.12;
    _oval(canvas, const Offset(0, -20), 36 * puff, 22 * puff, const Color(0xFFCDF3A9));
    for (final x in const [-14.0, 14.0]) {
      canvas.drawCircle(Offset(x, -44), 11, Paint()..color = skin);
      canvas.drawCircle(Offset(x, -45), 8, Paint()..color = Colors.white);
      _eye(canvas, Offset(x + 1, -45), 3.8);
    }
    canvas.drawArc(
      Rect.fromCenter(center: const Offset(0, -31), width: 28, height: 12),
      0.15,
      math.pi - 0.3,
      false,
      Paint()
        ..color = _ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    _cheeks(canvas, const Offset(-20, -30), const Offset(20, -30), 4);
    _deerstalker(canvas, const Offset(0, -52), 26, tilt: -0.12);
  }

  void _bee(Canvas canvas) {
    final hover = math.sin(time * 2.2) * 5;
    canvas.translate(0, -58 + hover);
    final flap = 0.45 + 0.55 * (math.sin(time * 38).abs());
    for (final side in const [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(side * 13, -26);
      canvas.rotate(side * 0.5);
      canvas.scale(1, flap);
      _oval(canvas, const Offset(0, -12), 20, 28, Colors.white.withValues(alpha: 0.78));
      canvas.restore();
    }
    final body = Rect.fromCenter(center: const Offset(0, 0), width: 40, height: 46);
    canvas.drawOval(body, Paint()..color = const Color(0xFFFFD54F));
    canvas.save();
    canvas.clipPath(Path()..addOval(body));
    final stripe = Paint()..color = const Color(0xFF3A2E2A);
    canvas.drawRect(const Rect.fromLTWH(-30, 2, 60, 7), stripe);
    canvas.drawRect(const Rect.fromLTWH(-30, 15, 60, 7), stripe);
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(-4, 22)
        ..lineTo(0, 30)
        ..lineTo(4, 22)
        ..close(),
      Paint()..color = const Color(0xFF3A2E2A),
    );
    canvas.drawCircle(const Offset(0, -24), 15, Paint()..color = const Color(0xFFFFE082));
    final antenna = Paint()
      ..color = const Color(0xFF3A2E2A)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(side * 5, -37)
          ..quadraticBezierTo(side * 8, -48, side * 14, -48),
        antenna,
      );
      canvas.drawCircle(Offset(side * 14, -48), 2.8, Paint()..color = const Color(0xFF3A2E2A));
    }
    _eye(canvas, const Offset(-6, -25), 3.2);
    _eye(canvas, const Offset(6, -25), 3.2);
    _cheeks(canvas, const Offset(-10, -18), const Offset(10, -18), 3.2);
    _magnifier(canvas, const Offset(-26, 0), 8, angle: -0.8);
  }

  void _owl(Canvas canvas) {
    _oval(canvas, const Offset(0, -8), 56, 16, const Color(0xFF8A5A33));
    canvas.drawRect(const Rect.fromLTWH(-28, -8, 56, 8), Paint()..color = const Color(0xFF8A5A33));
    _oval(canvas, const Offset(0, -9), 50, 12, const Color(0xFFC9925E));
    _oval(canvas, const Offset(0, -9), 30, 6, const Color(0xFFA9744A));

    canvas.save();
    canvas.translate(0, -40);
    canvas.rotate(math.sin(time * 0.9) * 0.09);
    const feather = Color(0xFF8D6E63);
    const featherDark = Color(0xFF6D4C41);
    _oval(canvas, const Offset(-22, -2), 16, 34, featherDark, angle: 0.2);
    _oval(canvas, const Offset(22, -2), 16, 34, featherDark, angle: -0.2);
    _oval(canvas, const Offset(0, -6), 50, 60, feather);
    _oval(canvas, const Offset(0, 2), 30, 36, const Color(0xFFE6D5C3));
    final mark = Paint()
      ..color = featherDark.withValues(alpha: 0.6)
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke;
    for (final p in const [Offset(-6, -2), Offset(6, -2), Offset(0, 7), Offset(-7, 13), Offset(7, 13)]) {
      canvas.drawPath(
        Path()
          ..moveTo(p.dx - 3, p.dy)
          ..lineTo(p.dx, p.dy + 3)
          ..lineTo(p.dx + 3, p.dy),
        mark,
      );
    }
    for (final side in const [-1.0, 1.0]) {
      canvas.drawPath(
        Path()
          ..moveTo(side * 22, -24)
          ..lineTo(side * 18, -40)
          ..lineTo(side * 10, -28)
          ..close(),
        Paint()..color = feather,
      );
      canvas.drawCircle(Offset(side * 11, -18), 11, Paint()..color = const Color(0xFFFFF3E0));
      canvas.drawCircle(Offset(side * 11, -18), 7, Paint()..color = const Color(0xFFFFB300));
      _eye(canvas, Offset(side * 11, -18), 3.6);
    }
    canvas.drawPath(
      Path()
        ..moveTo(-4, -10)
        ..lineTo(4, -10)
        ..lineTo(0, -3)
        ..close(),
      Paint()..color = const Color(0xFFFF9800),
    );
    _deerstalker(canvas, const Offset(0, -33), 38, tilt: 0.08);
    canvas.restore();
  }

  void _penguin(Canvas canvas) {
    const body = Color(0xFF2E3A59);
    _oval(canvas, const Offset(-10, -4), 16, 8, const Color(0xFFFF9800));
    _oval(canvas, const Offset(10, -4), 16, 8, const Color(0xFFFF9800));
    final wave = math.sin(time * 4) * 0.35;
    _oval(canvas, const Offset(-24, -34), 12, 30, body, angle: 0.35);
    _oval(canvas, const Offset(24, -36), 12, 30, body, angle: -0.6 - wave);
    _oval(canvas, const Offset(0, -36), 48, 66, body);
    _oval(canvas, const Offset(0, -30), 34, 50, Colors.white);
    _eye(canvas, const Offset(-8, -54), 3.4);
    _eye(canvas, const Offset(8, -54), 3.4);
    canvas.drawPath(
      Path()
        ..moveTo(-5, -47)
        ..lineTo(5, -47)
        ..lineTo(0, -41)
        ..close(),
      Paint()..color = const Color(0xFFFF9800),
    );
    _cheeks(canvas, const Offset(-13, -46), const Offset(13, -46), 3.5);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: const Offset(0, -38), width: 40, height: 7), const Radius.circular(3)),
      Paint()..color = const Color(0xFFE53935),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(8, -38, 8, 18), const Radius.circular(3)),
      Paint()..color = const Color(0xFFC62828),
    );
    _deerstalker(canvas, const Offset(0, -66), 30);
  }

  @override
  bool shouldRepaint(covariant CritterPainter old) => old.time != time || old.hop != hop || old.kind != kind;
}
