import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// פס התקדמות "מטרת המילים" בזמן המשחק - מציג בבירור כמה מילים עוד
/// נותרו כדי להגיע ליעד השלב, ותצוגת שלושה כוכבים "חיה" שמתמלאת בזמן
/// אמת ברגע שהיחס בין מילים שנמצאו למילים שנדרשו עולה (ראו
/// GameSession.currentStars) - כך שברור לשחקן/ית בכל רגע כמה נשארו
/// וכמה כוכבים כבר "בכיס".
class WordsGoalPanel extends StatelessWidget {
  final int found;
  final int required;
  final int stars;

  const WordsGoalPanel({
    super.key,
    required this.found,
    required this.required,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (required - found).clamp(0, required);
    final label = remaining > 0
        ? 'עוד $remaining ${remaining == 1 ? "מילה" : "מילים"} למטרה 🎯'
        : '🎉 המטרה הושגה! השלב מסתיים...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.textDark,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final filled = i < stars;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedScale(
                  scale: filled ? 1.0 : 0.7,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.elasticOut,
                  child: Icon(
                    Icons.star_rounded,
                    size: 20,
                    color: filled ? AppColors.star : Colors.grey.shade300,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}
