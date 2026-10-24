import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ads/ads_policy.dart';
import '../../../core/ads/ads_runtime.dart';
import '../../../core/purchases/iap_controller.dart';
import '../../../core/purchases/real_money_catalog.dart';
import '../../../providers/player_profile_provider.dart';
import '../../../providers/sound_provider.dart';
import '../../ads/rewarded_gift_button.dart';
import '../store_screen.dart';
import 'hint_offers.dart';
import 'store_kit.dart';

/// באנר ההצעות בראש החנות: שקופיות שמתחלפות לבד, עם תמונת תלת-ממד
/// מרחפת מעל קרני אור.
class StoreHero extends ConsumerStatefulWidget {
  final bool isGuest;
  final ValueChanged<StoreTab> onOpenTab;

  const StoreHero({super.key, required this.isGuest, required this.onOpenTab});

  @override
  ConsumerState<StoreHero> createState() => _StoreHeroState();
}

class _StoreHeroState extends ConsumerState<StoreHero> {
  final _pages = PageController(viewportFraction: 0.92);
  Timer? _auto;
  int _page = 0;
  int _count = 1;
  bool _userTouched = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _auto ??= periodicIfMotion(context, const Duration(seconds: 5), _next);
  }

  void _next() {
    if (!mounted || _userTouched || _count < 2 || !_pages.hasClients) return;
    _pages.animateToPage(
      (_page + 1) % _count,
      duration: const Duration(milliseconds: 650),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _auto?.cancel();
    _pages.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ads = ref.watch(adsGatewayProvider);
    final iap = ref.watch(iapProvider);
    final showGift = ads.isSupported && !(ads.isInitialized && !ads.canRequestAds);
    final treasure = RealMoneyCatalog.byId('wordbox_coins_1500');
    final showTreasure = !iap.isWeb && treasure != null && iap.prices.containsKey(treasure.productId);

    final slides = <Widget>[
      if (showGift) _GiftSlide(isGuest: widget.isGuest),
      if (showTreasure) _TreasureSlide(pack: treasure, price: iap.priceLabel(treasure)),
      if (!widget.isGuest) _HintDealSlide(onOpen: () => widget.onOpenTab(StoreTab.shop)),
      _CosmeticsSlide(onOpen: () => widget.onOpenTab(StoreTab.cosmetics)),
    ];
    _count = slides.length;
    if (_page >= _count) _page = 0;

    return Column(
      children: [
        SizedBox(
          height: 196,
          child: Listener(
            onPointerDown: (_) => _userTouched = true,
            child: PageView.builder(
              controller: _pages,
              itemCount: slides.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (context, i) => AnimatedBuilder(
                animation: _pages,
                builder: (context, child) {
                  var delta = 0.0;
                  if (_pages.hasClients && _pages.position.haveDimensions) {
                    delta = (_pages.page ?? 0) - i;
                  }
                  final scale = 1 - delta.abs().clamp(0.0, 1.0) * 0.08;
                  return Transform.scale(scale: scale, child: child);
                },
                child: Padding(padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6), child: slides[i]),
              ),
            ),
          ),
        ),
        if (slides.length > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < slides.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                  width: i == _page ? 18 : 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: i == _page ? StorePalette.gold : Colors.white.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// שלד משותף לשקופית: גרדיאנט, תמונה עם קרני אור בצד אחד, טקסט ופעולה.
class _Slide extends StatelessWidget {
  final List<Color> colors;
  final String art;
  final String? tag;
  final String title;
  final String subtitle;
  final Widget action;

  const _Slide({
    required this.colors,
    required this.art,
    required this.title,
    required this.subtitle,
    required this.action,
    this.tag,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: colors),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 8))],
        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(18, 14, 4, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tag != null) ...[StoreRibbon(tag!), const SizedBox(height: 6)],
                  Text(
                    title,
                    maxLines: 2,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      height: 1.1,
                      fontWeight: FontWeight.w900,
                      shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 4)],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  action,
                ],
              ),
            ),
          ),
          SizedBox(
            width: 138,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const LightRays(size: 200, color: Colors.white),
                FloatingArt(asset: art, size: 122, glow: Colors.white, amplitude: 6),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GiftSlide extends ConsumerWidget {
  final bool isGuest;

  const _GiftSlide({required this.isGuest});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ads = ref.watch(adsGatewayProvider);
    final remaining = ads.storeRewardsRemaining;
    return _Slide(
      colors: const [Color(0xFFFF5FA2), Color(0xFF8E3BFF)],
      art: StoreArt.gift,
      tag: remaining > 0 ? 'נותרו $remaining היום' : 'חוזרת מחר',
      title: 'מתנה חינם',
      subtitle: isGuest ? 'צפו בפרסומת קצרה וקבלו רמז' : 'צפו בפרסומת קצרה: רמז או ${AdsPolicy.storeCoinGift} מטבעות',
      action: Row(
        children: [
          Expanded(
            child: RewardedGiftButton(
              label: 'רמז חינם',
              successLabel: 'הרמז אצלכם!',
              icon: Icons.lightbulb_rounded,
              style: RewardedButtonStyle.contrast,
              quotaAvailable: remaining > 0,
              placement: 'store_gift_hint',
              rewardCurrency: 'hints',
              rewardAmount: 1,
              onReward: () async {
                await ref.read(playerProfileProvider.notifier).grantHints(1);
                await ref.read(adsGatewayProvider).recordStoreRewardGranted();
                ref.read(soundServiceProvider).playCoin();
              },
            ),
          ),
          if (!isGuest) ...[
            const SizedBox(width: 6),
            Expanded(
              child: RewardedGiftButton(
                label: '+${AdsPolicy.storeCoinGift}',
                successLabel: 'התקבל!',
                icon: Icons.paid_rounded,
                style: RewardedButtonStyle.contrast,
                quotaAvailable: remaining > 0,
                placement: 'store_gift_coins',
                rewardCurrency: 'coins',
                rewardAmount: AdsPolicy.storeCoinGift,
                onReward: () async {
                  await ref.read(playerProfileProvider.notifier).addCoins(AdsPolicy.storeCoinGift);
                  await ref.read(adsGatewayProvider).recordStoreRewardGranted();
                  ref.read(soundServiceProvider).playCoin();
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TreasureSlide extends ConsumerWidget {
  final RealMoneyPack pack;
  final String price;

  const _TreasureSlide({required this.pack, required this.price});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _Slide(
      colors: const [Color(0xFFFFB347), Color(0xFFFF5E62)],
      art: StoreArt.coinsLarge,
      tag: 'הכי משתלם',
      title: 'תיבת האוצר',
      subtitle: '${pack.coins} מטבעות לעיצובים ולרמזים',
      action: TiltCard(
        maxTilt: 0.06,
        onTap: () async {
          final error = await ref.read(iapProvider.notifier).buy(pack.productId);
          if (error != null && context.mounted) showStoreToast(context, error, success: false);
        },
        child: PriceButton(label: price, colors: const [Color(0xFF7CEB6E), Color(0xFF33C24D)]),
      ),
    );
  }
}

class _HintDealSlide extends StatelessWidget {
  final VoidCallback onOpen;

  const _HintDealSlide({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final pack = hintPacks.firstWhere((p) => p.bestValue);
    return _Slide(
      colors: const [Color(0xFF2BD2FF), Color(0xFF2B6CFF)],
      art: StoreArt.hint5,
      tag: 'חיסכון ${pack.savingsPercent(hintPacks.first.cost)}%',
      title: 'חבילת ${pack.hints} רמזים',
      subtitle: 'נתקעתם? רמז חושף מילה שלמה',
      action: TiltCard(
        maxTilt: 0.06,
        onTap: onOpen,
        child: PriceButton(
          label: '${pack.cost}',
          coins: true,
          colors: const [Color(0xFFFFE27A), StorePalette.goldDeep],
        ),
      ),
    );
  }
}

class _CosmeticsSlide extends StatelessWidget {
  final VoidCallback onOpen;

  const _CosmeticsSlide({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return _Slide(
      colors: const [Color(0xFF34E89E), Color(0xFF0F9B8E)],
      art: StoreArt.coinsMedium,
      title: 'לוח בסגנון שלכם',
      subtitle: 'צבעי לוח, אותיות וסימון - לבחור ולהתחדש',
      action: TiltCard(
        maxTilt: 0.06,
        onTap: onOpen,
        child: const PriceButton(label: 'לעיצובים', colors: [Color(0xFFFFE27A), StorePalette.goldDeep]),
      ),
    );
  }
}
