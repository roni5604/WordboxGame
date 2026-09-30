import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../game_engine/models/level_config.dart';

/// רצועת רקע של עולם אחד במפת הקמפיין - נצבעת בגרדיאנט הייחודי שלה
/// ומקשטת במוטיבים פשוטים (בקוד בלבד) כדי שבגלילה יהיה ברור שעברנו עולם.
class WorldSection {
  final WorldTier tier;
  final int worldIndex;
  final double startY;
  final double endY;

  const WorldSection({
    required this.tier,
    required this.worldIndex,
    required this.startY,
    required this.endY,
  });

  @override
  bool operator ==(Object other) {
    return other is WorldSection &&
        other.tier == tier &&
        other.worldIndex == worldIndex &&
        other.startY == startY &&
        other.endY == endY;
  }

  @override
  int get hashCode => Object.hash(tier, worldIndex, startY, endY);
}

/// מצייר רצועות רקע לכל עולם לאורך מפת השלבים, כולל מעבר רך בגבול
/// ביניהם ומוטיבים דקורטיביים שונים לכל עולם (עלה / טיפה / שמש / עץ).
class WorldBackdropPainter extends CustomPainter {
  final List<WorldSection> sections;

  const WorldBackdropPainter({required this.sections});

  @override
  void paint(Canvas canvas, Size size) {
    if (sections.isEmpty) return;

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];
      final rect = Rect.fromLTRB(0, section.startY, size.width, section.endY);
      if (rect.height <= 0) continue;

      final colors = AppColors.gradientForWorldIndex(section.worldIndex);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: colors,
          ).createShader(rect),
      );

      _paintMotifs(canvas, rect, section.worldIndex);

      if (i + 1 < sections.length) {
        _paintBlend(canvas, size.width, section.endY, section.worldIndex, sections[i + 1].worldIndex);
      }
    }
  }

  /// רצועת מעבר קצרה בין שני עולמות - כדי שהשינוי בצבע יורגש אבל לא
  /// "יקפוץ" בחדות ממש מתחת לבאנר.
  void _paintBlend(Canvas canvas, double width, double atY, int fromIndex, int toIndex) {
    const blend = 90.0;
    final rect = Rect.fromLTRB(0, atY - blend / 2, width, atY + blend / 2);
    final from = AppColors.gradientForWorldIndex(fromIndex).last;
    final to = AppColors.gradientForWorldIndex(toIndex).first;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [from.withValues(alpha: 0.0), from, to, to.withValues(alpha: 0.0)],
          stops: const [0.0, 0.35, 0.65, 1.0],
        ).createShader(rect),
    );
  }

  void _paintMotifs(Canvas canvas, Rect rect, int worldIndex) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.14)
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final random = math.Random(worldIndex * 92821 + 17);
    final count = math.max(8, (rect.height / 140).round());

    for (int i = 0; i < count; i++) {
      final x = 24 + random.nextDouble() * (rect.width - 48);
      final y = rect.top + 20 + random.nextDouble() * math.max(1, rect.height - 40);
      final scale = 0.7 + random.nextDouble() * 0.8;
      final origin = Offset(x, y);

      switch (worldIndex % 5) {
        case 0:
          _drawLeaf(canvas, origin, scale, paint);
          break;
        case 1:
          _drawDrop(canvas, origin, scale, paint);
          break;
        case 2:
          _drawSun(canvas, origin, scale, paint, stroke);
          break;
        case 3:
          _drawTree(canvas, origin, scale, paint);
          break;
        default:
          _drawPeak(canvas, origin, scale, paint);
      }
    }
  }

  void _drawLeaf(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx, origin.dy - 16 * scale)
      ..quadraticBezierTo(
        origin.dx + 14 * scale,
        origin.dy,
        origin.dx,
        origin.dy + 16 * scale,
      )
      ..quadraticBezierTo(
        origin.dx - 14 * scale,
        origin.dy,
        origin.dx,
        origin.dy - 16 * scale,
      );
    canvas.drawPath(path, paint);
  }

  void _drawDrop(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx, origin.dy - 16 * scale)
      ..quadraticBezierTo(
        origin.dx + 12 * scale,
        origin.dy + 4 * scale,
        origin.dx,
        origin.dy + 14 * scale,
      )
      ..quadraticBezierTo(
        origin.dx - 12 * scale,
        origin.dy + 4 * scale,
        origin.dx,
        origin.dy - 16 * scale,
      );
    canvas.drawPath(path, paint);
  }

  void _drawSun(Canvas canvas, Offset origin, double scale, Paint fill, Paint stroke) {
    canvas.drawCircle(origin, 8 * scale, fill);
    for (int i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      final inner = origin + Offset(math.cos(angle), math.sin(angle)) * 11 * scale;
      final outer = origin + Offset(math.cos(angle), math.sin(angle)) * 18 * scale;
      canvas.drawLine(inner, outer, stroke);
    }
  }

  void _drawTree(Canvas canvas, Offset origin, double scale, Paint paint) {
    final canopy = Path()
      ..moveTo(origin.dx, origin.dy - 18 * scale)
      ..lineTo(origin.dx + 14 * scale, origin.dy + 6 * scale)
      ..lineTo(origin.dx - 14 * scale, origin.dy + 6 * scale)
      ..close();
    canvas.drawPath(canopy, paint);
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(origin.dx, origin.dy + 12 * scale),
        width: 5 * scale,
        height: 10 * scale,
      ),
      paint,
    );
  }

  void _drawPeak(Canvas canvas, Offset origin, double scale, Paint paint) {
    final path = Path()
      ..moveTo(origin.dx, origin.dy - 16 * scale)
      ..lineTo(origin.dx + 16 * scale, origin.dy + 12 * scale)
      ..lineTo(origin.dx - 16 * scale, origin.dy + 12 * scale)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WorldBackdropPainter oldDelegate) {
    return !listEquals(oldDelegate.sections, sections);
  }
}
