import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/level_progress.dart';
import '../../../game_engine/models/level_config.dart';
import '../../../game_engine/rewards/reward_tables.dart';

enum _NodeLook { normal, lucky, master, finale }

/// נקודת שלב בודדת על מפת הקמפיין - מעגל עם מספר השלב, כוכבים שהושגו,
/// ומצב חזותי (נעול / פתוח לשחק / הושלם).
///
/// שלבי מאסטר, פינאלה ותיבת-מזל מקבלים צורה, זוהר ותווית משלהם, כדי
/// שבגלילה במפה יהיה ברור מיד שזה שלב מיוחד - גם כשהוא עדיין נעול.
class LevelNode extends StatelessWidget {
  final LevelConfig config;
  final LevelProgress progress;
  final bool isUnlocked;
  final bool isNextToPlay;
  final VoidCallback? onTap;

  const LevelNode({
    super.key,
    required this.config,
    required this.progress,
    required this.isUnlocked,
    required this.isNextToPlay,
    this.onTap,
  });

  static _NodeLook _lookFor(LevelConfig config) {
    if (config.isWorldFinale) return _NodeLook.finale;
    if (config.isMasterLevel) return _NodeLook.master;
    if (RewardTables.isLuckyBoxLevel(config.levelNumber)) return _NodeLook.lucky;
    return _NodeLook.normal;
  }

  /// גודל הצורה עצמה (בלי כוכבים/תווית) - משמש למיקום מדויק על המסלול.
  static double sizeFor(LevelConfig config) {
    switch (_lookFor(config)) {
      case _NodeLook.finale:
        return 82;
      case _NodeLook.master:
        return 76;
      case _NodeLook.lucky:
        return 70;
      case _NodeLook.normal:
        return 64;
    }
  }

  _NodeLook get _look => _lookFor(config);

  double get nodeSize => sizeFor(config);

  @override
  Widget build(BuildContext context) {
    final look = _look;
    final size = nodeSize;
    final isCompleted = progress.stars > 0;

    Widget node = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LevelNodePainter(
          look: look,
          isUnlocked: isUnlocked,
          isCompleted: isCompleted,
          isNextToPlay: isNextToPlay,
        ),
        child: Center(
          child: isUnlocked
              ? Text(
                  '${config.levelNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: look == _NodeLook.finale ? 22 : 20,
                    color: isCompleted || look != _NodeLook.normal
                        ? Colors.white
                        : AppColors.textDark,
                    shadows: look == _NodeLook.normal && !isCompleted
                        ? null
                        : const [Shadow(color: Colors.black38, blurRadius: 6)],
                  ),
                )
              : Icon(
                  Icons.lock_rounded,
                  color: Colors.white.withValues(alpha: look == _NodeLook.normal ? 1 : 0.92),
                  size: look == _NodeLook.finale ? 28 : 24,
                ),
        ),
      ),
    );

    if (look != _NodeLook.normal) {
      node = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          node,
          Positioned(
            top: -8,
            child: _SpecialBadge(look: look),
          ),
        ],
      );

      if (isUnlocked) {
        node = node
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(
              begin: 1,
              end: look == _NodeLook.finale ? 1.06 : 1.04,
              duration: look == _NodeLook.finale ? 900.ms : 1100.ms,
              curve: Curves.easeInOut,
            );
      }
    }

    if (isNextToPlay) {
      node = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          node,
          Positioned(
            bottom: -10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
              ),
              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 14),
            ),
          ),
        ],
      )
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.08, duration: 700.ms, curve: Curves.easeInOut);
    }

    return GestureDetector(
      onTap: isUnlocked ? onTap : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          node,
          const SizedBox(height: 4),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final filled = i < progress.stars;
              return Icon(
                Icons.star_rounded,
                size: 16,
                color: filled ? AppColors.star : AppColors.starEmpty,
              );
            }),
          ),
          if (look != _NodeLook.normal) ...[
            const SizedBox(height: 2),
            Text(
              switch (look) {
                _NodeLook.finale => 'פינאלה',
                _NodeLook.master => 'מאסטר',
                _NodeLook.lucky => 'תיבת מזל',
                _NodeLook.normal => '',
              },
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontWeight: FontWeight.w800,
                fontSize: 10,
                letterSpacing: 0.3,
                shadows: const [Shadow(color: Colors.black54, blurRadius: 6)],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SpecialBadge extends StatelessWidget {
  final _NodeLook look;

  const _SpecialBadge({required this.look});

  @override
  Widget build(BuildContext context) {
    final (icon, colors) = switch (look) {
      _NodeLook.finale => (Icons.emoji_events_rounded, [AppColors.finaleViolet, AppColors.finaleGold]),
      _NodeLook.master => (Icons.bolt_rounded, [AppColors.masterAmber, AppColors.masterDeep]),
      _NodeLook.lucky => (Icons.card_giftcard_rounded, [AppColors.luckyTeal, AppColors.luckyGold]),
      _NodeLook.normal => (Icons.circle, [Colors.white, Colors.white]),
    };

    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(colors: colors),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(color: colors.first.withValues(alpha: 0.7), blurRadius: 10, spreadRadius: 1),
        ],
      ),
      child: Icon(icon, color: Colors.white, size: look == _NodeLook.finale ? 16 : 14),
    );
  }
}

