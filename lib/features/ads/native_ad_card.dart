import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_runtime.dart';
import 'web_reward_ad_card.dart';

/// כרטיס פרסומת. במובייל זה Native של AdMob, באתר מודעת מתנה.
class NativeAdCard extends ConsumerWidget {
  const NativeAdCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsGatewayProvider);
    if (!ads.isSupported || !ads.isInitialized || !ads.canRequestAds) {
      return const SizedBox.shrink();
    }
    if (kIsWeb) return const WebRewardAdCard();
    return ads.buildNativePlacement();
  }
}
