import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/player_profile_provider.dart';

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

/// חנות פשוטה לקניית רמזים תמורת המטבעות שנצברו במשחק (ללא תשלום אמיתי) -
/// נותנת לשחקנים שאזלו להם הרמזים החינמיים דרך נוספת להמשיך להיעזר.
class StoreScreen extends ConsumerWidget {
  const StoreScreen({super.key});

  Future<void> _buy(BuildContext context, WidgetRef ref, _HintPack pack) async {
    final ok = await ref
        .read(playerProfileProvider.notifier)
        .buyHints(amount: pack.hints, cost: pack.cost);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: ok ? AppColors.success : AppColors.error,
        content: Text(
          ok ? 'קניתם ${pack.hints} רמזים חדשים! 💡' : 'אין מספיק מטבעות לחבילה הזו 😕',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);

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
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, st) => Center(
              child: Text('שגיאה: $e', style: const TextStyle(color: Colors.white)),
            ),
            data: (profile) {
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => context.pop(),
                          icon: const Icon(Icons.arrow_forward_rounded, color: Colors.white),
                        ),
                        const Text(
                          'חנות רמזים',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.paid_rounded, color: Colors.amberAccent, size: 18),
                              const SizedBox(width: 6),
                              Text('${profile.coins}',
                                  style: const TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '💡 יש לך כרגע ${profile.hints} רמזים',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                    ),
                  ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                  const SizedBox(height: 6),
                  const Text(
                    'רמז מציג לכם מילה שעוד לא מצאתם, כדי לעזור לכם להתקדם.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 28),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: _packs.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 16),
                      itemBuilder: (context, i) {
                        final pack = _packs[i];
                        return _PackCard(
                          pack: pack,
                          onBuy: () => _buy(context, ref, pack),
                        ).animate().fadeIn(delay: (100 * i).ms).slideY(begin: 0.15, end: 0);
                      },
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
              child: const Icon(Icons.lightbulb_rounded, color: AppColors.primary, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(pack.label,
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      if (pack.bestValue) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.star,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('הכי משתלם',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('${pack.hints} רמזים', style: const TextStyle(color: Colors.black54)),
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
