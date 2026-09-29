import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'rewarded_gift_button.dart';

/// באתר אין כרטיס Native של AdMob. במקומו כרטיס «פרסומת» שמפעיל
/// מודעת מתנה של Google (Ad Placement API) ומעניק רמז אחד.
class WebRewardAdCard extends ConsumerWidget {
  const WebRewardAdCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(adsGatewayProvider).adHintsRemaining;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Material(
        color: Colors.white,
        elevation: 3,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Align(
                alignment: AlignmentDirectional.centerStart,
                child: _Badge(),
              ),
              const SizedBox(height: 8),
              const Text(
                'רמז תמורת צפייה',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text(
                'צפייה קצרה, ורמז אחד אצלכם. אפשר לדלג.',
                style: TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 10),
              RewardedGiftButton(
                label: 'צפו וקבלו רמז',
                successLabel: 'הרמז אצלכם!',
                icon: Icons.play_circle_fill_rounded,
                quotaAvailable: remaining > 0,
                onReward: () async {
                  await ref.read(playerProfileProvider.notifier).grantHints(1);
                  await ref.read(adsGatewayProvider).recordAdHintGranted();
                  ref.read(soundServiceProvider).playCoin();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'פרסומת',
        style: TextStyle(
          color: AppColors.primaryDark,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
