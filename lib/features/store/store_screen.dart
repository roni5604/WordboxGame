import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/cosmetics/cosmetic_catalog.dart';
import '../../core/purchases/iap_controller.dart';
import '../../core/purchases/real_money_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/player_profile.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../ads/native_ad_card.dart';
import '../ads/store_ad_gift_card.dart';

class _HintPack {
  final int hints;
  final int cost;
  final String label;
  final bool bestValue;

  const _HintPack({
    required this.hints,
    required this.cost,
    required this.label,
    this.bestValue = false,
  });
}

const _packs = [
  _HintPack(hints: 1, cost: 40, label: 'רמז בודד'),
  _HintPack(hints: 5, cost: 150, label: 'חבילת 5', bestValue: true),
  _HintPack(hints: 12, cost: 300, label: 'חבילת ענק'),
];

/// חנות: רמזים במטבעות, סקינים, ורכישת מטבעות/רמזים בכסף אמיתי באפליקציה.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, _HintPack pack) async {
    final ok = await ref
        .read(playerProfileProvider.notifier)
        .buyHints(amount: pack.hints, cost: pack.cost);
    if (!context.mounted) return;
    ok
        ? ref.read(soundServiceProvider).playCoin()
        : ref.read(soundServiceProvider).playError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(
          ok
              ? 'קניתם ${pack.hints} רמזים חדשים! 💡'
              : 'אין מספיק מטבעות לחבילה הזו 😕',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;
    final showPlacements = ref.watch(adsGatewayProvider).isSupported;

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
            error: (e, st) => Center(
              child: Text(
                'שגיאה: $e',
                style: const TextStyle(color: Colors.white),
              ),
            ),
            data: (profile) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ),
                        const Text(
                          'חנות',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.paid_rounded,
                                color: Colors.amberAccent,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '${profile.coins}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: _StoreSections(
                      profile: profile,
                      isGuest: isGuest,
                      showPlacements: showPlacements,
                      onBuyHints: (pack) => _buy(context, ref, pack),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _StoreSections extends ConsumerStatefulWidget {
  final PlayerProfile profile;
  final bool isGuest;
  final bool showPlacements;
  final ValueChanged<_HintPack> onBuyHints;

  const _StoreSections({
    required this.profile,
    required this.isGuest,
    required this.showPlacements,
    required this.onBuyHints,
  });

  @override
  ConsumerState<_StoreSections> createState() => _StoreSectionsState();
}

class _StoreSectionsState extends ConsumerState<_StoreSections> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen<IapState>(iapProvider, (previous, next) {
      final message = next.message;
      if (message == null || message == previous?.message) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    });

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              _TabChip(label: 'רמזים', selected: _tab == 0, onTap: () => setState(() => _tab = 0)),
              const SizedBox(width: 8),
              _TabChip(label: 'עיצובים', selected: _tab == 1, onTap: () => setState(() => _tab = 1)),
              const SizedBox(width: 8),
              _TabChip(label: 'כסף', selected: _tab == 2, onTap: () => setState(() => _tab = 2)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: switch (_tab) {
            1 => _CosmeticsTab(profile: widget.profile),
            2 => const _RealMoneyTab(),
            _ => _HintsTab(
                profile: widget.profile,
                isGuest: widget.isGuest,
                showPlacements: widget.showPlacements,
                onBuyHints: widget.onBuyHints,
              ),
          },
        ),
      ],
    );
  }
}

class _TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _TabChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Material(
        color: selected ? Colors.white : Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.primaryDark : Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HintsTab extends StatelessWidget {
  final PlayerProfile profile;
  final bool isGuest;
  final bool showPlacements;
  final ValueChanged<_HintPack> onBuyHints;

  const _HintsTab({
    required this.profile,
    required this.isGuest,
    required this.showPlacements,
    required this.onBuyHints,
  });

  @override
  Widget build(BuildContext context) {
    if (isGuest) {
      return const Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 20),
            child: StoreAdGiftCard(),
          ),
          SizedBox(height: 12),
          Expanded(child: _GuestHintsCta()),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      itemCount: _packs.length + (showPlacements ? 2 : 0) + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Column(
            children: [
              Text(
                '💡 יש לך כרגע ${profile.hints} רמזים',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'רמז מציג מילה שלמה. בחנות הזו קונים רמזים במטבעות.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          );
        }
        final index = i - 1;
        if (showPlacements && index == 0) return const StoreAdGiftCard();
        if (showPlacements && index == _packs.length + 1) return const NativeAdCard();
        final packIndex = showPlacements ? index - 1 : index;
        final pack = _packs[packIndex];
        return _PackCard(pack: pack, onBuy: () => onBuyHints(pack));
      },
    );
  }
}

class _CosmeticsTab extends ConsumerWidget {
  final PlayerProfile profile;

  const _CosmeticsTab({required this.profile});

