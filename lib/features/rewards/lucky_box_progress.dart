import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../core/motion/motion.dart';
import '../../core/ui/rarity_style.dart';
import '../../game_engine/rewards/reward_tables.dart';

/// "תיבת מזל בעוד 3 שלבים" - שבעה פסים שמתמלאים לקראת התיבה הבאה.
/// ציפייה לפרס קרוב היא סיבה טובה לשחק "עוד שלב אחד".
class LuckyBoxProgress extends StatelessWidget {
  final int levelNumber;
  const LuckyBoxProgress({super.key, required this.levelNumber});

  @override
  Widget build(BuildContext context) {
    const interval = RewardTables.luckyBoxLevelInterval;
    final done = levelNumber % interval;
    final left = interval - done;
    final gold = RarityStyle.of(Rarity.legendary);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 12, 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F0FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(shape: BoxShape.circle, gradient: gold.gradient),
            child: const Icon(Icons.card_giftcard_rounded, color: Colors.white, size: 18),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .rotate(begin: -0.03, end: 0.03, duration: 900.ms, curve: Curves.easeInOut),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  left == 1 ? 'תיבת מזל בשלב הבא!' : 'תיבת מזל בעוד $left שלבים',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Color(0xFF5B2A9E)),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    for (var i = 0; i < interval; i++)
                      Expanded(
                        child: Container(
                          height: 7,
                          margin: const EdgeInsetsDirectional.only(end: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            color: i < done ? null : const Color(0xFFE2D6F5),
                            gradient: i < done ? LinearGradient(colors: [gold.light, gold.base]) : null,
                          ),
                        )
                            .animate(delay: (900 + i * 60).ms)
                            .fadeIn(duration: Motion.quick)
                            .scaleX(begin: i == done - 1 ? 0.2 : 1, curve: Motion.backOut, duration: 420.ms),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
