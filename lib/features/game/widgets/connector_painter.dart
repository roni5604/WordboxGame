import 'dart:math';

import 'package:flutter/material.dart';

import '../../../core/cosmetics/cosmetic_catalog.dart';
import '../../../core/theme/app_colors.dart';

/// מצייר את הסימון שמחבר בין מרכזי התאים שנבחרו (ועד מיקום האצבע
/// הנוכחי). הסגנון מגיע מסקין הסימון המצויד.
class ConnectorPainter extends CustomPainter {
  final List<Offset> points;
  final bool isError;
  final MarkerStyle style;
  final Color markerColor;

  ConnectorPainter({
    required this.points,
    this.isError = false,
    this.style = MarkerStyle.classic,
    this.markerColor = AppColors.tileSelected,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    final color = isError ? AppColors.error : markerColor;
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final p in points.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }

    switch (style) {
      case MarkerStyle.classic:
        _drawStroke(canvas, path, color, 22, glow: true);
        _drawStroke(canvas, path, color, 10);
      case MarkerStyle.dashed:
        _drawDashed(canvas, path, color);
      case MarkerStyle.pearls:
        _drawPearls(canvas, path, color);
      case MarkerStyle.doubleLine:
        _drawStroke(canvas, path, color, 18);
        _drawStroke(canvas, path, Colors.white, 6);
      case MarkerStyle.stars:
        _drawStroke(canvas, path, color.withValues(alpha: 0.85), 8);
        _drawStars(canvas, path, color);
    }

    if (style != MarkerStyle.pearls && style != MarkerStyle.stars) {
      for (final p in points) {
        canvas.drawCircle(p, 6, Paint()..color = Colors.white.withValues(alpha: 0.9));
      }
    }
  }

  void _drawStroke(Canvas canvas, Path path, Color color, double width, {bool glow = false}) {
    final paint = Paint()
      ..color = glow ? color.withValues(alpha: 0.35) : color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    if (glow) {
      paint.maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    }
    canvas.drawPath(path, paint);
  }

  void _drawDashed(Canvas canvas, Path path, Color color) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = min(distance + 14, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 22;
      }
    }
  }

  void _drawPearls(Canvas canvas, Path path, Color color) {
    final paint = Paint()..color = color;
    final core = Paint()..color = Colors.white.withValues(alpha: 0.9);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance <= metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawCircle(tangent.position, 7, paint);
          canvas.drawCircle(tangent.position, 3, core);
        }
        distance += 16;
      }
    }
  }

  void _drawStars(Canvas canvas, Path path, Color color) {
    final paint = Paint()..color = color;
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance <= metric.length) {
        final tangent = metric.getTangentForOffset(distance);
        if (tangent != null) {
          canvas.drawPath(_star(tangent.position, 8), paint);
        }
        distance += 22;
      }
    }
  }

  Path _star(Offset center, double radius) {
    final path = Path();
    for (int i = 0; i < 10; i++) {
      final r = i.isEven ? radius : radius * 0.45;
      final angle = -pi / 2 + i * pi / 5;
      final point = Offset(center.dx + cos(angle) * r, center.dy + sin(angle) * r);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant ConnectorPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.isError != isError ||
        oldDelegate.style != style ||
        oldDelegate.markerColor != markerColor;
  }
}
