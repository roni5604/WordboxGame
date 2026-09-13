import 'dart:math';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../game_engine/rewards/reward_tables.dart';

/// דיאלוג "גלגל מזל" - נפתח פעם אחת בסיום כל שלב פינאלה (סיום עולם, ראו
/// [LevelConfig.isWorldFinale] ו-lib/features/game/level_result_screen.dart).
/// מסובב את הגלגל אוטומטית עד שהוא עוצר בדיוק על המקטע שהוגרל מראש
/// (ראו [RewardTables.rollWheelPrize]) - כדי שהתוצאה תיראה "הוגנת"
/// ומרגשת, לא רק טקסט סטטי.
class FortuneWheelDialog extends StatefulWidget {
  final int prizeIndex;
  final FortuneWheelPrize prize;

  const FortuneWheelDialog({super.key, required this.prizeIndex, required this.prize});

  static Future<void> show(
    BuildContext context, {
    required int prizeIndex,
    required FortuneWheelPrize prize,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => FortuneWheelDialog(prizeIndex: prizeIndex, prize: prize),
    );
  }

  @override
  State<FortuneWheelDialog> createState() => _FortuneWheelDialogState();
}

class _FortuneWheelDialogState extends State<FortuneWheelDialog>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _rotation;
  late final ConfettiController _confetti;
  bool _revealed = false;
  bool _spinning = false;

  static const List<Color> _segmentColors = [
    Color(0xFFFF7A45),
    Color(0xFF6A11CB),
    Color(0xFF11998E),
    Color(0xFFE0303B),
    Color(0xFFFFC93C),
    Color(0xFF2575FC),
    Color(0xFF38EF7D),
  ];

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 4));
    _rotation = Tween<double>(begin: 0, end: _targetRotation()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _revealed = true);
        _confetti.play();
      }
    });
  }

  double _targetRotation() {
    final prizes = RewardTables.wheelPrizes;
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);
    double cumulative = 0;
    for (int i = 0; i < widget.prizeIndex; i++) {
      cumulative += prizes[i].weight;
    }
    final segStart = cumulative / total * 2 * pi;
    final segSweep = prizes[widget.prizeIndex].weight / total * 2 * pi;
    final centerAngle = segStart + segSweep / 2;

    double base = (-pi / 2 - centerAngle) % (2 * pi);
    if (base < 0) base += 2 * pi;
    const extraTurns = 6;
    return base + extraTurns * 2 * pi;
  }

  void _spin() {
    if (_spinning) return;
    setState(() => _spinning = true);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.72;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Stack(
        alignment: Alignment.topCenter,
        clipBehavior: Clip.none,
        children: [
          Align(
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 40,
              gravity: 0.28,
              shouldLoop: false,
              colors: const [AppColors.star, AppColors.primary, AppColors.success, Colors.white],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF2B2440), Color(0xFF6A11CB)]),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  '🎉 עולם חדש! גלגל מזל 🎉',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    clipBehavior: Clip.none,
                    children: [
                      AnimatedBuilder(
                        animation: _rotation,
                        builder: (context, child) {
                          return Transform.rotate(angle: _rotation.value, child: child);
                        },
                        child: CustomPaint(
                          size: Size(size, size),
                          painter: _WheelPainter(
                            prizes: RewardTables.wheelPrizes,
                            colors: _segmentColors,
                          ),
                        ),
                      ),
                      const Positioned(
                        top: -6,
                        child: Icon(Icons.arrow_drop_down_rounded, size: 44, color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (!_revealed)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      onPressed: _spinning ? null : _spin,
                      child: Text(_spinning ? 'מסתובב...' : 'סובבו!'),
                    ),
                  )
                else ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'זכיתם ב-${widget.prize.resultText}! 🎊',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                  ).animate().fadeIn().scale(
                        begin: const Offset(0.7, 0.7),
                        curve: Curves.elasticOut,
                        duration: 600.ms,
                      ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: AppColors.primaryDark,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('מעולה!'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WheelPainter extends CustomPainter {
  final List<FortuneWheelPrize> prizes;
  final List<Color> colors;

  const _WheelPainter({required this.prizes, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final total = prizes.fold<int>(0, (sum, p) => sum + p.weight);

    double startAngle = -pi / 2;
    for (int i = 0; i < prizes.length; i++) {
      final sweep = prizes[i].weight / total * 2 * pi;
      final paint = Paint()..color = colors[i % colors.length];
      canvas.drawArc(Rect.fromCircle(center: center, radius: radius), startAngle, sweep, true, paint);

      final labelAngle = startAngle + sweep / 2;
      final labelRadius = radius * 0.62;
      final labelCenter = Offset(
        center.dx + labelRadius * cos(labelAngle),
        center.dy + labelRadius * sin(labelAngle),
      );

      final tp = TextPainter(
        text: TextSpan(
          text: prizes[i].label,
          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(maxWidth: radius * 0.6);
      tp.paint(canvas, labelCenter - Offset(tp.width / 2, tp.height / 2));

      startAngle += sweep;
    }

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = Colors.white,
    );
    canvas.drawCircle(center, 10, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WheelPainter oldDelegate) => false;
}
