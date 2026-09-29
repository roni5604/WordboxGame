import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'rewarded_gift_button.dart';

/// אחרי שלב עם כוכבים: מכפילים רק את המטבעות שכבר הורווחו בשלב הזה.
class DoubleCoinsCta extends ConsumerWidget {
  final int coins;

  const DoubleCoinsCta({super.key, required this.coins});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (coins <= 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: RewardedGiftButton(
        label: 'צפו והכפילו את $coins המטבעות',
        successLabel: 'המטבעות הוכפלו!',
        icon: Icons.play_circle_fill_rounded,
        onReward: () async {
          await ref.read(playerProfileProvider.notifier).addCoins(coins);
          ref.read(soundServiceProvider).playCoin();
        },
      ),
    );
  }
}
