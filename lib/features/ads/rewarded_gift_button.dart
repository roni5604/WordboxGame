import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/analytics/analytics_service.dart';
import '../../core/theme/app_colors.dart';

/// כפתור "צפו וקבלו" משותף. מוסתר לגמרי כשאין תמיכה בפרסומות (Web),
/// וכבוי עם הסבר כשאין מודעה מוכנה או שהמכסה היומית נגמרה.
enum RewardedButtonStyle { filled, contrast }

class RewardedGiftButton extends ConsumerStatefulWidget {
  final String label;
  final String successLabel;
  final IconData icon;
  final Future<void> Function() onReward;
  final bool quotaAvailable;
  final RewardedButtonStyle style;

  /// Analytics: where the offer is shown (ad_offer_shown / ad_reward_earned /
  /// ad_show_failed) and what it grants (earn_virtual_currency, source=ad).
  final String placement;
  final String rewardCurrency;
  final int rewardAmount;

  const RewardedGiftButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onReward,
    required this.placement,
    required this.rewardCurrency,
    required this.rewardAmount,
    this.successLabel = 'המתנה התקבלה!',
    this.quotaAvailable = true,
    this.style = RewardedButtonStyle.filled,
  });

  @override
  ConsumerState<RewardedGiftButton> createState() => _RewardedGiftButtonState();
}

class _RewardedGiftButtonState extends ConsumerState<RewardedGiftButton> {
  bool _busy = false;
  bool _done = false;
  bool _offerLogged = false;

  String get _reward => '${widget.rewardCurrency}_${widget.rewardAmount}';

  Future<void> _watch() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final ads = ref.read(adsGatewayProvider);
    final analytics = ref.read(analyticsProvider);
    final earned = await ads.showRewarded();
    if (earned) {
      analytics
        ..adRewardEarned(placement: widget.placement, reward: _reward)
        ..earnVirtualCurrency(
          currency: widget.rewardCurrency,
          value: widget.rewardAmount,
          source: 'ad',
          item: widget.placement,
        );
    } else {
      final reason = ads.lastShowFailureReason;
      if (reason != null) analytics.adShowFailed(placement: widget.placement, format: 'rewarded', reason: reason);
    }
    if (!mounted) return;
    if (!earned) {
      setState(() => _busy = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('הצפייה לא הושלמה, אין מתנה'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }
    try {
      await widget.onReward();
    } catch (e) {
      debugPrint('Reward grant failed: $e');
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsGatewayProvider);
    if (!ads.isSupported) return const SizedBox.shrink();
    if (ads.isInitialized && !ads.canRequestAds) return const SizedBox.shrink();

    final String label;
    final bool enabled;
    if (_done) {
      label = widget.successLabel;
      enabled = false;
    } else if (!widget.quotaAvailable) {
      label = 'חזרו מחר';
      enabled = false;
    } else if (!ads.isInitialized || _busy) {
      label = 'טוען פרסומת...';
      enabled = false;
    } else if (!ads.isRewardedReady) {
      label = 'אין פרסומת כרגע';
      enabled = false;
    } else {
      label = widget.label;
      enabled = true;
    }

    // ad_offer_shown: once per widget, the first time the offer is actually
    // available to tap.
    if (enabled && !_offerLogged) {
      _offerLogged = true;
      ref.read(analyticsProvider).adOfferShown(placement: widget.placement, reward: _reward);
    }

    final onPressed = enabled ? _watch : null;
    final child = _busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          )
        : Text(label, textAlign: TextAlign.center, maxLines: 2);

    final ButtonStyle style;
    if (widget.style == RewardedButtonStyle.contrast) {
      style = FilledButton.styleFrom(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primaryDark,
        disabledBackgroundColor: Colors.white.withValues(alpha: 0.45),
        disabledForegroundColor: AppColors.primaryDark.withValues(alpha: 0.7),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      );
    } else {
      style = FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
        disabledForegroundColor: Colors.white,
        minimumSize: const Size.fromHeight(46),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
      );
    }

    if (_busy || _done) {
      return FilledButton(style: style, onPressed: onPressed, child: child);
    }
    return FilledButton.icon(
      style: style,
      onPressed: onPressed,
      icon: Icon(widget.icon, size: 18),
      label: child,
    );
  }
}