class _LevelNodePainter extends CustomPainter {
  final _NodeLook look;
  final bool isUnlocked;
  final bool isCompleted;
  final bool isNextToPlay;

  _LevelNodePainter({
    required this.look,
    required this.isUnlocked,
    required this.isCompleted,
    required this.isNextToPlay,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    final path = _shapePath(center, radius);

    final colors = _fillColors();
    final glow = colors.first;

    if (look != _NodeLook.normal) {
      canvas.drawPath(
        path,
        Paint()
          ..color = glow.withValues(alpha: isUnlocked ? 0.45 : 0.22)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
      );
    }

    canvas.drawPath(
      path.shift(const Offset(0, 5)),
      Paint()..color = Colors.black.withValues(alpha: 0.22),
    );

    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = look == _NodeLook.normal ? (isNextToPlay ? 3 : 2) : 3.5
        ..color = Colors.white.withValues(alpha: isUnlocked ? 0.95 : 0.55),
    );

    if (look == _NodeLook.finale) {
      canvas.drawPath(
        _shapePath(center, radius - 5),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = AppColors.finaleGold.withValues(alpha: 0.85),
      );
    }
  }

  List<Color> _fillColors() {
    if (!isUnlocked) {
      return switch (look) {
        _NodeLook.finale => [
            AppColors.finaleViolet.withValues(alpha: 0.55),
            const Color(0xFF2B2440).withValues(alpha: 0.7),
          ],
        _NodeLook.master => [
            AppColors.masterDeep.withValues(alpha: 0.5),
            const Color(0xFF4A2A00).withValues(alpha: 0.65),
          ],
        _NodeLook.lucky => [
            AppColors.luckyTeal.withValues(alpha: 0.5),
            const Color(0xFF0A3A40).withValues(alpha: 0.65),
          ],
        _NodeLook.normal => [Colors.white.withValues(alpha: 0.35), Colors.white.withValues(alpha: 0.2)],
      };
    }
    if (isCompleted) {
      return switch (look) {
        _NodeLook.finale => [AppColors.finaleGold, AppColors.finaleViolet],
        _NodeLook.master => [AppColors.star, AppColors.masterDeep],
        _NodeLook.lucky => [AppColors.luckyGold, AppColors.luckyTeal],
        _NodeLook.normal => [AppColors.star, const Color(0xFFFFA726)],
      };
    }
    return switch (look) {
      _NodeLook.finale => [const Color(0xFF9B6DFF), AppColors.finaleViolet],
      _NodeLook.master => [const Color(0xFFFFD54F), AppColors.masterDeep],
      _NodeLook.lucky => [const Color(0xFF80DEEA), AppColors.luckyTeal],
      _NodeLook.normal => [Colors.white, const Color(0xFFF3F3F3)],
    };
  }

  Path _shapePath(Offset center, double radius) {
    switch (look) {
      case _NodeLook.master:
        return _regularPolygon(center, radius, 6, -math.pi / 2);
      case _NodeLook.finale:
        return _diamond(center, radius);
      case _NodeLook.lucky:
        return _roundedSquare(center, radius);
      case _NodeLook.normal:
        return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    }
  }

  Path _regularPolygon(Offset center, double radius, int sides, double startAngle) {
    final path = Path();
    for (int i = 0; i < sides; i++) {
      final angle = startAngle + (2 * math.pi * i / sides);
      final point = Offset(
        center.dx + radius * math.cos(angle),
        center.dy + radius * math.sin(angle),
      );
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    path.close();
    return path;
  }

  Path _diamond(Offset center, double radius) {
    return Path()
      ..moveTo(center.dx, center.dy - radius)
      ..lineTo(center.dx + radius * 0.78, center.dy)
      ..lineTo(center.dx, center.dy + radius)
      ..lineTo(center.dx - radius * 0.78, center.dy)
      ..close();
  }

  Path _roundedSquare(Offset center, double radius) {
    final rect = Rect.fromCircle(center: center, radius: radius * 0.92);
    return Path()..addRRect(RRect.fromRectAndRadius(rect, const Radius.circular(16)));
  }

  @override
  bool shouldRepaint(covariant _LevelNodePainter oldDelegate) {
    return oldDelegate.look != look ||
        oldDelegate.isUnlocked != isUnlocked ||
        oldDelegate.isCompleted != isCompleted ||
        oldDelegate.isNextToPlay != isNextToPlay;
  }
}
