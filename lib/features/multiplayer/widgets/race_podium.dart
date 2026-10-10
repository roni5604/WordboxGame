import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../game/widgets/mascot_widget.dart';
import '../../profile/widgets/avatar_widget.dart';

/// משתתף/ת בפודיום התוצאות (תחרות מול המחשב או מול חברים).
class PodiumEntry {
  final String name;
  final int score;
  final int wordsFound;
  final bool isMe;
  final String? avatarId;
  final String? photoUrl;

  /// ניצחונות מצטברים בסדרה (אופציונלי).
  final int? wins;

  const PodiumEntry({
    required this.name,
    required this.score,
    required this.wordsFound,
    this.isMe = false,
    this.avatarId,
    this.photoUrl,
    this.wins,
  });
}

/// פודיום בסגנון משחקי תחרות: מקום ראשון במרכז וגבוה, שני וימינה/שמאלה
/// נמוכים יותר, והעמודים "צומחים" מלמטה בזה אחר זה. משתתפים ממקום 4
/// והלאה מוצגים כשורות מתחת.
class RacePodium extends StatelessWidget {
  /// ממוינים מהמקום הראשון.
  final List<PodiumEntry> entries;

  const RacePodium({super.key, required this.entries});

  static const _medals = [Color(0xFFFFC93C), Color(0xFFCBD5E1), Color(0xFFE0A26B)];

  @override
  Widget build(BuildContext context) {
    final top = entries.take(3).toList();
    final rest = entries.skip(3).toList();
    // סדר ויזואלי: 2 - 1 - 3 (ב-RTL השני מופיע מימין).
    final order = <int>[if (top.length > 1) 1, 0, if (top.length > 2) 2];
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final i in order)
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: _PodiumColumn(entry: top[i], rank: i + 1, color: _medals[i]),
                ),
              ),
          ],
        ),
        for (int i = 0; i < rest.length; i++)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _RestRow(
              entry: rest[i],
              rank: i + 4,
            ).animate(delay: (900 + 120 * i).ms).fadeIn().slideX(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
          ),
      ],
    );
  }
}

class _PodiumColumn extends StatelessWidget {
  final PodiumEntry entry;
  final int rank;
  final Color color;

  const _PodiumColumn({required this.entry, required this.rank, required this.color});

  @override
  Widget build(BuildContext context) {
    final height = switch (rank) {
      1 => 128.0,
      2 => 96.0,
      _ => 74.0,
    };
    final avatarSize = rank == 1 ? 64.0 : 52.0;
    // העמוד הנמוך עולה ראשון, והמנצח/ת אחרון - בונה מתח.
    final delay = switch (rank) {
      3 => 200,
      2 => 420,
      _ => 640,
    };
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 118),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (rank == 1)
            const Text('👑', style: TextStyle(fontSize: 28))
                .animate(delay: (delay + 350).ms)
                .fadeIn()
                .moveY(begin: -18, end: 0, curve: Curves.bounceOut, duration: 600.ms),
          Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: entry.isMe ? AppColors.accent : Colors.white,
                  boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: rank == 1 ? 18 : 8)],
                ),
                child: entry.avatarId != null
                    ? AvatarWidget(avatarId: entry.avatarId!, photoUrl: entry.photoUrl, size: avatarSize, ring: false)
                    : ClipOval(
                        child: Container(
                          color: Colors.white,
                          width: avatarSize,
                          height: avatarSize,
                          alignment: Alignment.center,
                          child: MascotWidget(mood: MascotMood.idle, size: avatarSize * 0.9),
                        ),
                      ),
              )
              .animate(delay: delay.ms)
              .fadeIn()
              .scale(begin: const Offset(0.4, 0.4), curve: Curves.elasticOut, duration: 700.ms),
          const SizedBox(height: 6),
          Text(
            entry.isMe ? '${entry.name} (את/ה)' : entry.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: rank == 1 ? 16 : 14,
              shadows: const [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))],
            ),
          ).animate(delay: delay.ms).fadeIn(),
          const SizedBox(height: 6),
          Container(
                height: height,
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color.lerp(color, Colors.white, 0.35)!, color],
                  ),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '$rank',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: rank == 1 ? 40 : 30,
                        fontWeight: FontWeight.w900,
                        height: 1,
                        shadows: const [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: entry.score),
                      duration: Duration(milliseconds: 800 + delay),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => Text(
                        '$v נק׳',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
                      ),
                    ),
                    if (entry.wins != null)
                      Text(
                        '${entry.wins} ניצחונות',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              )
              .animate(delay: delay.ms)
              .scaleY(begin: 0, end: 1, alignment: Alignment.bottomCenter, curve: Curves.easeOutBack, duration: 550.ms),
        ],
      ),
    );
  }
}

class _RestRow extends StatelessWidget {
  final PodiumEntry entry;
  final int rank;
  const _RestRow({required this.entry, required this.rank});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: entry.isMe ? Colors.white : Colors.white.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: entry.isMe ? Border.all(color: AppColors.accent, width: 2.5) : null,
      ),
      child: Row(
        children: [
          Text(
            '$rank',
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: Colors.black45),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              entry.isMe ? '${entry.name} (את/ה)' : entry.name,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          Text('${entry.wordsFound} מילים', style: const TextStyle(color: Colors.black45, fontSize: 12)),
          const SizedBox(width: 10),
          Text('${entry.score} נק׳', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
        ],
      ),
    );
  }
}
