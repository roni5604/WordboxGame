import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/player_profile_provider.dart';
import 'widgets/level_node.dart';
import 'widgets/path_painter.dart';
import 'widgets/world_map_backdrop.dart';

const double _nodeSpacingY = 136;
const double _amplitude = 90;

/// רווח נוסף לפני השלב הראשון של עולם חדש - כדי ששער-המעבר (_WorldGate)
/// יהיה רחב ובולט, והרקע של העולם הבא כבר יתחיל מאחוריו.
const double _worldBannerGap = 176;

class _WorldBannerData {
  final WorldTier tier;
  final int worldIndex;
  final double centerY;

  const _WorldBannerData({required this.tier, required this.worldIndex, required this.centerY});
}

/// מפת השלבים (הקמפיין) - מגיעים לכאן בלחיצה על "שחקו!" בתפריט הראשי.
/// הרקע והמסלול מחליפים צבע לפי העולם בגלילה, כדי שההבדל בין העולמות
/// יורגש גם בלי לקרוא את הבאנר.
class CampaignMapScreen extends ConsumerStatefulWidget {
  const CampaignMapScreen({super.key});

  @override
  ConsumerState<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends ConsumerState<CampaignMapScreen> {
  final _scrollController = ScrollController();
  int _visibleWorldIndex = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    final context = this.context;
    if (!context.mounted) return;
    final bands = _lastBands;
    if (bands.isEmpty) return;
    final viewport = MediaQuery.sizeOf(context).height * 0.42;
    final focusY = _scrollController.offset + viewport;
    var next = bands.first.worldIndex;
    for (final band in bands) {
      if (focusY >= band.startY) next = band.worldIndex;
    }
    if (next != _visibleWorldIndex) {
      setState(() => _visibleWorldIndex = next);
    }
  }

  List<WorldBand> _lastBands = const [];

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('שגיאה בטעינת הפרופיל: $e')),
        data: (profile) {
          final levels = CampaignLevels.all;
          final width = MediaQuery.of(context).size.width;
          final centerX = width / 2;

          final positions = <Offset>[];
          final worldBanners = <_WorldBannerData>[
            _WorldBannerData(
              tier: levels.first.tier,
              worldIndex: levels.first.tier.index,
              centerY: 56,
            ),
          ];
          final bands = <WorldBand>[];
          double y = 150.0;
          var bandStart = 0.0;
          var bandTier = levels.first.tier;

          for (int i = 0; i < levels.length; i++) {
            final isNewWorldStart = i > 0 && levels[i].tier != levels[i - 1].tier;
            if (isNewWorldStart) {
              bands.add(
                WorldBand(
                  tier: bandTier,
                  worldIndex: bandTier.index,
                  startY: bandStart,
                  endY: y,
                ),
              );
              worldBanners.add(
                _WorldBannerData(
                  tier: levels[i].tier,
                  worldIndex: levels[i].tier.index,
                  centerY: y + _worldBannerGap / 2,
                ),
              );
              y += _worldBannerGap;
              bandStart = y - _worldBannerGap;
              bandTier = levels[i].tier;
            }
            final x = centerX + _amplitude * math.sin(i * 0.9);
            positions.add(Offset(x, y));
            y += _nodeSpacingY;
          }

          final totalHeight = y + 180;
          bands.add(
            WorldBand(
              tier: bandTier,
              worldIndex: bandTier.index,
              startY: bandStart,
              endY: totalHeight,
            ),
          );
          _lastBands = bands;

          final fallbackTier = levels
              .firstWhere(
                (l) => l.levelNumber == profile.highestUnlockedLevel,
                orElse: () => levels.first,
              )
              .tier;
          final visibleTier = CampaignLevels.worldOrder[_visibleWorldIndex.clamp(
            0,
            CampaignLevels.worldOrder.length - 1,
          )];
          final headerTier = _scrollController.hasClients ? visibleTier : fallbackTier;

          final segmentColors = [
            for (int i = 1; i < levels.length; i++)
              AppColors.pathColorForWorldIndex(levels[i].tier.index),
          ];

          return Container(
            color: AppColors.gradientForWorldIndex(headerTier.index).first,
            child: SafeArea(
              child: Column(
                children: [
                  _TopBar(
                    coins: profile.coins,
                    totalStars: profile.totalStars,
                    worldLabel: headerTier.titleHe,
                    worldIndex: headerTier.index,
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      child: SizedBox(
                        width: width,
                        height: totalHeight,
                        child: Stack(
                          children: [
                            CustomPaint(
                              size: Size(width, totalHeight),
                              painter: WorldMapBackdrop(bands: bands, width: width),
                            ),
                            CustomPaint(
                              size: Size(width, totalHeight),
                              painter: PathPainter(
                                points: positions,
                                segmentColors: segmentColors,
                              ),
                            ),
                            for (final banner in worldBanners)
                              Positioned(
                                left: 12,
                                right: 12,
                                top: banner.centerY - 48,
                                child: _WorldGate(
                                  tier: banner.tier,
                                  worldIndex: banner.worldIndex,
                                ),
                              ),
                            for (int i = 0; i < levels.length; i++)
                              Positioned(
                                left: positions[i].dx - LevelNode.sizeFor(levels[i]) / 2,
                                top: positions[i].dy - LevelNode.sizeFor(levels[i]) / 2,
                                child: LevelNode(
                                  config: levels[i],
                                  progress: profile.progressFor(levels[i].levelNumber),
                                  isUnlocked: profile.isLevelUnlocked(levels[i].levelNumber),
                                  isNextToPlay:
                                      levels[i].levelNumber == profile.highestUnlockedLevel,
                                  onTap: () =>
                                      context.push('/level/${levels[i].levelNumber}/intro'),
                                ),
                              ),
                          ],
                        ),
                      ),
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

/// שער מעבר-עולם רחב - מוצג במפה לפני הצומת הראשון של כל עולם חדש.
/// האייקון, השם והצבע של העולם הבא ממלאים את רוחב המסך, כדי שהמעבר
/// יורגש בגלילה גם ממרחק.
class _WorldGate extends StatelessWidget {
  final WorldTier tier;
  final int worldIndex;

  const _WorldGate({required this.tier, required this.worldIndex});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.gradientForWorldIndex(worldIndex);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white, width: 2.5),
        boxShadow: [
          BoxShadow(color: colors.last.withValues(alpha: 0.45), blurRadius: 18, spreadRadius: 1),
          const BoxShadow(color: Colors.black38, blurRadius: 12, offset: Offset(0, 6)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
            ),
            child: Icon(AppColors.iconForWorldIndex(worldIndex), color: Colors.white, size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'עולם ${worldIndex + 1}',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
                Text(
                  tier.titleHe,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '${tier.gridSize}×${tier.gridSize}',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
            ),
          ),
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
