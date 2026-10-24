import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/purchases/iap_controller.dart';
import '../../../core/purchases/real_money_catalog.dart';
import '../store_screen.dart';
import 'store_kit.dart';

/// רכישה בכסף אמיתי (App Store / Google Play). באפליקציה מציגים רק חבילות
/// שהחנות החזירה (עם מחיר), כדי שלא יופיע כפתור קנייה שנכשל.
class PremiumOffers extends ConsumerWidget {
  const PremiumOffers({super.key});

  static const _art = {
    'wordbox_coins_200': StoreArt.coinsSmall,
    'wordbox_coins_600': StoreArt.coinsMedium,
    'wordbox_coins_1500': StoreArt.coinsLarge,
    'wordbox_hints_5': StoreArt.hint1,
    'wordbox_hints_15': StoreArt.hint5,
    'wordbox_hints_40': StoreArt.hint12,
  };

  /// מחיר מספרי מתוך תווית מחיר של החנות ("\$2.99", "₪10.90", "3,90 €").
  static double? parsePrice(String label) {
    var digits = label.replaceAll(RegExp(r'[^0-9.,]'), '');
    if (digits.contains(',') && !digits.contains('.')) digits = digits.replaceAll(',', '.');
    digits = digits.replaceAll(',', '');
    return double.tryParse(digits);
  }

