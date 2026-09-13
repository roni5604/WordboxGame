import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../game_engine/models/level_config.dart';

/// פס רקע של עולם אחד במפת הקמפיין - כדי שבגלילה ייראה בבירור המעבר
/// בין עולמות (צבע + אייקונים דקורטיביים), ולא רק באנר קטן בגבול.
class WorldBand {
  final WorldTier tier;
  final int worldIndex;
  final double startY;
  final double endY;

  const WorldBand({
    required this.tier,
    required this.worldIndex,
    required this.startY,
    required this.endY,
  });
}

/// מצייר לכל עולם פס גרדיאנט מלא-רוחב + אייקונים שקופים ייחודיים לעולם.
/// כך כשגוללים למטה הרקע עצמו מחליף זהות, בלי נכסי אמנות חדשים.
class WorldMapBackdrop extends CustomPainter {
  final List<WorldBand> bands;
  final double width;

  WorldMapBackdrop({required this.bands, required this.width});

  @override
  void paint(Canvas canvas, Size size) {
    for (final band in bands) {
      final top = band.startY.clamp(0.0, size.height);
      final bottom = band.endY.clamp(0.0, size.height);
      if (bottom <= top) continue;

      final rect = Rect.fromLTRB(0, top, size.width, bottom);
      final colors = AppColors.gradientForWorldIndex(band.worldIndex);
      final paint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(colors.first, Colors.black, 0.08)!,
            colors.last,
            Color.lerp(colors.first, colors.last, 0.55)!,
          ],
        ).createShader(rect);
      canvas.drawRect(rect, paint);

      _paintDecorations(canvas, rect, band);
    }
  }

  void _paintDecorations(Canvas canvas, Rect rect, WorldBand band) {
    final icon = AppColors.iconForWorldIndex(band.worldIndex);
    final painter = TextPainter(textDirection: TextDirection.ltr);
    final rng = math.Random(band.worldIndex * 9176 + 13);
    final count = 10;

    for (int i = 0; i < count; i++) {
      final x = 18 + rng.nextDouble() * math.max(1, rect.width - 36);
      final y = rect.top + 20 + rng.nextDouble() * math.max(1, rect.height - 40);
      final size = 22.0 + rng.nextDouble() * 26;
      painter.text = TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: size,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          color: Colors.white.withValues(alpha: 0.10 + rng.nextDouble() * 0.08),
        ),
      );
      painter.layout();
      painter.paint(canvas, Offset(x, y));
    }
  }

  @override
  bool shouldRepaint(covariant WorldMapBackdrop oldDelegate) {
    return oldDelegate.bands != bands || oldDelegate.width != width;
  }
}
