import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../theme/app_colors.dart';
import 'ads_config.dart';

/// כרטיס Native בתבנית Medium של Google, בלי Factory משלנו ב-Kotlin/Swift.
/// נטען רק כשמסך הבית או החנות מבקשים אותו, ורק אחרי שיש הסכמה.
class NativeAdPlacement extends StatefulWidget {
  const NativeAdPlacement({super.key});

  @override
  State<NativeAdPlacement> createState() => _NativeAdPlacementState();
}

class _NativeAdPlacementState extends State<NativeAdPlacement> {
  NativeAd? _ad;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    final isIos = Platform.isIOS;
    final ad = NativeAd(
      adUnitId: AdsConfig.nativeUnitId(isIos: isIos),
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (!mounted) return;
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, error) {
          debugPrint('Native ad failed: ${error.message}');
          ad.dispose();
          if (identical(_ad, ad)) _ad = null;
        },
      ),
      nativeTemplateStyle: NativeTemplateStyle(
        templateType: TemplateType.medium,
        mainBackgroundColor: Colors.white,
        cornerRadius: 24,
        callToActionTextStyle: NativeTemplateTextStyle(
          textColor: Colors.white,
          backgroundColor: AppColors.primary,
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        primaryTextStyle: NativeTemplateTextStyle(
          textColor: AppColors.textDark,
          style: NativeTemplateFontStyle.bold,
          size: 16,
        ),
        secondaryTextStyle: NativeTemplateTextStyle(
          textColor: const Color(0x8A000000),
          style: NativeTemplateFontStyle.normal,
          size: 14,
        ),
      ),
    );
    _ad = ad;
    ad.load();
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (!_loaded || ad == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: _AdBadge(),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ColoredBox(
              color: Colors.white,
              child: SizedBox(height: 340, child: AdWidget(ad: ad)),
            ),
          ),
        ],
      ),
    );
  }
}

class _AdBadge extends StatelessWidget {
  const _AdBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Text(
        'פרסומת',
        style: TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
