import 'package:flutter/material.dart';

/// מצייר קו מקווקו מעוגל שמחבר בין נקודות השלבים במפת הקמפיין, וכך יוצר
/// תחושה של "מסלול" הרפתקאות מתמשך (בהשראת מפות שלבים במשחקי מובייל).
class PathPainter extends CustomPainter {
  final List<Offset> points;
  final Color color;

  PathPainter({required this.points, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.55)
      ..strokeWidth = 6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      final prev = points[i - 1];
      final curr = points[i];
      final mid = Offset((prev.dx + curr.dx) / 2, (prev.dy + curr.dy) / 2);
      path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      path.quadraticBezierTo(mid.dx, mid.dy, curr.dx, curr.dy);
    }

    final dashed = _dashPath(path, dashLength: 14, gapLength: 10);
    canvas.drawPath(dashed, paint);
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
    return oldDelegate.points != points || oldDelegate.color != color;
  }
}
