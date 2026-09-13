import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../game/widgets/mascot_widget.dart';

class ScoreboardEntry {
  final String name;
  final int score;
  final bool isHuman;

  /// מודגש/ת בהדגשה חזקה יותר מ-[isHuman] הרגילה - שימושי במשחק מול חברים
  /// כדי להבליט את השחקן/ית הצופה עצמו/ה בין כמה שחקנים אמיתיים (ולא רק
  /// "אנושי מול בוט"). ברירת המחדל false לא משנה כלל את התצוגה הקיימת
  /// במשחק מול המחשב.
  final bool isMe;

  const ScoreboardEntry({
    required this.name,
    required this.score,
    required this.isHuman,
    this.isMe = false,
  });
}

/// לוח תוצאות חי, ממוין לפי ניקוד - מוצג לצד הלוח במהלך תחרות מקומית,
/// כדי שהשחקן/ית יראה/תראה בזמן אמת איך הוא/היא מתקדם/ת מול היריבים.
class LiveScoreboard extends StatelessWidget {
  final List<ScoreboardEntry> entries; // כבר ממוין

  const LiveScoreboard({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isLeader = index == 0;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: entry.isMe ? 12 : 10, vertical: entry.isMe ? 8 : 6),
            decoration: BoxDecoration(
              color: entry.isHuman ? Colors.white : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: entry.isMe
                  ? Border.all(color: AppColors.accent, width: 2.5)
                  : (isLeader ? Border.all(color: AppColors.star, width: 2) : null),
              boxShadow: entry.isMe
                  ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)]
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLeader)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.emoji_events_rounded, color: AppColors.star, size: 18),
                  ),
                MascotWidget(
                  mood: entry.isHuman ? MascotMood.happy : MascotMood.idle,
                  size: entry.isMe ? 30 : 26,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: entry.isMe ? AppColors.accent : null,
                      ),
                    ),
                    Text(
                      '${entry.score} נק׳',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: entry.isMe ? 16 : 13,
                        color: entry.isMe ? AppColors.accent : null,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
