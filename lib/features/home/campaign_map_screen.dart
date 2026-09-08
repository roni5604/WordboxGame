import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/player_profile_provider.dart';
import 'widgets/level_node.dart';
import 'widgets/path_painter.dart';

const double _nodeSpacingY = 128;
const double _amplitude = 90;

/// מפת השלבים (הקמפיין) - מגיעים לכאן בלחיצה על "שחקו!" בתפריט הראשי.
class CampaignMapScreen extends ConsumerWidget {
  const CampaignMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('שגיאה בטעינת הפרופיל: $e')),
        data: (profile) {
          final levels = CampaignLevels.all;
          final width = MediaQuery.of(context).size.width;
          final centerX = width / 2;

          final positions = List.generate(levels.length, (i) {
            final x = centerX + _amplitude * math.sin(i * 0.9);
            final y = 140.0 + i * _nodeSpacingY;
            return Offset(x, y);
          });

          final totalHeight = 140.0 + levels.length * _nodeSpacingY + 160;
          final worldIndex = profile.highestUnlockedLevel > 0
              ? levels
                  .firstWhere(
                    (l) => l.levelNumber == profile.highestUnlockedLevel,
                    orElse: () => levels.first,
                  )
                  .tier
                  .index
              : 0;

          final currentTier = levels
              .firstWhere(
                (l) => l.levelNumber == profile.highestUnlockedLevel,
                orElse: () => levels.first,
              )
              .tier;

          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.gradientForWorldIndex(worldIndex),
              ),
            ),
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    coins: profile.coins,
                    totalStars: profile.totalStars,
                    worldLabel: currentTier.titleHe,
                  ),
                  Expanded(
                    child: Stack(
                      children: [
                        SingleChildScrollView(
                          child: SizedBox(
                            width: width,
                            height: totalHeight,
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size(width, totalHeight),
                                  painter: PathPainter(points: positions),
                                ),
                                for (int i = 0; i < levels.length; i++)
                                  Positioned(
                                    left: positions[i].dx - 32,
                                    top: positions[i].dy - 32,
                                    child: LevelNode(
                                      config: levels[i],
                                      progress: profile.progressFor(levels[i].levelNumber),
                                      isUnlocked: profile.isLevelUnlocked(levels[i].levelNumber),
                                      isNextToPlay:
                                          levels[i].levelNumber == profile.highestUnlockedLevel,
                                      onTap: () => context
                                          .push('/level/${levels[i].levelNumber}/intro'),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final int coins;
  final int totalStars;
  final String worldLabel;

  const _TopBar({required this.coins, required this.totalStars, required this.worldLabel});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.go('/home'),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'מפת השלבים',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
              ),
              Text(
                worldLabel,
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          _Pill(icon: Icons.star_rounded, iconColor: AppColors.star, label: '$totalStars'),
          const SizedBox(width: 8),
          _Pill(icon: Icons.paid_rounded, iconColor: Colors.amberAccent, label: '$coins'),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _Pill({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
