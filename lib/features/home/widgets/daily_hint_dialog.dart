import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/motion/motion.dart';
import '../../../core/ui/rarity_style.dart';
import '../../../game_engine/rewards/rarity.dart';
import '../../../providers/player_profile_provider.dart';
import '../../rewards/reward_reveal.dart';

/// הבונוס היומי (רמזים כמספר היום ברצף השבועי: יום 1 = רמז אחד ... יום 7 =
/// שבעה). כל יום הוא מתנה בדרגה גבוהה יותר - כך שהיום השביעי ("אגדי") הוא
/// סיבה אמיתית לחזור כל יום ולא לשבור את הרצף.
class DailyBonus {
  DailyBonus._();

  static const List<Rarity> rarityByDay = [
    Rarity.common,
    Rarity.common,
    Rarity.uncommon,
    Rarity.uncommon,
    Rarity.rare,
    Rarity.epic,
    Rarity.legendary,
  ];

  static Rarity rarityFor(int day) => rarityByDay[(day - 1).clamp(0, 6)];

  static Future<void> show(BuildContext context, DailyHintReward reward, {WidgetBuilder? extraAction}) {
    return RewardReveal.show(
      context,
      RewardContents(
        rarity: rarityFor(reward.day),
        hints: reward.hintsAwarded,
        title: 'בונוס יומי · יום ${reward.day}',
      ),
      extraAction: extraAction,
      header: (_) => DailyWeekTrack(day: reward.day),
    );
  }
}

/// 7 מתנות קטנות בצבעי הדרגה - מה כבר נאסף, מה היום, ומה מחכה מחר.
class DailyWeekTrack extends StatelessWidget {
  final int day;
  const DailyWeekTrack({super.key, required this.day});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var d = 1; d <= 7; d++) _DayPip(day: d, state: d < day ? _PipState.done : (d == day ? _PipState.today : _PipState.future))
                .animate(delay: (d * 45).ms)
                .fadeIn(duration: 180.ms)
                .slideY(begin: 0.4, curve: Motion.out, duration: 320.ms),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          day >= 7 ? 'השבוע הושלם! מחר מתחילים סבב חדש' : 'מחר: ${day + 1} רמזים · דרגת ${DailyBonus.rarityFor(day + 1).label}',
          style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

enum _PipState { done, today, future }

class _DayPip extends StatelessWidget {
  final int day;
  final _PipState state;
  const _DayPip({required this.day, required this.state});

  @override
  Widget build(BuildContext context) {
    final s = RarityStyle.of(DailyBonus.rarityFor(day));
    final today = state == _PipState.today;
    final size = today ? 44.0 : 36.0;
    final pip = Container(
      width: size,
      height: size,
      margin: const EdgeInsets.symmetric(horizontal: 3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: state == _PipState.future
            ? null
            : LinearGradient(colors: [s.light, s.base, s.dark], begin: Alignment.topCenter, end: Alignment.bottomCenter),
        color: state == _PipState.future ? Colors.white.withValues(alpha: 0.12) : null,
        border: Border.all(color: state == _PipState.future ? s.base.withValues(alpha: 0.8) : Colors.white, width: today ? 3 : 2),
        boxShadow: today ? [BoxShadow(color: s.glow, blurRadius: 16)] : null,
      ),
      alignment: Alignment.center,
      child: state == _PipState.done
          ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
          : Icon(
              day == 7 ? Icons.workspace_premium_rounded : Icons.card_giftcard_rounded,
              color: state == _PipState.future ? s.light.withValues(alpha: 0.85) : Colors.white,
              size: today ? 24 : 18,
            ),
    );
    if (!today) return pip;
    return pip
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.1, duration: 650.ms, curve: Curves.easeInOut);
  }
}
