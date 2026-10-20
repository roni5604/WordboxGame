import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../game/widgets/mascot_widget.dart';
import '../../profile/widgets/avatar_widget.dart';

class ScoreboardEntry {
  final String name;
  final int score;
  final bool isHuman;

  /// מודגש/ת בהדגשה חזקה יותר מ-[isHuman] הרגילה - שימושי במשחק מול חברים
  /// כדי להבליט את השחקן/ית הצופה עצמו/ה בין כמה שחקנים אמיתיים (ולא רק
  /// "אנושי מול בוט"). ברירת המחדל false לא משנה כלל את התצוגה הקיימת
  /// במשחק מול המחשב.
  final bool isMe;

  /// מזהה האוואטאר המצויר שנבחר בפרופיל ([PlayerProfile.avatarId]) -
  /// כשקיים (רק לשחקן/ית האמיתי/ת הצופה, ראו live_scoreboard.dart קריאה),
  /// מוצג במקום קמע גנרי. null לבוטים/יריבים שאין להם פרופיל מקומי.
  final String? avatarId;

  /// תמונת הפרופיל האמיתית (Google/Apple) אם קיימת - מוצגת
  /// במקום האוואטאר המצויר. ראו lib/features/profile/widgets/avatar_widget.dart.
  final String? photoUrl;

  /// ניצחונות מצטברים בסדרת משחקונים - מוצג רק כשקיים (חדר פרטי עם יותר
  /// ממשחקון אחד). לא בשימוש במצב מול המחשב.
  final int? wins;

  /// עולה ב-1 בכל פעם שהמשתתף/ת צבר/ה נקודות - מפעיל "פעימה" ו-+N מעל
  /// הכרטיס. כך רואים שהיריב מצא מילה **בלי** לחשוף איזו מילה.
  final int gainToken;

  /// כמה נקודות נוספו באירוע האחרון (מוצג כ-+N).
  final int lastGain;

  const ScoreboardEntry({
    required this.name,
    required this.score,
    required this.isHuman,
    this.isMe = false,
    this.avatarId,
    this.photoUrl,
    this.wins,
    this.gainToken = 0,
    this.lastGain = 0,
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
      height: 76,
      child: ListView.separated(
        padding: const EdgeInsets.only(top: 12),
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        itemCount: entries.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final entry = entries[index];
          final isLeader = index == 0;
          final card = AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.symmetric(horizontal: entry.isMe ? 12 : 10, vertical: entry.isMe ? 8 : 6),
            decoration: BoxDecoration(
              color: entry.isHuman ? Colors.white : Colors.white.withValues(alpha: 0.75),
              borderRadius: BorderRadius.circular(16),
              border: entry.isMe
                  ? Border.all(color: AppColors.accent, width: 2.5)
                  : (isLeader ? Border.all(color: AppColors.star, width: 2) : null),
              boxShadow: entry.isMe ? [BoxShadow(color: AppColors.accent.withValues(alpha: 0.4), blurRadius: 8)] : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isLeader)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(Icons.emoji_events_rounded, color: AppColors.star, size: 18),
                  ),
                entry.avatarId != null
                    ? AvatarWidget(
                        avatarId: entry.avatarId!,
                        photoUrl: entry.photoUrl,
                        size: entry.isMe ? 30 : 26,
                        ring: false,
                      )
                    : MascotWidget(
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
                      entry.wins == null ? '${entry.score} נק׳' : '${entry.score} נק׳ · ${entry.wins}נ׳',
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
          if (entry.gainToken == 0) return card;
          // פעימה + "+N" צף בכל פעם שהמשתתף/ת צובר/ת נקודות.
          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.topCenter,
            children: [
              card
                  .animate(key: ValueKey('pulse-${entry.name}-${entry.gainToken}'))
                  .scaleXY(begin: 1, end: 1.12, duration: 140.ms, curve: Curves.easeOut)
                  .then()
                  .scaleXY(begin: 1.12, end: 1, duration: 260.ms, curve: Curves.elasticOut),
              Positioned(
                top: -6,
                child: IgnorePointer(
                  child:
                      Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: entry.isMe ? AppColors.success : AppColors.star,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
                            ),
                            child: Text(
                              '+${entry.lastGain}',
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12),
                            ),
                          )
                          .animate(key: ValueKey('gain-${entry.name}-${entry.gainToken}'))
                          .fadeIn(duration: 120.ms)
                          .moveY(begin: 6, end: -14, duration: 900.ms, curve: Curves.easeOutCubic)
                          .then(delay: 150.ms)
                          .fadeOut(duration: 300.ms),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
