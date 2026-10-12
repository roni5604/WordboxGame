import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../../core/ui/rarity_style.dart';

/// קופסת מתנה תלת-ממדית מצוירת: גוף + מכסה + סרט + פפיון, עם הצללה
/// בצבעי הדרגה, ברק עליון ונצנוצים. [lid] 0..1 = כמה המכסה כבר "עף".
class GiftBoxPainter extends CustomPainter {
  final RarityStyle style;
  final double lid;
  final double shimmer;
  final double crack;

  GiftBoxPainter({required this.style, this.lid = 0, this.shimmer = 0, this.crack = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final isGold = style.base.toARGB32() == const Color(0xFFFFB800).toARGB32();
    final ribbon = isGold ? const Color(0xFFFF4FA3) : const Color(0xFFFFE066);
    final ribbonDark = isGold ? const Color(0xFFC21D6E) : const Color(0xFFE0A100);

    // צל על הרצפה
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w / 2, h * 0.95), width: w * 0.74, height: h * 0.08),
      Paint()..color = const Color(0x55000000),
    );

    // גוף
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.14, h * 0.42, w * 0.72, h * 0.5), Radius.circular(w * 0.07));
    canvas.drawRRect(
      body,
      Paint()..shader = ui.Gradient.linear(body.outerRect.topCenter, body.outerRect.bottomCenter, [style.base, style.dark]),
    );
    // צד ימני כהה יותר - תחושת עומק
    canvas.save();
    canvas.clipRRect(body);
    canvas.drawRect(
      Rect.fromLTWH(w * 0.62, h * 0.42, w * 0.24, h * 0.5),
      Paint()..color = const Color(0x22000000),
    );
    // סרט אנכי
    canvas.drawRect(
      Rect.fromCenter(center: Offset(w / 2, h * 0.67), width: w * 0.16, height: h * 0.5),
      Paint()..shader = ui.Gradient.linear(Offset(w * 0.42, 0), Offset(w * 0.58, 0), [ribbon, ribbonDark]),
    );
    // "סדקים" של אור שבוקע מבפנים (ככל שלוחצים יותר)
    if (crack > 0) {
      final glow = Paint()
        ..color = style.light.withValues(alpha: 0.9 * crack)
        ..strokeWidth = 2.5 + 2 * crack
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + 3 * crack);
      final path = Path()
        ..moveTo(w * 0.25, h * 0.48)
        ..lineTo(w * 0.31, h * 0.6)
        ..lineTo(w * 0.27, h * 0.7)
        ..moveTo(w * 0.72, h * 0.5)
        ..lineTo(w * 0.66, h * 0.62)
        ..lineTo(w * 0.71, h * 0.76)
        ..lineTo(w * 0.66, h * 0.86);
      canvas.drawPath(path, glow);
    }
    canvas.restore();
    // ברק על הגוף
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.19, h * 0.46, w * 0.08, h * 0.38), Radius.circular(w * 0.04)),
      Paint()..color = const Color(0x40FFFFFF),
    );

    // אור שבוקע מתוך הקופסה כשהמכסה עף
    if (lid > 0) {
      final open = Offset(w / 2, h * 0.42);
      canvas.drawCircle(
        open,
        w * (0.3 + 0.5 * lid),
        Paint()..shader = ui.Gradient.radial(open, w * (0.3 + 0.5 * lid), [style.light.withValues(alpha: lid), style.light.withValues(alpha: 0)]),
      );
    }

    // מכסה + פפיון (עף למעלה ומסתובב כשנפתח)
    canvas.save();
    canvas.translate(w / 2, h * 0.36 - lid * h * 0.55);
    canvas.rotate(-0.5 * lid);
    final lidRect = RRect.fromRectAndRadius(Rect.fromCenter(center: Offset.zero, width: w * 0.84, height: h * 0.17), Radius.circular(w * 0.06));
    canvas.drawRRect(
      lidRect,
      Paint()..shader = ui.Gradient.linear(lidRect.outerRect.topCenter, lidRect.outerRect.bottomCenter, [style.light, style.base]),
    );
    canvas.drawRect(
      Rect.fromCenter(center: Offset.zero, width: w * 0.17, height: h * 0.17),
      Paint()..shader = ui.Gradient.linear(Offset(-w * 0.09, 0), Offset(w * 0.09, 0), [ribbon, ribbonDark]),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(-w * 0.38, -h * 0.07, w * 0.5, h * 0.035), Radius.circular(h * 0.02)),
      Paint()..color = const Color(0x55FFFFFF),
    );
    // פפיון: שתי לולאות + קשר
    final bow = Paint()..shader = ui.Gradient.linear(Offset(0, -h * 0.2), Offset(0, -h * 0.05), [ribbon, ribbonDark]);
    for (final dir in [-1.0, 1.0]) {
      canvas.save();
      canvas.translate(dir * w * 0.1, -h * 0.13);
      canvas.rotate(dir * 0.5);
      canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: w * 0.22, height: h * 0.11), bow);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(0, -h * 0.01), width: w * 0.1, height: h * 0.04),
        Paint()..color = const Color(0x33000000),
      );
      canvas.restore();
    }
    canvas.drawCircle(Offset(0, -h * 0.1), w * 0.055, Paint()..color = ribbon);
    canvas.restore();

    _glints(canvas, size, shimmer, style);
  }

  @override
  bool shouldRepaint(covariant GiftBoxPainter old) =>
      old.style != style || old.lid != lid || old.shimmer != shimmer || old.crack != crack;
}

