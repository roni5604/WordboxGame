import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';

/// פס טיימר מתרוקן + שעון ספרות ברור (אם [secondsLeft] מועבר), בהשראת
/// פס הזמן שמופיע בתחתית מסך Wordbox המקורי. משנה צבע לאדום כשנשארו
/// פחות מ-20% מהזמן, כדי ליצור תחושת דחיפות - ואז השעון גם "פועם" בכל
/// שנייה שלמה (אפקט "טיק" ויזואלי, בנוסף לצליל האזהרה).
class TimerBar extends StatelessWidget {
  final double progress; // 0..1
  final bool urgent;

  /// שניות שנותרו - אופציונלי. אם null, מוצג רק הפס בלי מספר (למשל
  /// כשמקום המסך מוגבל, כמו במסך התחרות).
  final int? secondsLeft;

  const TimerBar({super.key, required this.progress, this.urgent = false, this.secondsLeft});

  String _label(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return m > 0 ? '$m:${s.toString().padLeft(2, '0')}' : '$s';
  }

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.error : AppColors.success;

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 14,
        color: Colors.white.withValues(alpha: 0.35),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Align(
              alignment: Alignment.centerRight,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: constraints.maxWidth * progress.clamp(0.0, 1.0),
                color: color,
              ),
            );
          },
        ),
      ),
    );

    final seconds = secondsLeft;
    if (seconds == null) return bar;

    final clock = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_rounded, size: 18, color: urgent ? AppColors.error : Colors.white),
        const SizedBox(width: 4),
        Text(
          _label(seconds),
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 15,
            color: urgent ? AppColors.error : Colors.white,
          ),
        ),
      ],
    );

    return Row(
      children: [
        SizedBox(
          width: 58,
          // מפתח שמשתנה בכל שנייה שלמה (רק כשדחוף) - כך flutter_animate
          // "מריץ" מחדש את אנימציית הפעימה בכל טיק, ליצירת תחושת שעון
          // חי שסופר בפועל, לא רק פס שמתרוקן בשקט.
          child: clock
              .animate(key: ValueKey(urgent ? seconds : -1))
              .scaleXY(
                begin: 1.0,
                end: urgent ? 1.28 : 1.0,
                duration: 150.ms,
                curve: Curves.easeOut,
              )
              .then()
              .scaleXY(end: 1.0, duration: 150.ms),
        ),
        const SizedBox(width: 8),
        Expanded(child: bar),
      ],
    );
  }
}
