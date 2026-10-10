import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/platform/top_bar_tint.dart';
import '../../core/ui/game_backdrop.dart';
import '../../providers/dictionary_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/letter_tile.dart';

/// צבעי מסך הפתיחה - שקיעה כתומה-ורודה-סגולה, כמו האייקון.
const kSplashGradient = [Color(0xFFFF8A3D), Color(0xFFFF5E7E), Color(0xFF9B5CFF)];

/// הלוח שמוצג בפתיחה, והנתיב שמאוית עליו: מ → י → ל → ה (כולל צעד באלכסון).
const _board = [
  ['מ', 'צ', 'א'],
  ['ת', 'י', 'ל'],
  ['ש', 'ב', 'ה'],
];
const _path = [(0, 0), (1, 1), (1, 2), (2, 2)];

const _tips = [
  'אפשר לחבר אותיות גם באלכסון ↘',
  'מילה ארוכה שווה הרבה יותר נקודות',
  'כל יום יש אתגר יומי חדש - אותו לוח לכולם',
  'הזמינו חברים ותתחרו על אותו לוח בזמן אמת',
  'בלי כוכב אחד לפחות השלב הבא נשאר נעול',
];

/// מסך פתיחה מונפש: לוח אותיות בתלת-מימד שהאריחים שלו "נוחתים" אחד-אחד,
/// קו זוהר שמאיית עליו "מילה", הבלש קופץ מאחורי הלוח, אותיות מרחפות
/// בעומקים שונים ברקע, ופס טעינה אמיתי (מילון + פרופיל) עם טיפים.
///
/// לפי עקרונות מסכי פתיחה טובים: קצר (~2.6 שניות), מותג ברור, פס התקדמות
/// במקום ספינר, ומעבר ישיר למסך הבא ברגע שהכול מוכן (או בלחיצה).
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> with TickerProviderStateMixin {
  /// ציר הזמן החד-פעמי של הפתיחה (נחיתת האריחים, איות המילה, הבלש).
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );

  /// תנועה מתמשכת (נדנוד הלוח, אותיות הרקע, הברק בכותרת).
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 12));

  double _progress = 0.05;
  int _tipIndex = 0;
  Timer? _tipTimer;
  String? _destination;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _intro.forward();
    _tipTimer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _prepare());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!_ambient.isAnimating) _ambient.repeat();
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    _tipTimer?.cancel();
    super.dispose();
  }

  Future<void> _prepare() async {
    await ref.read(dictionaryLoadProvider.future);
    if (mounted) setState(() => _progress = 0.7);
    final profile = await ref.read(playerProfileProvider.notifier).ensureLoaded();
    if (!mounted) return;
    setState(() => _progress = 1);

    // כניסה ראשונית: קודם מסך התחברות, אחר כך הדרכה, ואז התפריט הראשי.
    _destination = !profile.authIntroShown
        ? '/auth?initial=true'
        : (profile.onboardingCompleted ? '/home' : '/onboarding');

    // נותנים לאנימציית הפתיחה להסתיים (היא קצרה), ואז ממשיכים.
    if (_intro.isAnimating) await _intro.forward().orCancel.catchError((_) {});
    await Future.delayed(const Duration(milliseconds: 250));
    _go();
  }

  void _go() {
    final dest = _destination;
    if (dest == null || _navigated || !mounted) return;
    _navigated = true;
    context.go(dest);
  }

  @override
  Widget build(BuildContext context) {
    return TopBarTint(
      color: kSplashGradient.first,
      child: Scaffold(
        backgroundColor: kSplashGradient.last,
        body: GestureDetector(
          behavior: HitTestBehavior.opaque,
          // לחיצה מדלגת על האנימציה - ברגע שהטעינה הסתיימה.
          onTap: _go,
          child: AnimatedBuilder(
            animation: Listenable.merge([_intro, _ambient]),
            builder: (context, _) {
              final t = _intro.value;
              final a = _ambient.value;
              return Stack(
                fit: StackFit.expand,
                children: [
                  _AnimatedGradient(phase: a),
                  _FloatingLetters(phase: a),
                  SafeArea(
                    child: Column(
                      children: [
                        const Spacer(flex: 3),
                        SizedBox(height: 330, child: _HeroBoard(t: t, ambient: a)),
                        const SizedBox(height: 8),
                        _Title(t: t, ambient: a),
                        const Spacer(flex: 2),
                        _LoadingBar(progress: _progress, tip: _tips[_tipIndex], t: t),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// ערך 0..1 של קטע מתוך ציר הזמן [t] בין [start] ל-[end], עם עקומה.
double _seg(double t, double start, double end, [Curve curve = Curves.linear]) {
  if (t <= start) return 0;
  if (t >= end) return 1;
  return curve.transform((t - start) / (end - start));
}

class _AnimatedGradient extends StatelessWidget {
  final double phase;
  const _AnimatedGradient({required this.phase});

  @override
  Widget build(BuildContext context) {
    final angle = phase * 2 * math.pi;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(math.sin(angle) * 0.6, -1),
          end: Alignment(-math.sin(angle) * 0.6, 1),
          colors: kSplashGradient,
        ),
      ),
      child: DecoratedBox(
        // הילה רכה במרכז, מאחורי הלוח.
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.15),
            radius: 0.75,
            colors: [Colors.white.withValues(alpha: 0.28), Colors.white.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}

/// אותיות עבריות מרחפות למעלה בשלוש שכבות עומק (קטנות ושקופות = רחוקות).
class _FloatingLetters extends StatelessWidget {
  final double phase;
  const _FloatingLetters({required this.phase});

  static final _items = List.generate(16, (i) {
    final r = math.Random(i * 7919 + 3);
    return (
      letter: 'אבגדהוזחטיכלמנסעפצקרשת'[r.nextInt(22)],
      x: r.nextDouble(),
      y: r.nextDouble(),
      depth: 0.35 + r.nextDouble() * 0.65,
      spin: (r.nextDouble() - 0.5) * 2,
    );
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return IgnorePointer(
      child: Stack(
        children: [
          for (final item in _items)
            Builder(
              builder: (context) {
                // רחוקות זזות לאט יותר (פרלקסה).
                final y = (item.y - phase * (0.35 + item.depth * 0.5)) % 1.0;
                final tileSize = 26 + 34 * item.depth;
                return Positioned(
                  left: item.x * (size.width - tileSize),
                  top: y * (size.height + tileSize) - tileSize,
                  child: Opacity(
                    opacity: 0.08 + 0.2 * item.depth,
                    child: Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.002)
                        ..rotateX(phase * 2 * math.pi * item.spin)
                        ..rotateY(phase * 2 * math.pi * item.spin * 0.7),
                      child: Container(
                        width: tileSize,
                        height: tileSize,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(tileSize * 0.3),
                        ),
                        child: Text(
                          item.letter,
                          style: TextStyle(
                            fontSize: tileSize * 0.55,
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFFE23B4E),
                            height: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

/// הלוח התלת-ממדי: מוטה לאחור עם פרספקטיבה, האריחים נוחתים בזה אחר זה,
/// ואז קו זוהר מאיית "מילה" והבלש קופץ מאחוריו.
class _HeroBoard extends StatelessWidget {
  final double t;
  final double ambient;
  const _HeroBoard({required this.t, required this.ambient});

  @override
  Widget build(BuildContext context) {
    const cell = 76.0;
    const boardSize = cell * 3;
    final sway = math.sin(ambient * 2 * math.pi) * 0.12;
    // הלוח "נכנס" מוטה חזק ומתיישר לזווית נוחה.
    final tilt = 0.95 - 0.4 * _seg(t, 0, 0.45, Curves.easeOutCubic);
    final pathProgress = _seg(t, 0.42, 0.78, Curves.easeInOut) * _path.length;
    final mascotIn = _seg(t, 0.62, 0.9, Curves.elasticOut);

    return Center(
      child: SizedBox(
        width: boardSize + 60,
        height: 330,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            // הבלש מציץ מאחורי הלוח.
            Positioned(
              top: 0,
              child: Opacity(
                opacity: mascotIn.clamp(0.0, 1.0),
                child: Transform.translate(
                  offset: Offset(0, 70 * (1 - mascotIn)),
                  child: Transform.rotate(
                    angle: math.sin(ambient * 4 * math.pi) * 0.05,
                    child: Image.asset('assets/avatar/detective_celebrate.png', height: 132),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()
                  ..setEntry(3, 2, 0.0014)
                  ..rotateX(tilt)
                  ..rotateZ(sway * 0.35)
                  ..rotateY(sway),
                child: Container(
                  width: boardSize + 24,
                  height: boardSize + 24,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF5B1C6B).withValues(alpha: 0.35),
                        blurRadius: 30,
                        offset: const Offset(0, 22),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _PathPainter(progress: pathProgress, cell: cell)),
                      ),
                      for (int r = 0; r < 3; r++)
                        for (int c = 0; c < 3; c++) _tile(r, c, cell, pathProgress),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tile(int r, int c, double cell, double pathProgress) {
    final order = r * 3 + c;
    final drop = _seg(t, 0.02 + order * 0.035, 0.22 + order * 0.035, Curves.bounceOut);
    final pathIndex = _path.indexOf((r, c));
    final lit = pathIndex >= 0 && pathProgress > pathIndex;
    final pop = pathIndex >= 0 ? _seg(pathProgress, pathIndex.toDouble(), pathIndex + 0.6, Curves.elasticOut) : 0.0;
    return Positioned(
      left: (2 - c) * cell, // RTL: העמודה הראשונה מימין
      top: r * cell,
      width: cell,
      height: cell,
      child: Opacity(
        opacity: drop.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -160 * (1 - drop)),
          child: Center(
            child: Transform.scale(
              scale: 1 + 0.12 * pop * (lit ? 1 : 0),
              child: LetterTile(
                letter: _board[r][c],
                size: cell * 0.84,
                state: lit ? TileVisualState.selected : TileVisualState.idle,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// הקו הזוהר שמחבר את אותיות המילה (מצויר מתחת לאריחים).
class _PathPainter extends CustomPainter {
  final double progress;
  final double cell;
  _PathPainter({required this.progress, required this.cell});

  Offset _center((int, int) p) => Offset((2 - p.$2) * cell + cell / 2, p.$1 * cell + cell / 2);

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.05) return;
    final path = Path()..moveTo(_center(_path[0]).dx, _center(_path[0]).dy);
    final full = progress.clamp(0.0, _path.length - 1.0);
    for (int i = 1; i <= full.floor(); i++) {
      final p = _center(_path[i]);
      path.lineTo(p.dx, p.dy);
    }
    final frac = full - full.floor();
    if (frac > 0 && full.floor() + 1 < _path.length) {
      final a = _center(_path[full.floor()]);
      final b = _center(_path[full.floor() + 1]);
      final p = Offset.lerp(a, b, frac)!;
      path.lineTo(p.dx, p.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFFFFE27A).withValues(alpha: 0.55)
        ..strokeWidth = 22
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.white
        ..strokeWidth = 10
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant _PathPainter old) => old.progress != progress || old.cell != cell;
}

class _Title extends StatelessWidget {
  final double t;
  final double ambient;
  const _Title({required this.t, required this.ambient});

  @override
  Widget build(BuildContext context) {
    final appear = _seg(t, 0.3, 0.65, Curves.elasticOut);
    // ברק שעובר על הכותרת כל כמה שניות.
    final shine = (ambient * 3) % 1.0;
    return Opacity(
      opacity: _seg(t, 0.3, 0.45).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.6 + 0.4 * appear,
        child: Column(
          children: [
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (rect) => LinearGradient(
                begin: Alignment(-1.6 + shine * 3.2, -0.4),
                end: Alignment(-1.0 + shine * 3.2, 0.4),
                colors: [Colors.white.withValues(alpha: 0), Colors.white.withValues(alpha: 0.85), Colors.white.withValues(alpha: 0)],
              ).createShader(rect),
              child: Text(
                'מצא ת׳מילה',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 46,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  shadows: [
                    Shadow(color: const Color(0xFFB4321F).withValues(alpha: 0.9), offset: const Offset(0, 5)),
                    Shadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'משחקו של רוני מיכאלי',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadingBar extends StatelessWidget {
  final double progress;
  final String tip;
  final double t;
  const _LoadingBar({required this.progress, required this.tip, required this.t});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: _seg(t, 0.15, 0.35).clamp(0.0, 1.0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 48),
        child: Column(
          children: [
            Container(
              height: 16,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1.5),
              ),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (context, v, _) => Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FractionallySizedBox(
                    widthFactor: v.clamp(0.02, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFFB700)]),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(begin: const Offset(0, 0.3), end: Offset.zero).animate(anim),
                  child: child,
                ),
              ),
              child: Text(
                '💡 $tip',
                key: ValueKey(tip),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.95), fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
