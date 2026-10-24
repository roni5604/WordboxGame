import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/game_backdrop.dart';

/// אבני הבניין של החנות: צבעים, תמונות התלת-ממד, כרטיס שנוטה לכיוון האצבע,
/// ברק שעובר על הצעה מומלצת, תגיות וכפתורי מחיר.

class StorePalette {
  StorePalette._();

  static const Color vaultTop = Color(0xFF1E0A4A);
  static const Color vaultMid = Color(0xFF4A1A9C);
  static const Color vaultBottom = Color(0xFF7B2CBF);
  static const Color card = Color(0xFFFFFFFF);
  static const Color cardTint = Color(0xFFF6F0FF);
  static const Color gold = Color(0xFFFFC93C);
  static const Color goldDeep = Color(0xFFFF9F1C);
  static const Color ink = AppColors.textDark;
  static const Color muted = Color(0xFF7A7090);
  static const Color mint = Color(0xFF2EE59D);
  static const Color pink = Color(0xFFFF4F8B);
}

/// תמונות המוצרים שנוצרו ב-Blender (tool/store_art/render_store_art.py).
class StoreArt {
  StoreArt._();

  static const String hint1 = 'assets/store/hint_1.png';
  static const String hint5 = 'assets/store/hint_5.png';
  static const String hint12 = 'assets/store/hint_12.png';
  static const String coinsSmall = 'assets/store/coins_small.png';
  static const String coinsMedium = 'assets/store/coins_medium.png';
  static const String coinsLarge = 'assets/store/coins_large.png';
  static const String gift = 'assets/store/gift.png';
}

/// תמונת מוצר שמרחפת לאט מעל הילה רכה. [phase] מזיז את המחזור כדי
/// שכרטיסים סמוכים לא יזוזו יחד.
class FloatingArt extends StatefulWidget {
  final String asset;
  final double size;
  final Color glow;
  final double phase;
  final double amplitude;

  const FloatingArt({
    super.key,
    required this.asset,
    required this.size,
    this.glow = StorePalette.gold,
    this.phase = 0,
    this.amplitude = 5,
  });

  @override
  State<FloatingArt> createState() => _FloatingArtState();
}

class _FloatingArtState extends State<FloatingArt> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
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
    final size = widget.size;
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = (_c.value + widget.phase) * math.pi * 2;
          final dy = math.sin(t) * widget.amplitude;
          final glow = 0.55 + 0.15 * math.sin(t);
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: size * 0.82,
                height: size * 0.82,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.glow.withValues(alpha: glow),
                      widget.glow.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
              Transform.translate(
                offset: Offset(0, dy),
                child: Transform.rotate(angle: math.sin(t * 0.5) * 0.03, child: child),
              ),
            ],
          );
        },
        child: Image.asset(widget.asset, width: size, height: size, filterQuality: FilterQuality.medium),
      ),
    );
  }
}

/// כרטיס שנוטה בתלת-ממד לכיוון האצבע ומתכווץ מעט בלחיצה, כמו קלף אמיתי.
class TiltCard extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double maxTilt;

  const TiltCard({super.key, required this.child, this.onTap, this.maxTilt = 0.16});

  @override
  State<TiltCard> createState() => _TiltCardState();
}

class _TiltCardState extends State<TiltCard> {
  Offset _tilt = Offset.zero;
  bool _pressed = false;

  void _track(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    final dx = (local.dx / size.width - 0.5) * 2;
    final dy = (local.dy / size.height - 0.5) * 2;
    setState(() => _tilt = Offset(dx.clamp(-1.0, 1.0), dy.clamp(-1.0, 1.0)));
  }

