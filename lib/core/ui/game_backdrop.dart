import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pressable.dart';

/// אנימציות "אווירה" אינסופיות (בועות שמרחפות ברקע וכו') כבויות בבדיקות
/// אוטומטיות ובמכשירים שביקשו להפחית תנועה - כדי ש-pumpAndSettle יסתיים,
/// ומשתמשים רגישים לתנועה לא יקבלו רקע זז.
class AmbientMotion {
  AmbientMotion._();

  static bool get _isTest => WidgetsBinding.instance.runtimeType.toString().contains('Test');

  static bool enabledFor(BuildContext context) =>
      !_isTest && !MediaQuery.of(context).disableAnimations;
}

/// סגנון שורת הסטטוס של המערכת למסכים צבעוניים (אייקונים לבנים, רקע שקוף)
/// - הרקע של המסך עצמו ממשיך עד קצה המסך, גם מאחורי ה"אי" של האייפון.
const SystemUiOverlayStyle kLightSystemBars = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.transparent,
  systemNavigationBarIconBrightness: Brightness.light,
  systemNavigationBarContrastEnforced: false,
);

/// רווח תחתון "נוח" מעל פס הבית של האייפון / כפתורי הניווט של אנדרואיד:
/// לעולם לא פחות מ-[min], וגם כשיש פס בית מוסיפים מעליו מרווח קטן -
/// כך כפתורים לא יושבים "בהכי למטה" של המסך.
extension SafeInsets on BuildContext {
  double safeBottom({double min = 16, double extra = 10}) {
    final inset = MediaQuery.viewPaddingOf(this).bottom;
    return inset > 0 ? inset + extra : min;
  }

  double get safeTop => MediaQuery.viewPaddingOf(this).top;
}

/// רקע מלא-מסך לכל מסכי המשחק: גרדיאנט שממשיך עד הקצוות (מאחורי שורת
/// הסטטוס, ה-notch/Dynamic Island ופס הבית), עם בועות אור רכות שמרחפות
/// לאט - כמו הרקעים החיים במשחקי מובייל מובילים. התוכן עצמו נשאר בתוך
/// האזור הבטוח (ראו [GameScaffold]).
class GameBackdrop extends StatefulWidget {
  final List<Color> colors;
  final Widget child;
  final bool bubbles;

  const GameBackdrop({super.key, required this.colors, required this.child, this.bubbles = true});

  @override
  State<GameBackdrop> createState() => _GameBackdropState();
}

class _GameBackdropState extends State<GameBackdrop> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 40),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.bubbles && AmbientMotion.enabledFor(context)) {
      if (!_controller.isAnimating) _controller.repeat();
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: kLightSystemBars,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: widget.colors,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (widget.bubbles)
              RepaintBoundary(
                child: CustomPaint(
                  painter: _BubblesPainter(_controller),
                ),
              ),
            widget.child,
          ],
        ),
      ),
    );
  }
}

class _BubblesPainter extends CustomPainter {
  final Animation<double> t;
  _BubblesPainter(this.t) : super(repaint: t);

  static final _bubbles = List.generate(14, (i) {
    final r = math.Random(i * 7919 + 13);
    return (
      x: r.nextDouble(),
      y: r.nextDouble(),
      radius: 18 + r.nextDouble() * 70,
      speed: 0.4 + r.nextDouble() * 0.9,
      phase: r.nextDouble() * math.pi * 2,
      alpha: 0.05 + r.nextDouble() * 0.08,
    );
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final b in _bubbles) {
      final progress = (t.value * b.speed + b.y) % 1.0;
      final dy = size.height * (1.15 - progress * 1.3);
      final dx = size.width * b.x + math.sin(t.value * math.pi * 2 * b.speed + b.phase) * 24;
      paint.shader = RadialGradient(
        colors: [Colors.white.withValues(alpha: b.alpha * 1.6), Colors.white.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: Offset(dx, dy), radius: b.radius));
      canvas.drawCircle(Offset(dx, dy), b.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BubblesPainter oldDelegate) => false;
}

/// שלד אחיד למסך: רקע מלא-מסך + כותרת עליונה בתוך האזור הבטוח + גוף.
/// [bottomBar] (אם יש) יושב מעל פס הבית עם מרווח נוח.
class GameScaffold extends StatelessWidget {
  final List<Color> colors;
  final Widget? header;
  final Widget body;
  final Widget? bottomBar;
  final bool bubbles;
  final bool resizeToAvoidBottomInset;

  const GameScaffold({
    super.key,
    required this.colors,
    required this.body,
    this.header,
    this.bottomBar,
    this.bubbles = true,
    this.resizeToAvoidBottomInset = true,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: colors.last,
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      body: GameBackdrop(
        colors: colors,
        bubbles: bubbles,
        child: Column(
          children: [
            SafeArea(
              bottom: false,
              child: header ?? const SizedBox(height: 4),
            ),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: body,
              ),
            ),
            if (bottomBar != null)
              Padding(
                padding: EdgeInsets.fromLTRB(20, 8, 20, context.safeBottom()),
                child: bottomBar,
              ),
          ],
        ),
      ),
    );
  }
}

/// פס כותרת למסכים: כפתור חזרה עגול, כותרת גדולה עם צל, ואלמנט אופציונלי
/// בצד השני. מחליף את ה-AppBar הסטנדרטי (שנראה "אפליקציית משרד").
class GameHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final Widget? trailing;
  final IconData backIcon;

  const GameHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.trailing,
    this.backIcon = Icons.arrow_back_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
      child: Row(
        children: [
          if (onBack != null)
            _HeaderBackButton(icon: backIcon, onPressed: onBack!)
          else
            const SizedBox(width: 44),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 6)],
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13, fontWeight: FontWeight.w600),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(width: 44, child: trailing),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _HeaderBackButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      semanticLabel: 'חזרה',
      onTap: onPressed,
      child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.22),
            border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Icon(icon, color: Colors.white, size: 24),
      ),
    );
  }
}
