import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/pressable.dart';
import '../../../game_engine/models/level_config.dart';
import 'explorer_critters.dart';
import 'world_theme.dart';

/// זואי הבלשית עומדת ליד השלב הבא לשחק - "אתם כאן" של המפה.
/// מרחרחת (נדנוד קל), ובנגיעה קופצת בשמחה ומחליפה לתנוחת חגיגה.
class ZoeyGuide extends StatefulWidget {
  final double height;

  const ZoeyGuide({super.key, this.height = 92});

  @override
  State<ZoeyGuide> createState() => _ZoeyGuideState();
}

class _ZoeyGuideState extends State<ZoeyGuide> with SingleTickerProviderStateMixin {
  late final AnimationController _hop = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
  bool _cheering = false;

  @override
  void dispose() {
    _hop.dispose();
    super.dispose();
  }

  void _tap() {
    Haptics.light();
    PressFeedback.trigger(haptic: false);
    setState(() => _cheering = true);
    _hop.forward(from: 0).whenComplete(() {
      if (mounted) setState(() => _cheering = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _tap,
      child: SizedBox(
        width: h * 0.9,
        height: h,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              bottom: 0,
              child: Container(
                width: h * 0.55,
                height: h * 0.12,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.all(Radius.elliptical(h * 0.3, h * 0.06)),
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _hop,
              builder: (context, child) => Transform.translate(
                offset: Offset(0, -math.sin(_hop.value * math.pi) * h * 0.28),
                child: child,
              ),
              child: Image.asset(
                _cheering ? 'assets/avatar/detective_celebrate.png' : 'assets/avatar/detective_default.png',
                height: h,
                fit: BoxFit.contain,
                gaplessPlayback: true,
              )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .rotate(begin: -0.012, end: 0.012, duration: 1300.ms, curve: Curves.easeInOut, alignment: Alignment.bottomCenter)
                  .moveY(begin: 0, end: -3, duration: 1300.ms, curve: Curves.easeInOut),
            ),
          ],
        ),
      ),
    );
  }
}

/// שלט עץ בגדה הרחוקה של הנהר - "עולם 2 · ניצנים · 4×4". נעול עד שמגיעים.
class WorldSign extends StatelessWidget {
  final WorldTier tier;
  final int worldIndex;
  final bool locked;

  const WorldSign({super.key, required this.tier, required this.worldIndex, required this.locked});

  @override
  Widget build(BuildContext context) {
    final theme = WorldTheme.of(worldIndex);
    const wood = Color(0xFFB9774A);
    const woodDark = Color(0xFF7A4B26);
    return SizedBox(
      width: 150,
      height: 118,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          // עמודים.
          for (final dx in const [-34.0, 34.0])
            Positioned(
              bottom: 0,
              left: 75 + dx - 4,
              child: Container(
                width: 8,
                height: 60,
                decoration: BoxDecoration(color: woodDark, borderRadius: BorderRadius.circular(3)),
              ),
            ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 9),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFD9955F), wood],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: woodDark, width: 2.5),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(locked ? Icons.lock_rounded : AppColors.iconForWorldIndex(worldIndex), size: 13, color: Colors.white),
                      const SizedBox(width: 4),
                      Text(
                        'עולם ${worldIndex + 1}',
                        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tier.titleHe,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Color(0x88000000), blurRadius: 3, offset: Offset(0, 1))],
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                    decoration: BoxDecoration(color: theme.accent, borderRadius: BorderRadius.circular(8)),
                    child: Text(
                      'לוח ${tier.gridSize}×${tier.gridSize}',
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// כרטיס "ברוכים הבאים לעולם" - יורד מלמעלה כשחוצים נהר לעולם חדש (וגם
/// בכניסה למפה), עם החיה החוקרת של העולם, ונעלם מעצמו. לא חוסם מגע.
class WorldTitleCard extends StatelessWidget {
  final WorldTier tier;
  final int worldIndex;
  final Animation<double> ambient;

  const WorldTitleCard({super.key, required this.tier, required this.worldIndex, required this.ambient});

  @override
  Widget build(BuildContext context) {
    final theme = WorldTheme.of(worldIndex);
    final colors = AppColors.gradientForWorldIndex(worldIndex);
    return IgnorePointer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 28),
        padding: const EdgeInsets.fromLTRB(14, 10, 18, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(color: colors.last.withValues(alpha: 0.55), blurRadius: 24, spreadRadius: 2),
            const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 6)),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 62,
              height: 62,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.8), width: 2),
              ),
              alignment: Alignment.bottomCenter,
              child: ExplorerCritter(kind: theme.explorer, ambient: ambient, size: 50, interactive: false),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'עולם ${worldIndex + 1}',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      tier.titleHe,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        shadows: [Shadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 2))],
                      ),
                    ),
                  ),
                  Text(
                    '${theme.explorerNameHe} ${theme.explorerFeminine ? 'מצטרפת' : 'מצטרף'} לחקירה',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11.5, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ],
        ),
      )
          .animate()
          .slideY(begin: -1.6, end: 0, duration: 620.ms, curve: Curves.easeOutBack)
          .fadeIn(duration: 260.ms)
          .then(delay: 1500.ms)
          .slideY(begin: 0, end: -1.6, duration: 420.ms, curve: Curves.easeInCubic)
          .fadeOut(duration: 380.ms),
    );
  }
}