  Future<void> _buy(BuildContext context, WidgetRef ref, CosmeticSlot slot, String id, int cost) async {
    final ok = await ref.read(playerProfileProvider.notifier).buyOrEquipCosmetic(
          slot: slot,
          id: id,
          cost: cost,
        );
    if (!context.mounted) return;
    ok ? ref.read(soundServiceProvider).playCoin() : ref.read(soundServiceProvider).playError();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(ok ? 'העיצוב מצויד' : 'אין מספיק מטבעות'),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const _SectionTitle('לוח'),
        for (final skin in CosmeticCatalog.boards)
          _CosmeticCard(
            name: skin.nameHe,
            cost: skin.cost,
            owned: profile.ownedBoardSkins.contains(skin.id),
            equipped: profile.boardSkinId == skin.id,
            swatch: skin.tileColor,
            onBuy: () => _buy(context, ref, CosmeticSlot.board, skin.id, skin.cost),
          ),
        const _SectionTitle('אותיות'),
        for (final skin in CosmeticCatalog.letters)
          _CosmeticCard(
            name: skin.nameHe,
            cost: skin.cost,
            owned: profile.ownedLetterSkins.contains(skin.id),
            equipped: profile.letterSkinId == skin.id,
            swatch: skin.tileOverride ?? skin.letterColor,
            onBuy: () => _buy(context, ref, CosmeticSlot.letter, skin.id, skin.cost),
          ),
        const _SectionTitle('סימון'),
        for (final skin in CosmeticCatalog.markers)
          _CosmeticCard(
            name: skin.nameHe,
            cost: skin.cost,
            owned: profile.ownedMarkerSkins.contains(skin.id),
            equipped: profile.markerSkinId == skin.id,
            swatch: skin.color,
            onBuy: () => _buy(context, ref, CosmeticSlot.marker, skin.id, skin.cost),
          ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Text(
        text,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
      ),
    );
  }
}

class _CosmeticCard extends StatelessWidget {
  final String name;
  final int cost;
  final bool owned;
  final bool equipped;
  final Color swatch;
  final VoidCallback onBuy;

  const _CosmeticCard({
    required this.name,
    required this.cost,
    required this.owned,
    required this.equipped,
    required this.swatch,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final label = equipped ? 'מצויד' : (owned || cost == 0 ? 'הפעילו' : '$cost');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(color: swatch, shape: BoxShape.circle),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(name, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ),
              FilledButton(
                onPressed: equipped ? null : onBuy,
                child: Text(label),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RealMoneyTab extends ConsumerWidget {
  const _RealMoneyTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final iap = ref.watch(iapProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Text(
          iap.isWeb
              ? 'רכישה בכסף אמיתי זמינה באפליקציה ל-iPhone ולאנדרואיד.'
              : 'קנו מטבעות או רמזים. המחיר הסופי מופיע בחלון החנות.',
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 12),
        for (final pack in RealMoneyCatalog.packs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Icon(
                      pack.hints > 0 ? Icons.lightbulb_rounded : Icons.paid_rounded,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(pack.titleHe, style: const TextStyle(fontWeight: FontWeight.w800)),
                          Text(pack.subtitleHe, style: const TextStyle(color: Colors.black54, fontSize: 12)),
                        ],
                      ),
                    ),
                    FilledButton(
                      onPressed: iap.isWeb
                          ? null
                          : () async {
                              final error = await ref.read(iapProvider.notifier).buy(pack.productId);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                      child: Text(iap.isWeb ? 'באפליקציה' : iap.priceLabel(pack)),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// מוצג במקום חנות הרמזים כשמשחקים כאורח/ת - רמזים (כולל מתנת הפתיחה
/// והבונוס היומי) שמורים לחשבונות אמיתיים, כדי לתת סיבה טובה להירשם.
class _GuestHintsCta extends StatelessWidget {
  const _GuestHintsCta();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '🎁',
              style: TextStyle(fontSize: 56),
            ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
            const SizedBox(height: 16),
            const Text(
              'רמזים שמורים למי שנרשם/ת',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'הרשמו בחינם עם Google, Apple, Facebook או מייל - ותקבלו 5 רמזי '
              'מתנה מיד, בונוס רמזים חדש בכל יום, ואפשרות לקנות עוד עם המטבעות '
              'שלכם.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () => context.push('/auth'),
                child: const Text(
                  'הרשמה / התחברות',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PackCard extends StatelessWidget {
  final _HintPack pack;
  final VoidCallback onBuy;

  const _PackCard({required this.pack, required this.onBuy});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      elevation: pack.bestValue ? 8 : 3,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: pack.bestValue
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.star, width: 2.5),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_rounded,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        pack.label,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      if (pack.bestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.star,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text(
                            'הכי משתלם',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${pack.hints} רמזים',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              onPressed: onBuy,
              icon: const Icon(Icons.paid_rounded, size: 16),
              label: Text('${pack.cost}'),
            ),
          ],
        ),
      ),
    );
  }
}
