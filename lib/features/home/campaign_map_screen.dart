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

/// רווח נוסף (בנוסף ל-[_nodeSpacingY] הרגיל) לפני השלב הראשון של עולם
/// חדש - כדי שיהיה מקום לבאנר "מעבר עולם" (ראו [_WorldBanner]) בלי
/// לדחוס אותו על הצומת עצמו.
const double _worldBannerGap = 130;

/// מידע על באנר מעבר-עולם בודד שיש לצייר מעל מיקום מסוים במפה.
class _WorldBannerData {
  final WorldTier tier;
  final int worldIndex;
  final double centerY;

  const _WorldBannerData({required this.tier, required this.worldIndex, required this.centerY});
}

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

          // מיקום כל צומת - מסלול סינוסי רציף אחד (כמו קודם), אבל עם
          // רווח נוסף (_worldBannerGap) בכל פעם שעוברים לעולם חדש, כדי
          // שיהיה מקום לבאנר "מעבר עולם" (ראו _WorldBanner) בלי לפגוע
          // בחיבור המסלול המקווקו עצמו (PathPainter עדיין מחבר את כל
          // הצמתים ברצף, גם על פני הרווח המורחב).
          final positions = <Offset>[];
          final worldBanners = <_WorldBannerData>[];
          double y = 140.0;
          for (int i = 0; i < levels.length; i++) {
            final isNewWorldStart = i > 0 && levels[i].tier != levels[i - 1].tier;
            if (isNewWorldStart) {
              worldBanners.add(
                _WorldBannerData(
                  tier: levels[i].tier,
                  worldIndex: levels[i].tier.index,
                  centerY: y + _worldBannerGap / 2,
                ),
              );
              y += _worldBannerGap;
            }
            final x = centerX + _amplitude * math.sin(i * 0.9);
            positions.add(Offset(x, y));
            y += _nodeSpacingY;
          }

          final totalHeight = y + 160;
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
                    worldIndex: currentTier.index,
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
                                for (final banner in worldBanners)
                                  Positioned(
                                    left: 0,
                                    right: 0,
                                    top: banner.centerY - 34,
                                    child: _WorldBanner(
                                      tier: banner.tier,
                                      worldIndex: banner.worldIndex,
                                    ),
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
  final int worldIndex;

  const _TopBar({
    required this.coins,
    required this.totalStars,
    required this.worldLabel,
    required this.worldIndex,
  });

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
              Row(
                children: [
                  Icon(AppColors.iconForWorldIndex(worldIndex), color: Colors.white70, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    worldLabel,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
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

/// באנר "מעבר עולם" - מוצג במפת השלבים ממש לפני הצומת הראשון של כל
/// עולם חדש (ראו החישוב ב-[CampaignMapScreen.build]), עם אייקון+שם+צבע
/// ייחודיים לעולם (ראו [AppColors.worldGradients]/[AppColors.worldIcons]) -
/// זהות ויזואלית ברורה בלי צורך בנכסי אמנות חדשים.
class _WorldBanner extends StatelessWidget {
  final WorldTier tier;
  final int worldIndex;

  const _WorldBanner({required this.tier, required this.worldIndex});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: AppColors.gradientForWorldIndex(worldIndex)),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 12)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppColors.iconForWorldIndex(worldIndex), color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              '${tier.titleHe} - לוח ${tier.gridSize}×${tier.gridSize}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ],
        ),
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
