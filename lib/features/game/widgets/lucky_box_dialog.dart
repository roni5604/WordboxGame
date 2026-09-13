import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';
import '../../../game_engine/rewards/reward_tables.dart';

/// דיאלוג "תיבת מזל" - נפתח אוטומטית כל 7 שלבים (ראו
/// [RewardTables.luckyBoxLevelInterval] ו-lib/features/game/level_result_screen.dart).
/// לוחצים על התיבה כדי "לפתוח" אותה ולחשוף את הפרס (מטבעות, ולעיתים גם רמז).
class LuckyBoxDialog extends StatefulWidget {
  final LuckyBoxReward reward;

  const LuckyBoxDialog({super.key, required this.reward});

  static Future<void> show(BuildContext context, LuckyBoxReward reward) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => LuckyBoxDialog(reward: reward),
    );
  }

  @override
  State<LuckyBoxDialog> createState() => _LuckyBoxDialogState();
}

class _LuckyBoxDialogState extends State<LuckyBoxDialog> {
  bool _opened = false;
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _openBox() {
    if (_opened) return;
    setState(() => _opened = true);
    _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
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
              numberOfParticles: 22,
              gravity: 0.3,
              shouldLoop: false,
              colors: const [AppColors.star, AppColors.primary, AppColors.success, Colors.white],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
              ),
              borderRadius: BorderRadius.circular(28),
              boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 20)],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'תיבת מזל! 🎁',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: _openBox,
                  child: Icon(
                    _opened ? Icons.card_giftcard_rounded : Icons.inventory_2_rounded,
                    size: 96,
                    color: Colors.white,
                  )
                      .animate(target: _opened ? 1 : 0)
                      .scaleXY(begin: 1, end: 1.25, curve: Curves.elasticOut, duration: 500.ms)
                      .shake(hz: _opened ? 0 : 2, curve: Curves.easeInOut),
                ),
                const SizedBox(height: 8),
                if (!_opened)
                  const Text(
                    'הקישו על התיבה כדי לפתוח!',
                    style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                  ),
                if (_opened) ...[
                  const SizedBox(height: 10),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _RewardChip(
                        icon: Icons.monetization_on_rounded,
                        label: '+${widget.reward.coins} מטבעות',
                      ),
                      if (widget.reward.hints > 0) ...[
                        const SizedBox(width: 10),
                        _RewardChip(
                          icon: Icons.lightbulb_rounded,
                          label: '+${widget.reward.hints} רמזים',
                        ),
                      ],
                    ],
                  ).animate().fadeIn().scale(
                        begin: const Offset(0.7, 0.7),
                        curve: Curves.elasticOut,
                        duration: 600.ms,
                      ),
                  const SizedBox(height: 20),
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

class _RewardChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _RewardChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}
