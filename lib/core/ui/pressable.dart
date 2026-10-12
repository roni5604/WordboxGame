import 'package:flutter/material.dart';
import '../feedback/haptics.dart';

/// משוב גלובלי ללחיצה (צליל + רטט). מוגדר פעם אחת ב-app.dart כדי שכל
/// הכפתורים באפליקציה ישמיעו את אותו צליל - בבדיקות נשאר no-op.
class PressFeedback {
  PressFeedback._();

  static VoidCallback onPress = () {};

  static void trigger({bool haptic = true}) {
    if (haptic) Haptics.light();
    onPress();
  }
}

/// עוטף כל אלמנט לחיץ ומוסיף לו את "התחושה" של משחקים כמו Candy Crush /
/// Clash Royale: הכפתור "נלחץ פנימה" (מתכווץ מעט) ברגע המגע, וקופץ חזרה
/// בתנועת קפיץ כשמשחררים - כך כל לחיצה מרגישה מוחשית.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// עד כמה הכפתור מתכווץ בלחיצה (1 = לא מתכווץ).
  final double pressedScale;

  /// האם להשמיע צליל/רטט גלובלי בלחיצה.
  final bool feedback;
  final String? semanticLabel;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.93,
    this.feedback = true,
    this.semanticLabel,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 420),
  );
  late final Animation<double> _scale = Tween<double>(begin: 1, end: widget.pressedScale).animate(
    CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
      reverseCurve: Curves.elasticOut,
    ),
  );

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _down(TapDownDetails _) {
    if (!_enabled) return;
    _controller.forward();
  }

  void _up() {
    if (!_enabled) return;
    _controller.reverse();
  }

  void _tap() {
    if (widget.onTap == null) return;
    // מוודאים שגם לחיצה מהירה מאוד מציגה את "הלחיצה פנימה".
    _controller.forward().then((_) {
      if (mounted) _controller.reverse();
    });
    if (widget.feedback) PressFeedback.trigger();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: _down,
        onTapUp: (_) => _up(),
        onTapCancel: _up,
        onTap: widget.onTap == null ? null : _tap,
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
          child: AnimatedOpacity(
            opacity: _enabled ? 1 : 0.55,
            duration: const Duration(milliseconds: 200),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
