import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/motion/motion.dart';
import '../../../core/ui/candy_button.dart';
import '../../../core/ui/rarity_style.dart';
import '../../../game_engine/rewards/reward_tables.dart';
import '../../../providers/sound_provider.dart';
import '../../rewards/reward_reveal.dart';
import '../../rewards/reward_widgets.dart';

/// "גלגל המזל" - נפתח פעם אחת בסיום כל עולם (שלב פינאלה).
///
/// התוצאה מוגרלת מראש (ראו [RewardTables.rollWheelPrize]); הגלגל מסתובב
/// בדיוק אליה. כל מקטע צבוע בצבע הדרגה שלו, המחוג "מקפץ" ומתקתק בכל מעבר
/// מקטע (צליל + רטט), והגלגל מאט לאט - המתח נבנה עד העצירה. אפשר לסובב
/// בכפתור או בהחלקה על הגלגל. אחרי העצירה נפתח מסך הפרס הרגיל, עם חגיגה
/// לפי הדרגה של המקטע.
class FortuneWheelDialog extends ConsumerStatefulWidget {
  final int prizeIndex;
  final FortuneWheelPrize prize;

  const FortuneWheelDialog({super.key, required this.prizeIndex, required this.prize});

  static Future<void> show(BuildContext context, {required int prizeIndex, required FortuneWheelPrize prize}) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'גלגל המזל',
      barrierColor: const Color(0xD9100822),
      transitionDuration: Motion.standard,
      transitionBuilder: (context, a, _, child) => FadeTransition(
        opacity: CurvedAnimation(parent: a, curve: Motion.out),
        child: ScaleTransition(scale: Tween(begin: 0.94, end: 1.0).animate(CurvedAnimation(parent: a, curve: Motion.out)), child: child),
      ),
      pageBuilder: (context, _, _) => FortuneWheelDialog(prizeIndex: prizeIndex, prize: prize),
    );
  }

  @override
  ConsumerState<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends ConsumerState<FortuneWheelDialog> with TickerProviderStateMixin {
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 5600));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();
  late final AnimationController _kick = AnimationController(vsync: this, duration: const Duration(milliseconds: 260));
  late final AnimationController _win = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final Animation<double> _rotation;
  late final double _target;
  bool _spinning = false;
  int _lastSegment = -1;

  /// האטה ארוכה במיוחד (easeOutQuart) - רוב הזמן הגלגל "כמעט עוצר".
  static const _spinCurve = Cubic(0.165, 0.84, 0.44, 1);

  @override
  void initState() {
    super.initState();
    _target = _targetRotation();
    _rotation = Tween<double>(begin: 0, end: _target).animate(CurvedAnimation(parent: _spin, curve: _spinCurve));
    _spin.addListener(_onSpinTick);
    _spin.addStatusListener((status) {
      if (status == AnimationStatus.completed) _onLanded();
    });
  }

  @override
  void dispose() {
    for (final c in [_spin, _ambient, _kick, _win]) {
      c.dispose();
    }
    super.dispose();
  }

  static List<double> _segmentStarts() {
    final prizes = RewardTables.wheelPrizes;
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);
    final starts = <double>[];
    var acc = 0;
    for (final p in prizes) {
      starts.add(acc / total * 2 * pi);
      acc += p.weight;
    }
    return starts;
  }

  double _targetRotation() {
    final prizes = RewardTables.wheelPrizes;
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);
    final segStart = _segmentStarts()[widget.prizeIndex];
    final segSweep = prizes[widget.prizeIndex].weight / total * 2 * pi;
    // נוחתים קצת לצד מתוך המקטע (לא בדיוק באמצע) - מרגיש פחות "מבוים".
    final jitter = (Random().nextDouble() - 0.5) * segSweep * 0.5;
    final centerAngle = segStart + segSweep / 2 + jitter;
    var base = (-centerAngle) % (2 * pi);
    if (base < 0) base += 2 * pi;
    const extraTurns = 7;
    return base + extraTurns * 2 * pi;
  }

  /// איזה מקטע נמצא כרגע מתחת למחוג (למעלה).
  int _segmentAt(double rotation) {
    final starts = _segmentStarts();
    var a = (-rotation) % (2 * pi);
    if (a < 0) a += 2 * pi;
    for (var i = starts.length - 1; i >= 0; i--) {
      if (a >= starts[i]) return i;
    }
    return 0;
  }

  void _onSpinTick() {
    final seg = _segmentAt(_rotation.value);
    if (seg != _lastSegment) {
      _lastSegment = seg;
      if (_spin.value > 0.02) {
        ref.read(soundServiceProvider).playWheelTick();
        Haptics.selection();
        _kick.forward(from: 0);
      }
    }
  }

  void _start() {
    if (_spinning) return;
    setState(() => _spinning = true);
    Haptics.medium();
    _lastSegment = _segmentAt(0);
    _spin.forward();
  }

  Future<void> _onLanded() async {
    Haptics.heavy();
    _win.repeat(reverse: true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    _win.stop();
    await RewardReveal.show(context, RewardContents.fromWheel(widget.prize), charge: false);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.sizeOf(context);
    final size = min(mq.width * 0.84, min(360.0, mq.height * 0.48));
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 2),
              const Text(
                'עולם חדש נפתח!',
                style: TextStyle(color: Colors.white70, fontSize: 16, fontWeight: FontWeight.w800),
              ).animate().fadeIn(duration: Motion.standard),
              const SizedBox(height: 4),
              ShineSweep(
                child: const Text(
                  'גלגל המזל',
                  style: TextStyle(
                    color: Color(0xFFFFE066),
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Color(0xFFD9690B), offset: Offset(0, 3)), Shadow(color: Colors.black54, blurRadius: 12)],
                  ),
                ),
              ).animate().scaleXY(begin: 0.8, curve: Motion.pop, duration: 520.ms).fadeIn(),
              const Spacer(),
              GestureDetector(
                // החלקה על הגלגל = סיבוב, כמו גלגל אמיתי.
                onPanEnd: (d) {
                  if (d.velocity.pixelsPerSecond.distance > 250) _start();
                },
                onTap: _start,
                child: SizedBox(
                  width: size,
                  height: size + 18,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_spin, _ambient, _kick, _win]),
                    builder: (context, _) {
                      final kick = sin(_kick.value * pi) * (1 - _kick.value);
                      return Stack(
                        alignment: Alignment.topCenter,
                        clipBehavior: Clip.none,
                        children: [
                          Positioned(
                            top: 18,
                            child: Transform.rotate(
                              angle: _rotation.value,
                              child: CustomPaint(
                                size: Size.square(size),
                                painter: _WheelPainter(
                                  prizes: RewardTables.wheelPrizes,
                                  starts: _segmentStarts(),
                                  winner: _spin.isCompleted ? widget.prizeIndex : -1,
                                  winPulse: _win.value,
                                  // Painter לא יורש את הגופן של האפליקציה - מעבירים אותו במפורש.
                                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                ),
                              ),
                            ),
                          ),
                          // הטבעת עם הנורות לא מסתובבת - רק מהבהבת.
                          Positioned(
                            top: 18,
                            child: IgnorePointer(
                              child: CustomPaint(size: Size.square(size), painter: _RimPainter(blink: _ambient.value, fast: _spinning && !_spin.isCompleted)),
                            ),
                          ),
                          // המחוג - "נבעט" הצידה בכל מעבר מקטע.
                          Positioned(
                            top: 0,
                            child: Transform.rotate(
                              angle: -0.45 * kick,
                              alignment: const Alignment(0, -0.6),
                              child: const CustomPaint(size: Size(46, 58), painter: _PointerPainter()),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ).animate().scaleXY(begin: 0.85, curve: Motion.backOut, duration: 600.ms).fadeIn(duration: 250.ms),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: AnimatedSwitcher(
                  duration: Motion.standard,
                  child: _spinning
                      ? const SizedBox(height: 70, key: ValueKey('spinning'))
                      : CandyButton(
                          key: const ValueKey('spin'),
                          label: 'סובבו!',
                          icon: Icons.casino_rounded,
                          palette: CandyPalette.gold,
                          height: 64,
                          fontSize: 24,
                          onPressed: _start,
                        )
                          .animate(onPlay: (c) => c.repeat(reverse: true))
                          .scaleXY(end: 1.05, duration: 700.ms, curve: Curves.easeInOut),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _spinning ? 'בהצלחה...' : 'או החליקו על הגלגל',
                style: const TextStyle(color: Colors.white60, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<FortuneWheelPrize> prizes;
  final List<double> starts;
  final int winner;
  final double winPulse;
  final String? fontFamily;

  _WheelPainter({
    required this.prizes,
    required this.starts,
    required this.winner,
    required this.winPulse,
    this.fontFamily,
  });

  static IconData _iconFor(FortuneWheelPrize p) {
    if (p.rarity == Rarity.legendary) return Icons.workspace_premium_rounded;
    if (p.doubleCoinsLevels > 0) return Icons.bolt_rounded;
    if (p.hints > 0) return Icons.lightbulb_rounded;
    return Icons.monetization_on_rounded;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final radius = size.width / 2 * 0.9;
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);

    for (var i = 0; i < prizes.length; i++) {
      final s = RarityStyle.of(prizes[i].rarity);
      final sweep = prizes[i].weight / total * 2 * pi;
      final start = starts[i] - pi / 2;
      final rect = Rect.fromCircle(center: c, radius: radius);
      final isWin = i == winner;
      final paint = Paint()
        ..shader = ui.Gradient.radial(c, radius, [
          Color.lerp(s.light, Colors.white, isWin ? 0.4 * winPulse : 0)!,
          s.base,
          s.dark,
        ], [0, 0.55, 1]);
      canvas.drawArc(rect, start, sweep, true, paint);
      // קו מפריד לבן
      canvas.drawLine(
        c,
        Offset(c.dx + radius * cos(start), c.dy + radius * sin(start)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..strokeWidth = 3,
      );

      // אייקון + כיתוב לאורך הרדיוס
      final mid = start + sweep / 2;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(mid);
      final icon = _iconFor(prizes[i]);
      final iconSize = sweep < 0.3 ? 18.0 : 24.0;
      final ip = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            fontSize: iconSize,
            color: Colors.white,
            shadows: [Shadow(color: s.dark, offset: const Offset(0, 1.5))],
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      canvas.save();
      canvas.translate(radius * 0.8, 0);
      canvas.rotate(pi / 2);
      ip.paint(canvas, Offset(-ip.width / 2, -ip.height / 2));
      canvas.restore();
      if (sweep > 0.3) {
        final tp = TextPainter(
          text: TextSpan(
            text: prizes[i].label,
            style: TextStyle(
              fontFamily: fontFamily,
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: s.dark, offset: const Offset(0, 1.5))],
            ),
          ),
          textDirection: TextDirection.rtl,
          maxLines: 1,
        )..layout(maxWidth: radius * 0.52);
        canvas.save();
        canvas.translate(radius * 0.42, 0);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
      }
      canvas.restore();
    }

    // הילת "זכייה" סביב המקטע המנצח
    if (winner >= 0) {
      final sweep = prizes[winner].weight / total * 2 * pi;
      canvas.drawArc(
        Rect.fromCircle(center: c, radius: radius - 4),
        starts[winner] - pi / 2,
        sweep,
        true,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..color = Colors.white.withValues(alpha: 0.5 + 0.5 * winPulse),
      );
    }

    // רכזת מרכזית
    canvas.drawCircle(c, radius * 0.17, Paint()..color = const Color(0x55000000));
    canvas.drawCircle(
      c,
      radius * 0.15,
      Paint()..shader = ui.Gradient.radial(c.translate(-4, -6), radius * 0.18, [const Color(0xFFFFF4B5), const Color(0xFFFFB800), const Color(0xFFD9690B)], [0, 0.6, 1]),
    );
    final star = Icons.star_rounded;
    final sp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(star.codePoint),
        style: TextStyle(fontFamily: star.fontFamily, package: star.fontPackage, fontSize: radius * 0.18, color: Colors.white),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sp.paint(canvas, c - Offset(sp.width / 2, sp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _WheelPainter old) => old.winner != winner || old.winPulse != winPulse;
}

/// טבעת חיצונית כהה עם נורות שמהבהבות (מהר יותר בזמן סיבוב).
class _RimPainter extends CustomPainter {
  final double blink;
  final bool fast;

  _RimPainter({required this.blink, required this.fast});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final outer = size.width / 2;
    final ringWidth = outer * 0.1;
    canvas.drawCircle(
      c,
      outer - ringWidth / 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = ringWidth
        ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [const Color(0xFF6A16C9), const Color(0xFF2B1260)]),
    );
    canvas.drawCircle(
      c,
      outer - ringWidth,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = const Color(0xFFFFE066),
    );
    const bulbs = 20;
    final phase = ((fast ? blink * 6 : blink * 2) % 1.0) < 0.5;
    for (var i = 0; i < bulbs; i++) {
      final a = i / bulbs * 2 * pi;
      final p = Offset(c.dx + (outer - ringWidth / 2) * cos(a), c.dy + (outer - ringWidth / 2) * sin(a));
      final on = (i.isEven) == phase;
      if (on) {
        canvas.drawCircle(p, ringWidth * 0.55, Paint()..color = const Color(0x66FFE066));
      }
      canvas.drawCircle(p, ringWidth * 0.26, Paint()..color = on ? const Color(0xFFFFF4B5) : const Color(0xFFB98A2E));
    }
  }

  @override
  bool shouldRepaint(covariant _RimPainter old) => old.blink != blink || old.fast != fast;
}

class _PointerPainter extends CustomPainter {
  const _PointerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, h)
      ..quadraticBezierTo(w * 0.05, h * 0.42, w * 0.18, h * 0.22)
      ..arcToPoint(Offset(w * 0.82, h * 0.22), radius: Radius.circular(w * 0.36))
      ..quadraticBezierTo(w * 0.95, h * 0.42, w / 2, h)
      ..close();
    canvas.drawShadow(path, Colors.black, 4, false);
    canvas.drawPath(
      path,
      Paint()..shader = ui.Gradient.linear(Offset.zero, Offset(0, h), [const Color(0xFFFF6B6B), const Color(0xFFC21D3A)]),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Colors.white,
    );
    canvas.drawCircle(Offset(w / 2, h * 0.3), w * 0.12, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
