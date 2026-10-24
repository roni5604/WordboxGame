import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/ui/game_backdrop.dart';
import 'letter_tile.dart';

/// "המילה הסודית" שנחשפה ב"גלה מילה": כרטיס זוהר מעל הלוח עם אותיות המילה
/// באריחים קטנים (כמו על הלוח), שמרחף בעדינות עד שהשחקן/ית מוצא/ת אותה.
/// כשנמצאה - [found] הופך ל-true: האותיות קופצות, הכרטיס נצבע ירוק,
/// "יופי! מצאת" - ונעלם. לא חוסם נגיעות בלוח.
class SecretWordCard extends StatefulWidget {
  final String displayWord;
  final bool found;

  const SecretWordCard({super.key, required this.displayWord, required this.found});

  @override
  State<SecretWordCard> createState() => _SecretWordCardState();
}

class _SecretWordCardState extends State<SecretWordCard> with SingleTickerProviderStateMixin {
  late final AnimationController _float = AnimationController(vsync: this, duration: const Duration(seconds: 3));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!_float.isAnimating) _float.repeat();
    } else {
      _float.stop();
    }
  }

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final found = widget.found;
    final letters = widget.displayWord.split('');
    final colors = found ? const [Color(0xFF5BE3B0), Color(0xFF1FB86A)] : const [Color(0xFF8E5CFF), Color(0xFF5B2BD6)];
    final card = AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.fromLTRB(12, 7, 12, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(found ? Icons.check_circle_rounded : Icons.search_rounded, color: Colors.white, size: 22),
          const SizedBox(width: 6),
          Text(
            found ? 'יופי! מצאת' : 'חפשו על הלוח:',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
          ),
          const SizedBox(width: 8),
          for (var i = 0; i < letters.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: found
                  ? LetterTile(letter: letters[i], size: 30, state: TileVisualState.success)
                        .animate()
                        .moveY(begin: 0, end: -10, delay: (i * 60).ms, duration: 160.ms, curve: Curves.easeOut)
                        .then()
                        .moveY(end: 10, duration: 220.ms, curve: Curves.bounceOut)
                  : LetterTile(letter: letters[i], size: 30, state: TileVisualState.hint),
            ),
        ],
      ),
    );
    // מילה ארוכה (עד 9+ אותיות בלוח 6×6) מתכווצת כדי להיכנס לרוחב המסך.
    final fitted = FittedBox(fit: BoxFit.scaleDown, child: card);
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _float,
        builder: (context, child) {
          final t = _float.value * math.pi * 2;
          return Transform.translate(
            offset: Offset(0, found ? 0 : math.sin(t) * 3),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.002)
                ..rotateX(found ? 0 : math.sin(t) * 0.06),
              child: child,
            ),
          );
        },
        child: fitted,
      ),
    );
  }
}