/// "כוכב מזל" - כוכב בצורת כרית עם שיפוע פנימי וברק (בהשראת ה-Starr Drop).
class StarDropPainter extends CustomPainter {
  final RarityStyle style;
  final double shimmer;
  final double crack;

  StarDropPainter({required this.style, this.shimmer = 0, this.crack = 0});

  Path _star(Offset c, double outer, double inner) {
    final path = Path();
    const points = 5;
    for (var i = 0; i < points * 2; i++) {
      final r = i.isEven ? outer : inner;
      final a = -math.pi / 2 + i * math.pi / points;
      final p = Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    return path..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = size.width * 0.46;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx, size.height * 0.96), width: size.width * 0.6, height: size.height * 0.07),
      Paint()..color = const Color(0x55000000),
    );
    final outer = _star(c, r, r * 0.5);
    // קו מתאר עבה ומעוגל = כוכב "כרית"
    canvas.drawPath(
      outer,
      Paint()
        ..color = style.dark
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.16
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), [style.light, style.base, style.dark], [0, 0.45, 1])
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      outer,
      Paint()
        ..shader = ui.Gradient.linear(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), [style.light, style.base])
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.12
        ..strokeJoin = StrokeJoin.round,
    );
    final inner = _star(Offset(c.dx, c.dy + r * 0.04), r * 0.55, r * 0.28);
    canvas.drawPath(inner, Paint()..color = style.light.withValues(alpha: 0.45));
    if (crack > 0) {
      canvas.drawPath(
        inner,
        Paint()
          ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.7 * crack)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 + 6 * crack),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(c.dx - r * 0.18, c.dy - r * 0.32), width: r * 0.34, height: r * 0.16),
      Paint()..color = const Color(0x66FFFFFF),
    );
    _glints(canvas, size, shimmer, style);
  }

  @override
  bool shouldRepaint(covariant StarDropPainter old) => old.style != style || old.shimmer != shimmer || old.crack != crack;
}

/// נצנוצים קטנים בצורת כוכב בעל 4 קרניים שמופיעים ונעלמים סביב הפרס.
void _glints(Canvas canvas, Size size, double t, RarityStyle style) {
  const spots = [Offset(0.18, 0.22), Offset(0.84, 0.3), Offset(0.78, 0.86), Offset(0.12, 0.74), Offset(0.5, 0.08)];
  for (var i = 0; i < spots.length; i++) {
    final phase = (t * 1.3 + i * 0.27) % 1.0;
    final a = math.sin(phase * math.pi);
    if (a < 0.05) continue;
    final c = Offset(spots[i].dx * size.width, spots[i].dy * size.height);
    final r = size.width * 0.05 * a * (0.6 + style.intensity * 0.6);
    final p = Paint()..color = const Color(0xFFFFFFFF).withValues(alpha: a);
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r);
    canvas.drawPath(path, p);
  }
}

/// קרני אור מסתובבות מאחורי הפרס (God rays) - חזקות יותר ככל שהדרגה גבוהה.
class RaysPainter extends CustomPainter {
  final Color color;
  final double rotation;
  final double strength;
  final int count;

  RaysPainter({required this.color, required this.rotation, required this.strength, this.count = 14});

  @override
  void paint(Canvas canvas, Size size) {
    if (strength <= 0.01) return;
    final c = size.center(Offset.zero);
    final radius = size.shortestSide * 0.5;
    final paint = Paint()
      ..shader = ui.Gradient.radial(c, radius, [
        color.withValues(alpha: 0.55 * strength),
        color.withValues(alpha: 0.18 * strength),
        color.withValues(alpha: 0),
      ], [0, 0.45, 1]);
    final path = Path();
    final sweep = math.pi / count;
    for (var i = 0; i < count; i++) {
      final a = rotation + i * 2 * sweep;
      path
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + radius * math.cos(a - sweep * 0.35), c.dy + radius * math.sin(a - sweep * 0.35))
        ..lineTo(c.dx + radius * math.cos(a + sweep * 0.35), c.dy + radius * math.sin(a + sweep * 0.35))
        ..close();
    }
    canvas.drawPath(path, paint);
    // זוהר מרכזי רך
    canvas.drawCircle(
      c,
      radius * 0.55,
      Paint()
        ..shader = ui.Gradient.radial(c, radius * 0.55, [
          color.withValues(alpha: 0.7 * strength),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant RaysPainter old) =>
      old.color != color || old.rotation != rotation || old.strength != strength;
}
