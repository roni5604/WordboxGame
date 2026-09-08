import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

enum MascotMood { idle, happy, sad, excited }

/// קמעון המשחק - דמות פשוטה ומצוירת-קוד (ללא צורך בקבצי אנימציה חיצוניים
/// כמו Rive/Lottie), עם הבעות פנים שונות לפי מצב המשחק. אפשר להחליף בעתיד
/// באנימציית Rive מלאה מבלי לשנות את ממשק ה-Widget הזה.
class MascotWidget extends StatelessWidget {
  final MascotMood mood;
  final double size;

  const MascotWidget({super.key, this.mood = MascotMood.idle, this.size = 96});

  @override
  Widget build(BuildContext context) {
    Widget face = CustomPaint(
      size: Size(size, size),
      painter: _MascotPainter(mood: mood),
    );

    switch (mood) {
      case MascotMood.idle:
        return face
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .moveY(begin: 0, end: -6, duration: 1200.ms, curve: Curves.easeInOut);
      case MascotMood.happy:
      case MascotMood.excited:
        return face
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.12, duration: 350.ms, curve: Curves.easeOut)
            .then()
            .shake(hz: 2, curve: Curves.easeInOut);
      case MascotMood.sad:
        return face.animate().moveY(begin: -4, end: 4, duration: 500.ms);
    }
  }
}

class _MascotPainter extends CustomPainter {
  final MascotMood mood;

  _MascotPainter({required this.mood});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bodyColor = switch (mood) {
      MascotMood.sad => const Color(0xFFB8C4FF),
      MascotMood.happy || MascotMood.excited => const Color(0xFFFFD166),
      MascotMood.idle => const Color(0xFFFFE29A),
    };

    canvas.drawCircle(center, radius, Paint()..color = bodyColor);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final eyeOffsetX = radius * 0.32;
    final eyeOffsetY = radius * 0.05;
    final eyeRadius = radius * 0.11;
    final eyePaint = Paint()..color = const Color(0xFF2B2440);

    canvas.drawCircle(center.translate(-eyeOffsetX, -eyeOffsetY), eyeRadius, eyePaint);
    canvas.drawCircle(center.translate(eyeOffsetX, -eyeOffsetY), eyeRadius, eyePaint);

    final mouthPaint = Paint()
      ..color = const Color(0xFF2B2440)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;

    final mouthRect = Rect.fromCenter(
      center: center.translate(0, radius * 0.28),
      width: radius * 0.9,
      height: radius * 0.7,
    );

    switch (mood) {
      case MascotMood.happy:
      case MascotMood.excited:
        canvas.drawArc(mouthRect, 0.2, 2.7, false, mouthPaint);
        break;
      case MascotMood.sad:
        canvas.drawArc(mouthRect.translate(0, radius * 0.35), 3.4, 2.7, false, mouthPaint);
        break;
      case MascotMood.idle:
        canvas.drawLine(
          center.translate(-radius * 0.22, radius * 0.32),
          center.translate(radius * 0.22, radius * 0.32),
          mouthPaint,
        );
        break;
    }

    if (mood == MascotMood.excited) {
      final blushPaint = Paint()..color = Colors.pinkAccent.withValues(alpha: 0.4);
      canvas.drawCircle(center.translate(-radius * 0.62, radius * 0.12), radius * 0.14, blushPaint);
      canvas.drawCircle(center.translate(radius * 0.62, radius * 0.12), radius * 0.14, blushPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MascotPainter oldDelegate) => oldDelegate.mood != mood;
}
