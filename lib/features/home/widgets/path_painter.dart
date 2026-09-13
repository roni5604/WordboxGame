import 'package:flutter/material.dart';

/// מצייר קו מקווקו מעוגל שמחבר בין נקודות השלבים במפת הקמפיין, וכך יוצר
/// תחושה של "מסלול" הרפתקאות מתמשך (בהשראת מפות שלבים במשחקי מובייל).
///
/// כל מקטע יכול לקבל צבע משלו - במפה משתמשים בזה כדי לצבוע את המסלול
/// לפי העולם של השלב הבא, כך שבגלילה גם הקו עצמו מחליף זהות.
class PathPainter extends CustomPainter {
  final List<Offset> points;
  final List<Color> segmentColors;
  final Color color;

  PathPainter({
    required this.points,
    this.segmentColors = const [],
    this.color = Colors.white,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      final segment = Path()
        ..moveTo(prev.dx, prev.dy)
        ..quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy)
        ..quadraticBezierTo(mid.dx, mid.dy, curr.dx, curr.dy);

      final segmentColor = i - 1 < segmentColors.length ? segmentColors[i - 1] : color;
      final paint = Paint()
        ..color = segmentColor.withValues(alpha: 0.78)
        ..strokeWidth = 7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      canvas.drawPath(_dashPath(segment, dashLength: 14, gapLength: 10), paint);
    }
  }

  Path _dashPath(Path source, {required double dashLength, required double gapLength}) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      bool draw = true;
      while (distance < metric.length) {
        final length = draw ? dashLength : gapLength;
        final next = (distance + length).clamp(0, metric.length);
        if (draw) {
          dest.addPath(metric.extractPath(distance, next.toDouble()), Offset.zero);
        }
        distance = next.toDouble();
        draw = !draw;
      }
    }
    return dest;
  }

  @override
  bool shouldRepaint(covariant PathPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.color != color ||
        oldDelegate.segmentColors != segmentColors;
  }
}
