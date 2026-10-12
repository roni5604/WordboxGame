import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/motion.dart';
import '../../core/ui/rarity_style.dart';
import '../../game_engine/rewards/rarity.dart';

/// פס אור שעובר על הילד מצד לצד (ShinyText של React Bits) - לטקסט/תגיות
/// של פרסים נדירים. נעצר במצב "הפחתת תנועה".
class ShineSweep extends StatefulWidget {
  final Widget child;
  final Duration period;
  final double opacity;

  const ShineSweep({super.key, required this.child, this.period = const Duration(milliseconds: 2200), this.opacity = 0.75});

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.period);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (Motion.reduced(context)) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
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
      child: widget.child,
      builder: (context, child) {
        // הפס עובר ב-60% הראשונים של המחזור ואז "נח".
        final t = (_c.value / 0.6).clamp(0.0, 1.0);
        final x = -1.5 + 3 * Motion.inOut.transform(t);
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - 0.35, -0.4),
            end: Alignment(x + 0.35, 0.4),
            colors: [
              Colors.white.withValues(alpha: 0),
              Colors.white.withValues(alpha: widget.opacity),
              Colors.white.withValues(alpha: 0),
            ],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// תגית הדרגה ("נדיר!", "אגדי!") - גרדיאנט בצבע הדרגה, זוהר, וברק עובר.
class RarityBadge extends StatelessWidget {
  final Rarity rarity;
  final double fontSize;
  final bool exclaim;

  const RarityBadge({super.key, required this.rarity, this.fontSize = 18, this.exclaim = true});

  @override
  Widget build(BuildContext context) {
    final s = RarityStyle.of(rarity);
    final badge = Container(
      padding: EdgeInsets.symmetric(horizontal: fontSize * 0.9, vertical: fontSize * 0.28),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [s.light, s.base, s.dark], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(fontSize * 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.85), width: 2),
        boxShadow: [
          BoxShadow(color: s.glow.withValues(alpha: 0.4 + 0.5 * s.intensity), blurRadius: 10 + 18 * s.intensity),
          BoxShadow(color: s.dark.withValues(alpha: 0.6), offset: const Offset(0, 3)),
        ],
      ),
      child: Text(
        exclaim && rarity != Rarity.common ? '${rarity.label}!' : rarity.label,
        style: TextStyle(
          color: Colors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
          shadows: [Shadow(color: s.dark, offset: const Offset(0, 2), blurRadius: 2)],
        ),
      ),
    );
    if (rarity.index < Rarity.rare.index) return badge;
    return ShineSweep(period: Duration(milliseconds: rarity == Rarity.legendary ? 1500 : 2400), child: badge);
  }
}

/// מספר ש"סופר" מ-0 (או [from]) לערך הסופי (CountUp של React Bits), עם
/// "קפיצה" קטנה בסוף - הספירה עצמה היא חלק מתחושת הזכייה.
class CountUpText extends StatelessWidget {
  final int value;
  final int from;
  final Duration duration;
  final Duration delay;
  final TextStyle style;
  final String prefix;
  final String suffix;

  const CountUpText({
    super.key,
    required this.value,
    required this.style,
    this.from = 0,
    this.duration = const Duration(milliseconds: 900),
    this.delay = Duration.zero,
    this.prefix = '',
    this.suffix = '',
  });

  @override
  Widget build(BuildContext context) {
    if (Motion.reduced(context)) return Text('$prefix$value$suffix', style: style);
    return Text('$prefix$from$suffix', style: style)
        .animate(delay: delay)
        .custom(
          duration: duration,
          curve: Motion.out,
          builder: (context, t, _) => Text('$prefix${(from + (value - from) * t).round()}$suffix', style: style),
        )
        .then()
        .scaleXY(end: 1.12, duration: 90.ms, curve: Motion.out)
        .then()
        .scaleXY(end: 1 / 1.12, duration: 220.ms, curve: Motion.backOut);
  }
}
