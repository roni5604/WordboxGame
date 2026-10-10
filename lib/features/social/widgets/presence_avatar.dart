import 'package:flutter/material.dart';

import '../../../core/ui/game_backdrop.dart';
import '../../profile/widgets/avatar_widget.dart';
import '../models/social_models.dart';

/// אוואטאר עם נקודת נוכחות: ירוקה פועמת = מחובר/ת, כתומה = באמצע משחק,
/// בלי נקודה = לא מחובר/ת. כמו רשימות החברים ב-Clash Royale.
class PresenceAvatar extends StatelessWidget {
  final String avatarId;
  final String? photoUrl;
  final PresenceStatus status;
  final double size;

  const PresenceAvatar({
    super.key,
    required this.avatarId,
    this.photoUrl,
    this.status = PresenceStatus.offline,
    this.size = 52,
  });

  factory PresenceAvatar.of(PublicProfile profile, {double size = 52, Key? key}) => PresenceAvatar(
        key: key,
        avatarId: profile.avatarId,
        photoUrl: profile.photoUrl,
        status: profile.effectiveStatus(),
        size: size,
      );

  @override
  Widget build(BuildContext context) {
    final dot = size * 0.3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Opacity(
            opacity: status == PresenceStatus.offline ? 0.75 : 1,
            child: AvatarWidget(avatarId: avatarId, photoUrl: photoUrl, size: size, ring: false),
          ),
          if (status != PresenceStatus.offline)
            PositionedDirectional(
              bottom: -1,
              end: -1,
              child: _PresenceDot(
                size: dot,
                color: status == PresenceStatus.online ? const Color(0xFF2EDB5B) : const Color(0xFFFFA726),
                pulse: status == PresenceStatus.online,
              ),
            ),
        ],
      ),
    );
  }
}

class _PresenceDot extends StatefulWidget {
  final double size;
  final Color color;
  final bool pulse;
  const _PresenceDot({required this.size, required this.color, required this.pulse});

  @override
  State<_PresenceDot> createState() => _PresenceDotState();
}

class _PresenceDotState extends State<_PresenceDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.pulse && AmbientMotion.enabledFor(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (widget.pulse)
                Container(
                  width: widget.size * (1 + t * 1.2),
                  height: widget.size * (1 + t * 1.2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: 0.45 * (1 - t)),
                  ),
                ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
