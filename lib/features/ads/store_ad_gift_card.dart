import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_policy.dart';
import '../../core/ads/ads_runtime.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'rewarded_gift_button.dart';

/// מתנת חנות: רמז אחד או מטבעות, עד שתי צפיות ביום, משותף לשתי המתנות.
class StoreAdGiftCard extends ConsumerWidget {
  const StoreAdGiftCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsGatewayProvider);
    if (!ads.isSupported) return const SizedBox.shrink();
    if (ads.isInitialized && !ads.canRequestAds) return const SizedBox.shrink();

    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;
    final remaining = ads.storeRewardsRemaining;
    final coins = AdsPolicy.storeCoinGift;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'מתנה תמורת צפייה',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                Text(
                  remaining > 0 ? 'נותרו $remaining היום' : 'חזרו מחר',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              isGuest
                  ? 'רמז אחד תמורת צפייה. הצפייה היא בחירה שלכם.'
                  : 'רמז אחד, או חופן מטבעות. הצפייה היא בחירה שלכם.',
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 12),
            RewardedGiftButton(
              label: 'רמז חינם',
              successLabel: 'הרמז אצלכם!',
              icon: Icons.lightbulb_rounded,
              quotaAvailable: remaining > 0,
              onReward: () async {
                await ref.read(playerProfileProvider.notifier).grantHints(1);
                await ref.read(adsGatewayProvider).recordStoreRewardGranted();
                ref.read(soundServiceProvider).playCoin();
              },
            ),
            if (!isGuest) ...[
              const SizedBox(height: 8),
              RewardedGiftButton(
                label: '+$coins מטבעות',
                successLabel: 'המטבעות אצלכם!',
                icon: Icons.paid_rounded,
                quotaAvailable: remaining > 0,
                onReward: () async {
                  await ref
                      .read(playerProfileProvider.notifier)
                      .addCoins(coins);
                  await ref.read(adsGatewayProvider).recordStoreRewardGranted();
                  ref.read(soundServiceProvider).playCoin();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
