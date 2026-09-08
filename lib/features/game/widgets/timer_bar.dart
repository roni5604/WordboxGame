import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// פס טיימר מתרוקן, בהשראת פס הזמן שמופיע בתחתית מסך Wordbox המקורי.
/// משנה צבע לאדום כשנשארו פחות מ-20% מהזמן, כדי ליצור תחושת דחיפות.
class TimerBar extends StatelessWidget {
  final double progress; // 0..1
  final bool urgent;

  const TimerBar({super.key, required this.progress, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final color = urgent ? AppColors.error : AppColors.success;
    return ClipRRect(
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
  }
}
