import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../game/widgets/mascot_widget.dart';

class ScoreboardEntry {
  final String name;
  final int score;
  final bool isHuman;

  const ScoreboardEntry({required this.name, required this.score, required this.isHuman});
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
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: entry.isHuman ? Colors.white : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: isLeader ? Border.all(color: AppColors.star, width: 2) : null,
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
                  size: 26,
                ),
                const SizedBox(width: 6),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      entry.name,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
                    ),
                    Text(
                      '${entry.score} נק׳',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
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
