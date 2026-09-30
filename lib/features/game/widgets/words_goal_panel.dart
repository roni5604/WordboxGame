import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// פס התקדמות "מטרת הניקוד" בזמן המשחק - מציג כמה נקודות עוד נותרו
/// ליעד השלב, ותצוגת שלושה כוכבים שמתמלאת ברגע שהיחס בין הניקוד ליעד
/// עולה (ראו GameSession.currentStars).
class WordsGoalPanel extends StatelessWidget {
  final int score;
  final int required;
  final int stars;

  const WordsGoalPanel({
    super.key,
    required this.score,
    required this.required,
    required this.stars,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = (required - score).clamp(0, required);
    final unit = remaining == 1 ? 'נקודה' : 'נקודות';
    final label = remaining > 0
        ? 'עוד $remaining $unit למטרה 🎯'
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
