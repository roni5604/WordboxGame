import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import 'candy_button.dart';

/// פותח חלון קופץ בסגנון משחק: הרקע מטושטש ומוחשך, והחלון "קופץ" פנימה
/// בתנועת קפיץ (scale + fade), ויוצא באותה רכות.
Future<T?> showGameDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
  bool useRootNavigator = true,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierLabel: 'סגירה',
    barrierColor: Colors.black.withValues(alpha: 0.45),
    useRootNavigator: useRootNavigator,
    transitionDuration: const Duration(milliseconds: 420),
    pageBuilder: (dialogContext, _, _) => builder(dialogContext),
    transitionBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.elasticOut,
        reverseCurve: Curves.easeInBack,
      );
      final fade = CurvedAnimation(parent: animation, curve: const Interval(0, 0.4));
      return BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 6 * animation.value, sigmaY: 6 * animation.value),
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.7, end: 1).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// חלון קופץ מעוצב: כותרת על "סרט" צבעוני, אייקון/קמע עליון אופציונלי,
/// תוכן וכפתורי פעולה גדולים.
class GameDialog extends StatelessWidget {
  final String title;
  final Widget? hero;
  final Widget? body;
  final String? message;
  final List<Widget> actions;
  final CandyPalette ribbon;
  final VoidCallback? onClose;

