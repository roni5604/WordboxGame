import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../game_engine/bot_commentary.dart';
import '../../profile/widgets/avatar_widget.dart';

/// בועת דיבור של יריב: הדמות שלו "קופצת" עם בועה, ונעלמת לבד אחרי כמה
/// שניות. לא חוסמת נגיעות (IgnorePointer) - אפשר להמשיך לגרור מתחתיה.
class BotSpeechBubble extends StatelessWidget {
  final BotComment comment;
  final String avatarId;

  const BotSpeechBubble({super.key, required this.comment, required this.avatarId});

  static const visibleFor = Duration(milliseconds: 3200);

  Color get _accent => switch (comment.mood) {
    CommentMood.cheeky => const Color(0xFFFF7A45),
    CommentMood.impressed => const Color(0xFF9B5CF6),
    CommentMood.nervous => const Color(0xFFE6397A),
    CommentMood.thinking => const Color(0xFF2E8BFF),
    CommentMood.friendly => const Color(0xFF1FB86A),
  };

  @override
  Widget build(BuildContext context) {
    final accent = _accent;
    final bubble = Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 12)],
              ),
              child: AvatarWidget(avatarId: avatarId, size: 46, ring: false),
            )
            .animate()
            .scale(begin: const Offset(0.2, 0.2), curve: Curves.elasticOut, duration: 650.ms)
            .then()
            .shake(hz: 3, rotation: 0.05, duration: 400.ms),
        const SizedBox(width: 6),
        Flexible(
          child:
              Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: const BorderRadiusDirectional.only(
                        topStart: Radius.circular(18),
                        topEnd: Radius.circular(18),
                        bottomEnd: Radius.circular(18),
                        bottomStart: Radius.circular(4),
                      ),
                      border: Border.all(color: accent.withValues(alpha: 0.6), width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.22),
                          blurRadius: 12,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          comment.botName,
                          style: TextStyle(color: accent, fontSize: 11, fontWeight: FontWeight.w900),
                        ),
                        Text(
                          comment.text,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF2B2440),
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 120.ms, duration: 200.ms)
                  .scaleXY(begin: 0.7, curve: Curves.easeOutBack, duration: 380.ms),
        ),
      ],
    );
    return IgnorePointer(
      child: bubble
          .animate(delay: visibleFor - 450.ms)
          .fadeOut(duration: 400.ms)
          .slideY(end: -0.3, duration: 400.ms, curve: Curves.easeIn),
    );
  }
}
