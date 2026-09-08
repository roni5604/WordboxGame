import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// מצייר את הקו הזוהר שמחבר בין מרכזי התאים שנבחרו (ועד מיקום האצבע
/// הנוכחי), בהשראת המשוב החזותי במשחקי Boggle/Wordbox.
class ConnectorPainter extends CustomPainter {
  final List<Offset> points;
  final bool isError;

  ConnectorPainter({required this.points, this.isError = false});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final color = isError ? AppColors.error : AppColors.tileSelected;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);

    for (final p in points) {
      canvas.drawCircle(p, 6, Paint()..color = Colors.white.withValues(alpha: 0.9));
    }
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.isError != isError;
  }
}