  /// כמה יותר מקבלים לכל שקל לעומת החבילה הקטנה מאותו סוג, לפי המחירים
  /// שהחנות החזירה בפועל ([priceOf]).
  static int bonusPercent(RealMoneyPack pack, String Function(RealMoneyPack) priceOf) {
    final sameKind = RealMoneyCatalog.packs.where((p) => (p.hints > 0) == (pack.hints > 0)).toList();
    double value(RealMoneyPack p) {
      final price = parsePrice(priceOf(p)) ?? parsePrice(p.fallbackPrice) ?? 0;
      final amount = p.hints > 0 ? p.hints : p.coins;
      return price == 0 ? 0 : amount / price;
    }

    final base = value(sameKind.first);
    if (base == 0) return 0;
    return ((value(pack) / base - 1) * 100).round();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iap = ref.watch(iapProvider);
    final packs = iap.isWeb
        ? RealMoneyCatalog.packs
        : RealMoneyCatalog.packs.where((p) => iap.prices.containsKey(p.productId)).toList();
    final status = iap.isWeb
        ? 'רכישה בכסף אמיתי זמינה באפליקציה ל-iPhone ולאנדרואיד.'
        : !iap.ready
        ? 'טוען את החנות...'
        : packs.isEmpty
        ? 'החבילות לא זמינות כרגע. נסו שוב מאוחר יותר.'
        : 'מטבעות לעיצובים ורמזים מוכנים לשימוש. המחיר הסופי מופיע בחלון החנות.';

    final coins = packs.where((p) => p.coins > 0).toList();
    final hints = packs.where((p) => p.hints > 0).toList();

    // הכי משתלמת (האחרונה) ככרטיס רחב למעלה, והשאר בזוגות מתחתיה.
    Widget grid(List<RealMoneyPack> list) => Column(
      children: [
        if (list.length > 1)
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 14),
            child: _PremiumCard(pack: list.last, index: list.length - 1, siblings: list.length, wide: true),
          ),
        for (var i = 0; i < (list.length > 1 ? list.length - 1 : list.length); i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _PremiumCard(pack: list[i], index: i, siblings: list.length),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: i + 1 < (list.length > 1 ? list.length - 1 : list.length)
                        ? _PremiumCard(pack: list[i + 1], index: i + 1, siblings: list.length)
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _PremiumTitle(),
        const SizedBox(height: 6),
        Text(
          status,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13),
        ),
        const SizedBox(height: 14),
        if (coins.isNotEmpty) ...[const _KindTitle(icon: Icons.paid_rounded, title: 'חבילות מטבעות'), grid(coins)],
        if (hints.isNotEmpty) ...[const _KindTitle(icon: Icons.lightbulb_rounded, title: 'חבילות רמזים'), grid(hints)],
        if (packs.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.verified_user_rounded, color: Colors.white.withValues(alpha: 0.6), size: 16),
                const SizedBox(width: 6),
                Text(
                  'תשלום מאובטח דרך ${iap.isWeb ? 'החנות' : 'Apple / Google'}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.6),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KindTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _KindTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: StorePalette.gold, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}

class _PremiumCard extends ConsumerStatefulWidget {
  final RealMoneyPack pack;
  final int index;
  final int siblings;
  final bool wide;

  const _PremiumCard({required this.pack, required this.index, required this.siblings, this.wide = false});

  @override
  ConsumerState<_PremiumCard> createState() => _PremiumCardState();
}

class _PremiumCardState extends ConsumerState<_PremiumCard> {
  bool _busy = false;

  Future<void> _buy() async {
    final iap = ref.read(iapProvider);
    if (iap.isWeb || _busy) return;
    _busy = true;
    // purchase_start / purchase_failed are logged in IapController.
    final error = await ref.read(iapProvider.notifier).buy(widget.pack.productId);
    _busy = false;
    if (error != null && mounted) showStoreToast(context, error, success: false);
  }

  @override
  Widget build(BuildContext context) {
    final iap = ref.watch(iapProvider);
    final pack = widget.pack;
    final bonus = PremiumOffers.bonusPercent(pack, iap.priceLabel);
    final best = widget.siblings > 1 && widget.index == widget.siblings - 1;
    final popular = widget.siblings > 2 && widget.index == 1;
    final radius = BorderRadius.circular(24);
    final isHints = pack.hints > 0;

    final art = PremiumOffers._art[pack.productId] ?? StoreArt.coinsSmall;
    final glow = isHints ? const Color(0xFFFFD27A) : StorePalette.gold;
    final bonusText = bonus > 0
        ? Text(
            '+$bonus% בונוס',
            style: const TextStyle(color: Color(0xFF1FA463), fontSize: 12.5, fontWeight: FontWeight.w900),
          )
        : Text(pack.subtitleHe, style: const TextStyle(color: StorePalette.muted, fontSize: 12));
    final price = PriceButton(
      label: iap.isWeb ? 'באפליקציה' : iap.priceLabel(pack),
      enabled: !iap.isWeb,
      colors: best ? const [Color(0xFFFFE27A), StorePalette.goldDeep] : const [Color(0xFF7CEB6E), Color(0xFF33C24D)],
    );

    Widget card = widget.wide
        ? StoreCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(14, 18, 14, 14),
            gradient: const [Color(0xFFFFFBEA), Color(0xFFFFEFC2)],
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.titleHe,
                        style: const TextStyle(color: StorePalette.ink, fontSize: 22, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 2),
                      bonusText,
                      const SizedBox(height: 12),
                      price,
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                FloatingArt(asset: art, size: 124, phase: widget.index * 0.27, glow: glow),
              ],
            ),
          )
        : StoreCard(
            radius: 24,
            padding: const EdgeInsets.fromLTRB(10, 16, 10, 12),
            gradient: best ? const [Color(0xFFFFFBEA), Color(0xFFFFEFC2)] : null,
            child: Column(
              children: [
                FloatingArt(asset: art, size: 96, phase: widget.index * 0.27, glow: glow),
                const SizedBox(height: 6),
                Text(
                  pack.titleHe,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: StorePalette.ink, fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                SizedBox(height: 18, child: bonusText),
                const Spacer(),
                const SizedBox(height: 8),
                price,
              ],
            ),
          );

    if (best) {
      card = GlowFrame(
        radius: 24,
        child: ShineSweep(borderRadius: radius, child: card),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TiltCard(onTap: _buy, child: card),
        if (best || popular)
          Positioned(
            top: -10,
            left: 0,
            right: 0,
            child: Center(
              child: StoreRibbon(
                best ? 'הכי משתלם' : 'פופולרי',
                colors: best
                    ? const [StorePalette.pink, Color(0xFFFF7A45)]
                    : const [Color(0xFF4FC3F7), Color(0xFF1E88E5)],
              ),
            ),
          ),
      ],
    );
  }
}

/// כותרת לחלק של הכסף האמיתי, שמפרידה אותו מחבילות הרמזים במטבעות שמעליו.
class _PremiumTitle extends StatelessWidget {
  const _PremiumTitle();

  @override
  Widget build(BuildContext context) {
    Widget line({required bool fadeStart}) => Expanded(
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: AlignmentDirectional.centerStart,
                end: AlignmentDirectional.centerEnd,
                colors: [
                  StorePalette.gold.withValues(alpha: fadeStart ? 0 : 0.8),
                  StorePalette.gold.withValues(alpha: fadeStart ? 0.8 : 0),
                ],
              ),
            ),
          ),
        );
    return Row(
      children: [
        line(fadeStart: true),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.diamond_rounded, color: StorePalette.gold, size: 22),
              SizedBox(width: 6),
              Text(
                'חבילות פרימיום',
                style: TextStyle(color: StorePalette.gold, fontSize: 20, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ),
        line(fadeStart: false),
      ],
    );
  }
}