  const GameDialog({
    super.key,
    required this.title,
    this.hero,
    this.body,
    this.message,
    this.actions = const [],
    this.ribbon = CandyPalette.purple,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.sizeOf(context).width.clamp(0, 420).toDouble();
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: Material(
            color: Colors.transparent,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 22),
                  padding: const EdgeInsets.fromLTRB(20, 38, 20, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: ribbon.top.withValues(alpha: 0.6), width: 3),
                    boxShadow: const [
                      BoxShadow(color: Colors.black38, blurRadius: 30, offset: Offset(0, 14)),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hero != null) ...[hero!, const SizedBox(height: 12)],
                      if (message != null)
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            height: 1.4,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF3B3355),
                          ),
                        ),
                      ?body,
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (int i = 0; i < actions.length; i++) ...[
                          if (i > 0) const SizedBox(height: 10),
                          actions[i],
                        ],
                      ],
                    ],
                  ),
                ),
                // "סרט" הכותרת.
                Positioned(
                  top: 0,
                  left: 34,
                  right: 34,
                  child: Container(
                    height: 46,
                    alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [ribbon.top, ribbon.bottom],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: ribbon.lip, offset: const Offset(0, 4))],
                    ),
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: ribbon.text,
                        fontWeight: FontWeight.w900,
                        fontSize: 19,
                        shadows: [Shadow(color: ribbon.lip, offset: const Offset(0, 2))],
                      ),
                    ),
                  ),
                ),
                if (onClose != null)
                  PositionedDirectional(
                    top: 8,
                    end: -6,
                    child: CandyIconButton(
                      icon: Icons.close_rounded,
                      size: 38,
                      palette: CandyPalette.red,
                      onPressed: onClose,
                      tooltip: 'סגירה',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// דיאלוג אישור קצר (כן/לא) בעיצוב המשחק. מחזיר true אם אושר.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  String cancelLabel = 'ביטול',
  CandyPalette confirmPalette = CandyPalette.orange,
  Widget? hero,
}) async {
  final result = await showGameDialog<bool>(
    context: context,
    builder: (dialogContext) => GameDialog(
      title: title,
      message: message,
      hero: hero,
      actions: [
        CandyButton(
          label: confirmLabel,
          palette: confirmPalette,
          height: 54,
          fontSize: 18,
          onPressed: () => Navigator.of(dialogContext).pop(true),
        ),
        CandyButton(
          label: cancelLabel,
          palette: CandyPalette.white,
          height: 50,
          fontSize: 16,
          onPressed: () => Navigator.of(dialogContext).pop(false),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// הודעה צפה קצרה מלמעלה (בסגנון התראות משחק) - לא חוסמת את המסך.
/// נכנסת בקפיץ ויוצאת בהחלקה למעלה. אם יש [onTap] - לחיצה עליה מבצעת
/// פעולה (למשל "פתיחת בקשות החברות") ואפשר להחליק אותה למעלה כדי לסגור.
class GameToast {
  GameToast._();

  static OverlayEntry? _current;
  static GlobalKey<_ToastViewState>? _currentKey;
  static Timer? _timer;

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.check_circle_rounded,
    Color color = const Color(0xFF33C24D),
    Duration duration = const Duration(milliseconds: 2400),
    VoidCallback? onTap,
    String? actionLabel,
  }) {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    _timer?.cancel();
    _current?.remove();
    final key = GlobalKey<_ToastViewState>();
    late final OverlayEntry entry;
    void remove() {
      if (_current == entry) {
        entry.remove();
        _current = null;
        _currentKey = null;
      }
    }

    entry = OverlayEntry(
      builder: (context) => _ToastView(
        key: key,
        message: message,
        icon: icon,
        color: color,
        actionLabel: actionLabel,
        onTap: onTap == null
            ? null
            : () {
                _timer?.cancel();
                key.currentState?.dismiss(remove);
                onTap();
              },
        onDismissed: remove,
      ),
    );
    _current = entry;
    _currentKey = key;
    overlay.insert(entry);
    _timer = Timer(duration, () {
      final state = key.currentState;
      if (state != null) {
        state.dismiss(remove);
      } else {
        remove();
      }
    });
  }

  /// סוגר את ההודעה המוצגת (אם יש) באנימציה.
  static void hide() {
    _timer?.cancel();
    final entry = _current;
    final state = _currentKey?.currentState;
    if (entry == null) return;
    void remove() {
      if (_current == entry) {
        entry.remove();
        _current = null;
        _currentKey = null;
      }
    }

    if (state != null) {
      state.dismiss(remove);
    } else {
      remove();
    }
  }
}

class _ToastView extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;
  final String? actionLabel;
  final VoidCallback onDismissed;

  const _ToastView({
    super.key,
    required this.message,
    required this.icon,
    required this.color,
    required this.onDismissed,
    this.onTap,
    this.actionLabel,
  });

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 450),
    reverseDuration: const Duration(milliseconds: 240),
  )..forward();
  double _drag = 0;
  bool _dismissing = false;

  void dismiss(VoidCallback done) {
    if (_dismissing) return;
    _dismissing = true;
    _controller.reverse().whenComplete(done);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.viewPaddingOf(context).top + 10;
    final card = Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: widget.color, width: 2.5),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: Row(
          children: [
            Icon(widget.icon, color: widget.color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                widget.message,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF2B2440)),
              ),
            ),
            if (widget.actionLabel != null) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: widget.color, borderRadius: BorderRadius.circular(14)),
                child: Text(
                  widget.actionLabel!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    return Positioned(
      top: top,
      left: 16,
      right: 16,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final v = _controller.status == AnimationStatus.reverse
              ? Curves.easeInCubic.transform(_controller.value)
              : Curves.easeOutBack.transform(_controller.value);
          return Opacity(
            opacity: _controller.value.clamp(0.0, 1.0),
            child: Transform.translate(offset: Offset(0, -40 * (1 - v) + _drag), child: child),
          );
        },
        // הודעה בלי פעולה לא חוסמת לחיצות על מה שמתחתיה (למשל כפתור
        // החזרה בכותרת). הודעה עם פעולה - לחיצה מבצעת, והחלקה למעלה סוגרת.
        child: widget.onTap == null
            ? IgnorePointer(child: card)
            : GestureDetector(
                onTap: widget.onTap,
                onVerticalDragUpdate: (d) => setState(() => _drag = (_drag + d.delta.dy).clamp(-80.0, 12.0)),
                onVerticalDragEnd: (d) {
                  if (_drag < -24 || d.velocity.pixelsPerSecond.dy < -300) {
                    dismiss(widget.onDismissed);
                  } else {
                    setState(() => _drag = 0);
                  }
                },
                child: card,
              ),
      ),
    );
  }
}
