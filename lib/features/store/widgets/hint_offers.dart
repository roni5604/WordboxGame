import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/analytics/analytics_service.dart';
import '../../../data/models/player_profile.dart';
import '../../../providers/player_profile_provider.dart';
import '../../auth/sign_in_methods.dart';
import '../store_screen.dart';
import 'store_kit.dart';

class HintPack {
  final int hints;
  final int cost;
  final String label;
  final String art;
  final bool bestValue;

  const HintPack({
    required this.hints,
    required this.cost,
    required this.label,
    required this.art,
    this.bestValue = false,
  });

  /// אחוז החיסכון מול קניית רמזים בודדים.
  int savingsPercent(int singleCost) {
    final full = singleCost * hints;
    if (full <= cost) return 0;
    return ((full - cost) * 100 / full).round();
  }
}

/// רמז עולה בערך 2-3 שלבים של מטבעות (היה 40 / 150 / 300).
const hintPacks = [
  HintPack(hints: 1, cost: 60, label: 'רמז בודד', art: StoreArt.hint1),
  HintPack(hints: 5, cost: 270, label: 'חבילת 5', art: StoreArt.hint5, bestValue: true),
  HintPack(hints: 12, cost: 600, label: 'תיבת ענק', art: StoreArt.hint12),
];

class HintOffers extends ConsumerWidget {
  final PlayerProfile profile;
  final bool isGuest;
  final void Function(Offset at, {bool coinRain}) onCelebrate;
  final VoidCallback onNeedCoins;

  const HintOffers({
    super.key,
    required this.profile,
    required this.isGuest,
    required this.onCelebrate,
    required this.onNeedCoins,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionIntro(
          title: isGuest ? 'רמזים - לחשבונות רשומים' : 'יש לכם ${profile.hints} רמזים',
          subtitle: 'רמז חושף מילה שלמה על הלוח. כל רמז שווה כוכב.',
        ),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < hintPacks.length; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                Expanded(
                  child: _HintPackCard(
                    pack: hintPacks[i],
                    phase: i * 0.33,
                    locked: isGuest,
                    affordable: profile.coins >= hintPacks[i].cost,
                    onCelebrate: onCelebrate,
                    onNeedCoins: onNeedCoins,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (isGuest) ...[
          const SizedBox(height: 18),
          const _GuestHintsCta(),
        ] else ...[
          const SizedBox(height: 8),
          NeedCoinsHint(onTap: onNeedCoins),
        ],
      ],
    );
  }
}

class _SectionIntro extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionIntro({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13),
        ),
      ],
    );
  }
}

class _HintPackCard extends ConsumerStatefulWidget {
  final HintPack pack;
  final double phase;
  final bool locked;
  final bool affordable;
  final void Function(Offset at, {bool coinRain}) onCelebrate;
  final VoidCallback onNeedCoins;

  const _HintPackCard({
    required this.pack,
    required this.phase,
    required this.locked,
    required this.affordable,
    required this.onCelebrate,
    required this.onNeedCoins,
  });

  @override
  ConsumerState<_HintPackCard> createState() => _HintPackCardState();
}

class _HintPackCardState extends ConsumerState<_HintPackCard> {
  final _shake = GlobalKey<ShakeBoxState>();
  bool _busy = false;

  Future<void> _buy() async {
    if (widget.locked) {
      context.push('/auth');
      return;
    }
    if (_busy) return;
    _busy = true;
    final pack = widget.pack;
    await buyWithCoins(
      context: context,
      ref: ref,
      shakeKey: _shake,
      onCelebrate: widget.onCelebrate,
      onNeedCoins: widget.onNeedCoins,
      successText: 'קניתם ${pack.hints == 1 ? 'רמז' : '${pack.hints} רמזים'}! 💡',
      purchase: () async {
        final ok = await ref.read(playerProfileProvider.notifier).buyHints(amount: pack.hints, cost: pack.cost);
        if (ok) {
          AnalyticsService.instance
            ..spendVirtualCurrency(currency: 'coins', value: pack.cost, itemName: 'hint_pack_${pack.hints}')
            ..earnVirtualCurrency(
              currency: 'hints',
              value: pack.hints,
              source: 'other',
              item: 'hint_pack_${pack.hints}',
            );
        }
        return ok;
      },
    );
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final pack = widget.pack;
    final savings = pack.savingsPercent(hintPacks.first.cost);
    final radius = BorderRadius.circular(24);

    Widget card = StoreCard(
      radius: 24,
      padding: const EdgeInsets.fromLTRB(8, 18, 8, 10),
      child: Column(
        children: [
          FloatingArt(asset: pack.art, size: 84, phase: widget.phase),
          const SizedBox(height: 6),
          Text(
            '${pack.hints}',
            style: const TextStyle(color: StorePalette.ink, fontSize: 28, fontWeight: FontWeight.w900, height: 1),
          ),
          Text(
            pack.hints == 1 ? 'רמז' : 'רמזים',
            style: const TextStyle(color: StorePalette.muted, fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 20,
            child: savings > 0
                ? Text(
                    'חיסכון $savings%',
                    style: const TextStyle(color: Color(0xFF1FA463), fontSize: 12, fontWeight: FontWeight.w900),
                  )
                : null,
          ),
          const Spacer(),
          PriceButton(
            label: widget.locked ? 'הרשמה' : '${pack.cost}',
            coins: !widget.locked,
            enabled: widget.locked || widget.affordable,
            colors: widget.locked
                ? const [Color(0xFFB57BFF), Color(0xFF7B3FF2)]
                : const [Color(0xFF7CEB6E), Color(0xFF33C24D)],
          ),
        ],
      ),
    );

    if (pack.bestValue) {
      card = GlowFrame(
        radius: 24,
        child: ShineSweep(borderRadius: radius, child: card),
      );
    }

    return Semantics(
      button: true,
      label: '${pack.label}, ${pack.hints} רמזים, ${pack.cost} מטבעות',
      child: ShakeBox(
        key: _shake,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            TiltCard(onTap: _buy, child: card),
            if (pack.bestValue)
              const Positioned(top: -10, left: 0, right: 0, child: Center(child: StoreRibbon('הכי משתלם'))),
            if (widget.locked)
              Positioned(
                top: 10,
                right: 10,
                child: Icon(Icons.lock_rounded, size: 18, color: StorePalette.muted.withValues(alpha: 0.9)),
              ),
          ],
        ),
      ),
    );
  }
}

/// אורחים: הרמזים (כולל מתנת הפתיחה והבונוס היומי) שמורים לחשבונות
/// אמיתיים, כדי לתת סיבה טובה להירשם.
class _GuestHintsCta extends StatelessWidget {
  const _GuestHintsCta();

  @override
  Widget build(BuildContext context) {
    return StoreCard(
      gradient: const [Color(0xFF8E5CFF), Color(0xFF5B2BD6)],
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Text(
            'רמזים שמורים למי שנרשם/ת',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'הרשמו בחינם עם ${signInMethodsText()} - ותקבלו רמזי מתנה מיד, '
            'בונוס יומי עם רמזים ומטבעות, ואפשרות לקנות עוד עם המטבעות שלכם.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13.5, height: 1.45),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TiltCard(
              maxTilt: 0.06,
              onTap: () => context.push('/auth'),
              child: const PriceButton(label: 'הרשמה / התחברות', colors: [Color(0xFFFFE27A), StorePalette.goldDeep]),
            ),
          ),
        ],
      ),
    );
  }
}
