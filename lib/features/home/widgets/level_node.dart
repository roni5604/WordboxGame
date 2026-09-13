import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../data/models/level_progress.dart';
import '../../../game_engine/models/level_config.dart';

/// נקודת שלב בודדת על מפת הקמפיין - מעגל עם מספר השלב, כוכבים שהושגו,
/// ומצב חזותי (נעול / פתוח לשחק / הושלם).
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

  @override
  Widget build(BuildContext context) {
    final size = 64.0;

    final isCompleted = progress.stars > 0;
    final isMaster = config.isMasterLevel;
    final isFinale = config.isWorldFinale;

    // שלבי מאסטר/פינאלה מקבלים טבעת צבע ייחודית משלהם (כשפתוחים), כדי
    // שיבלטו על המפה עוד לפני שנלחצים - ענבר למאסטר, סגול-כתר לפינאלה.
    final specialRingColor = isFinale
        ? const Color(0xFF7C4DFF)
        : (isMaster ? const Color(0xFFFFA000) : null);

    Widget node = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isUnlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isCompleted
                    ? [AppColors.star, const Color(0xFFFFA726)]
                    : [Colors.white, const Color(0xFFF3F3F3)],
              )
            : null,
        color: isUnlocked ? null : Colors.white.withValues(alpha: 0.35),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
          if (isUnlocked && specialRingColor != null)
            BoxShadow(
              color: specialRingColor.withValues(alpha: 0.6),
              blurRadius: 14,
              spreadRadius: 1,
            ),
        ],
        border: isNextToPlay
            ? Border.all(color: Colors.white, width: 3)
            : Border.all(
                color: isUnlocked && specialRingColor != null
                    ? specialRingColor
                    : Colors.white,
                width: isUnlocked && specialRingColor != null ? 3 : 2,
              ),
      ),
      child: Center(
        child: isUnlocked
            ? Text(
                '${config.levelNumber}',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                  color: isCompleted ? Colors.white : AppColors.textDark,
                ),
              )
            : const Icon(Icons.lock, color: Colors.white, size: 26),
      ),
    );

    if (isUnlocked && (isMaster || isFinale)) {
      node = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          node,
          Positioned(
            top: -6,
            right: -6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: specialRingColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.5),
              ),
              child: Icon(
                isFinale ? Icons.emoji_events_rounded : Icons.bolt_rounded,
                color: Colors.white,
                size: 14,
              ),
            ),
          ),
        ],
      );
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
          .scaleXY(begin: 1, end: 1.1, duration: 700.ms, curve: Curves.easeInOut);
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
        ],
      ),
    );
  }
}