  void _release() => setState(() {
    _tilt = Offset.zero;
    _pressed = false;
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (d) {
        _pressed = true;
        _track(d.localPosition);
        Haptics.selection();
      },
      onPanUpdate: (d) => _track(d.localPosition),
      onPanEnd: (_) => _release(),
      onTapCancel: _release,
      onTapUp: (_) {
        _release();
        widget.onTap?.call();
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: _tilt),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (context, tilt, child) {
          final m = Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateX(-tilt.dy * widget.maxTilt)
            ..rotateY(tilt.dx * widget.maxTilt);
          return Transform(
            alignment: Alignment.center,
            transform: m,
            child: AnimatedScale(scale: _pressed ? 0.96 : 1, duration: const Duration(milliseconds: 140), child: child),
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// פס אור אלכסוני שחולף מדי כמה שניות על הילד - "ברק" להצעה מומלצת.
class ShineSweep extends StatefulWidget {
  final Widget child;
  final BorderRadius borderRadius;

  const ShineSweep({super.key, required this.child, required this.borderRadius});

  @override
  State<ShineSweep> createState() => _ShineSweepState();
}

class _ShineSweepState extends State<ShineSweep> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3600));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
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
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: widget.borderRadius,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  // החצי הראשון של המחזור: הברק עובר. החצי השני: מנוחה.
                  final p = (_c.value * 2).clamp(0.0, 1.0);
                  if (p >= 1 || p <= 0) return const SizedBox.shrink();
                  return FractionalTranslation(
                    translation: Offset(-1.2 + p * 2.4, 0),
                    child: Transform.rotate(
                      angle: 0.35,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withValues(alpha: 0),
                              Colors.white.withValues(alpha: 0.55),
                              Colors.white.withValues(alpha: 0),
                            ],
                            stops: const [0.35, 0.5, 0.65],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// מסגרת זהב מסתובבת סביב הצעה מומלצת.
class GlowFrame extends StatefulWidget {
  final Widget child;
  final double radius;
  final bool active;
  final List<Color> colors;

  const GlowFrame({
    super.key,
    required this.child,
    this.radius = 26,
    this.active = true,
    this.colors = const [StorePalette.gold, StorePalette.pink, Color(0xFF8E7CFF), StorePalette.gold],
  });

  @override
  State<GlowFrame> createState() => _GlowFrameState();
}

class _GlowFrameState extends State<GlowFrame> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.active && AmbientMotion.enabledFor(context)) {
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
    if (!widget.active) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius + 3),
          gradient: SweepGradient(colors: widget.colors, transform: GradientRotation(_c.value * math.pi * 2)),
          boxShadow: [BoxShadow(color: StorePalette.gold.withValues(alpha: 0.45), blurRadius: 22, spreadRadius: 1)],
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// סרט בראש כרטיס ("הכי משתלם", "פופולרי").
class StoreRibbon extends StatelessWidget {
  final String text;
  final List<Color> colors;

  const StoreRibbon(this.text, {super.key, this.colors = const [StorePalette.pink, Color(0xFFFF7A45)]});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 3))],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.2),
      ),
    );
  }
}

/// מטבע קטן (זהב עם כוכב), לצד מחירים ויתרות.
class CoinGlyph extends StatelessWidget {
  final double size;

  const CoinGlyph({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFE27A), StorePalette.gold, StorePalette.goldDeep],
        ),
        border: Border.all(color: const Color(0xFFE08A00), width: size * 0.07),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 2, offset: const Offset(0, 1))],
      ),
      child: Icon(Icons.star_rounded, size: size * 0.62, color: const Color(0xFFE08A00)),
    );
  }
}

/// כפתור מחיר בסגנון ממתק: מטבעות (עם מטבע) או מחיר חנות (טקסט).
class PriceButton extends StatelessWidget {
  final String label;
  final bool coins;
  final bool enabled;
  final List<Color> colors;
  final VoidCallback? onTap;

  const PriceButton({
    super.key,
    required this.label,
    this.coins = false,
    this.enabled = true,
    this.colors = const [Color(0xFF7CEB6E), Color(0xFF33C24D)],
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = enabled ? colors : [const Color(0xFFCFC8DD), const Color(0xFFB4ABC6)];
    return Container(
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: palette),
        boxShadow: [BoxShadow(color: Color.lerp(palette.last, Colors.black, 0.35)!, offset: const Offset(0, 3))],
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (coins) ...[const CoinGlyph(size: 18), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
                shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 1), blurRadius: 1)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// כרטיס זכוכית לבן עם צל רך, הבסיס של כל ההצעות בחנות.
class StoreCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final List<Color>? gradient;

  const StoreCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 26,
    this.gradient,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: gradient ?? const [StorePalette.card, StorePalette.cardTint],
        ),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

/// רעידה קצרה (למשל כשאין מספיק מטבעות). מפעילים דרך GlobalKey.
class ShakeBox extends StatefulWidget {
  final Widget child;

  const ShakeBox({super.key, required this.child});

  @override
  State<ShakeBox> createState() => ShakeBoxState();
}

class ShakeBoxState extends State<ShakeBox> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  void shake() => _c.forward(from: 0);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) {
        final t = _c.value;
        final dx = math.sin(t * math.pi * 6) * 10 * (1 - t);
        return Transform.translate(offset: Offset(dx, 0), child: child);
      },
      child: widget.child,
    );
  }
}
