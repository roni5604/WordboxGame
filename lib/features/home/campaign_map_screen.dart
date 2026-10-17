import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_dialog.dart';
import '../../data/models/player_profile.dart';
import '../../game_engine/chapters.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import 'widgets/chapter_gate.dart';
import 'widgets/level_node.dart';
import 'widgets/path_painter.dart';
import 'widgets/world_map_backdrop.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/feedback/haptics.dart';

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

  /// השלב שאליו גללנו אוטומטית לאחרונה. גוללים שוב רק כשהשלב הנוכחי
  /// משתנה (למשל הפרופיל נטען, או שלב חדש נפתח) - לא "חוטפים" גלילה ידנית.
  int? _scrolledForLevel;

  /// מיקום (Y בתוך המפה) של השלב הבא לשחק - לגלילה ולכפתור "לשלב שלי".
  double? _currentNodeY;

  /// האם השלב הנוכחי מחוץ לתצוגה (ואז מופיע כפתור "לשלב שלי").
  bool _currentOutOfView = false;

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

  double _targetOffsetFor(double nodeY) {
    final viewport = _scrollController.position.viewportDimension;
    final max = _scrollController.position.maxScrollExtent;
    // השלב הנוכחי מעט מתחת לאמצע המסך - כך רואים גם את השלבים הבאים.
    return (nodeY - viewport * 0.55).clamp(0.0, max);
  }

  void _scrollToCurrent({bool fromEntry = false}) {
    final y = _currentNodeY;
    if (y == null || !_scrollController.hasClients) return;
    final target = _targetOffsetFor(y);
    if (fromEntry) {
      // "נוחתים" ליד השלב ומחליקים אליו - מרגיש כמו מצלמה שמתמקדת, בלי
      // לגלול את כל המפה מההתחלה.
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo((target + 260).clamp(0.0, max));
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 900), curve: Curves.easeOutCubic);
    } else {
      _scrollController.animateTo(target, duration: const Duration(milliseconds: 650), curve: Curves.easeInOutCubic);
    }
  }

  void _onScroll() {
    final context = this.context;
    if (!context.mounted) return;
    final nodeY = _currentNodeY;
    if (nodeY != null && _scrollController.hasClients) {
      final top = _scrollController.offset;
      final bottom = top + _scrollController.position.viewportDimension;
      final out = nodeY < top + 40 || nodeY > bottom - 40;
      if (out != _currentOutOfView) setState(() => _currentOutOfView = out);
    }
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

  Widget _chapterMarkerAt({
    required BuildContext context,
    required PlayerProfile profile,
    required LevelConfig level,
    required Offset position,
    required double centerX,
    required double width,
  }) {
    const markerWidth = 104.0;
    final half = LevelNode.sizeFor(level) / 2;
    // בצד הנגדי למסלול, כדי לא להסתיר את הצומת או את הקו.
    final left = position.dx >= centerX ? position.dx - half - 10 - markerWidth : position.dx + half + 10;
    final chapter = CampaignChapters.chapterOf(level.levelNumber);
    return Positioned(
      left: left.clamp(8.0, width - markerWidth - 8),
      top: position.dy - 17,
      width: markerWidth,
      child: _ChapterMarker(
        chapter: chapter,
        open: profile.isChapterOpen(chapter),
        reached: profile.isLevelUnlocked(level.levelNumber),
        requiredStars: CampaignChapters.requiredStars(chapter),
        onTap: () {
          if (!profile.isChapterOpen(chapter) && profile.isLevelUnlocked(level.levelNumber)) {
            showChapterGateDialog(context, chapter);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('לא הצלחנו לטעון את הפרופיל. נסו שוב.')),
        data: (profile) {
          final levels = CampaignLevels.all;
          final width = MediaQuery.of(context).size.width;
          final centerX = width / 2;

          final positions = <Offset>[];
          final worldBanners = <_WorldBannerData>[
            _WorldBannerData(tier: levels.first.tier, worldIndex: levels.first.tier.index, centerY: 56),
          ];
          final bands = <WorldBand>[];
          double y = 150.0;
          var bandStart = 0.0;
          var bandTier = levels.first.tier;

          for (int i = 0; i < levels.length; i++) {
            final isNewWorldStart = i > 0 && levels[i].tier != levels[i - 1].tier;
            if (isNewWorldStart) {
              bands.add(WorldBand(tier: bandTier, worldIndex: bandTier.index, startY: bandStart, endY: y));
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

          final currentIndex = (profile.highestUnlockedLevel - 1).clamp(0, levels.length - 1);
          _currentNodeY = positions[currentIndex].dy;
          if (_scrolledForLevel != profile.highestUnlockedLevel) {
            final firstTime = _scrolledForLevel == null;
            _scrolledForLevel = profile.highestUnlockedLevel;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _scrollToCurrent(fromEntry: firstTime);
            });
          }

          final totalHeight = y + 180;
          bands.add(WorldBand(tier: bandTier, worldIndex: bandTier.index, startY: bandStart, endY: totalHeight));
          _lastBands = bands;

          final fallbackTier = levels
              .firstWhere((l) => l.levelNumber == profile.highestUnlockedLevel, orElse: () => levels.first)
              .tier;
          final visibleTier =
              CampaignLevels.worldOrder[_visibleWorldIndex.clamp(0, CampaignLevels.worldOrder.length - 1)];
          final headerTier = _scrollController.hasClients ? visibleTier : fallbackTier;

          final segmentColors = [
            for (int i = 1; i < levels.length; i++) AppColors.pathColorForWorldIndex(levels[i].tier.index),
          ];

          final map = Container(
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
                              painter: PathPainter(points: positions, segmentColors: segmentColors),
                            ),
                            for (final banner in worldBanners)
                              Positioned(
                                left: 12,
                                right: 12,
                                top: banner.centerY - 48,
                                child: _WorldGate(tier: banner.tier, worldIndex: banner.worldIndex),
                              ),
                            for (int i = 0; i < levels.length; i++)
                              Positioned(
                                left: positions[i].dx - LevelNode.sizeFor(levels[i]) / 2,
                                top: positions[i].dy - LevelNode.sizeFor(levels[i]) / 2,
                                child: LevelNode(
                                  config: levels[i],
                                  progress: profile.progressFor(levels[i].levelNumber),
                                  isUnlocked: profile.canPlayLevel(levels[i].levelNumber),
                                  isNextToPlay: levels[i].levelNumber == profile.highestUnlockedLevel &&
                                      profile.canPlayLevel(levels[i].levelNumber),
                                  onTap: () => context.push('/level/${levels[i].levelNumber}/intro'),
                                  onLockedTap: () {
                                    Haptics.medium();
                                    if (profile.isBlockedByChapterGate(levels[i].levelNumber)) {
                                      showChapterGateDialog(
                                        context,
                                        CampaignChapters.chapterOf(levels[i].levelNumber),
                                      );
                                      return;
                                    }
                                    GameToast.show(
                                      context,
                                      message:
                                          'שלב ${levels[i].levelNumber} עוד נעול - סיימו את שלב ${profile.highestUnlockedLevel} כדי להתקדם',
                                      icon: Icons.lock_rounded,
                                      color: const Color(0xFF7B3FF2),
                                    );
                                  },
                                ),
                              ),
                            // תווית "פרק N" ליד השלב הראשון של כל פרק, עם מצב השער שלו.
                            for (int i = 0; i < levels.length; i++)
                              if (CampaignChapters.isGateLevel(levels[i].levelNumber))
                                _chapterMarkerAt(
                                  context: context,
                                  profile: profile,
                                  level: levels[i],
                                  position: positions[i],
                                  centerX: centerX,
                                  width: width,
                                ),
                            // "אתם כאן": האוואטאר של השחקן/ית מרחף מעל השלב הבא.
                            Positioned(
                              left: positions[currentIndex].dx - 26,
                              top: positions[currentIndex].dy - LevelNode.sizeFor(levels[currentIndex]) / 2 - 74,
                              child: IgnorePointer(
                                child: _YouAreHereMarker(
                                  avatarId: profile.avatarId,
                                  photoUrl: ref.watch(authStateProvider).valueOrNull?.photoUrl,
                                ),
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

          return TopBarTint(
            color: AppColors.gradientForWorldIndex(headerTier.index).first,
            child: Stack(
              children: [
                map,
                // כפתור צף "לשלב שלי" - מופיע רק כשגוללים רחוק מהשלב הנוכחי.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.paddingOf(context).bottom + 18,
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      transitionBuilder: (child, a) => ScaleTransition(
                        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                        child: FadeTransition(opacity: a, child: child),
                      ),
                      child: _currentOutOfView
                          ? SizedBox(
                              key: const ValueKey('jump'),
                              width: 200,
                              child: CandyButton(
                                label: 'לשלב שלי',
                                subtitle: 'שלב ${profile.highestUnlockedLevel}',
                                icon: _scrollController.hasClients && (_currentNodeY ?? 0) < _scrollController.offset
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                palette: CandyPalette.green,
                                height: 54,
                                fontSize: 17,
                                onPressed: _scrollToCurrent,
                              ),
                            )
                          : const SizedBox.shrink(key: ValueKey('none')),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// סמן "אתם כאן" בסגנון מפות שלבים: האוואטאר בתוך סיכה לבנה שמרחפת
/// מעלה-מטה מעל השלב הבא לשחק.
class _YouAreHereMarker extends StatelessWidget {
  final String avatarId;
  final String? photoUrl;

  const _YouAreHereMarker({required this.avatarId, this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
          width: 52,
          height: 66,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              Positioned(
                top: 44,
                child: Transform.rotate(
                  angle: math.pi / 4,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(2, 2))],
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: AvatarWidget(avatarId: avatarId, photoUrl: photoUrl, size: 46, ring: false),
              ),
            ],
          ),
        )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .moveY(begin: 0, end: -8, duration: 900.ms, curve: Curves.easeInOut);
  }
}

class _TopBar extends StatelessWidget {
  final int coins;
  final int totalStars;
  final String worldLabel;
  final int worldIndex;

  const _TopBar({required this.coins, required this.totalStars, required this.worldLabel, required this.worldIndex});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          CandyIconButton(icon: Icons.arrow_back_rounded, tooltip: 'חזרה לתפריט', onPressed: () => context.go('/home')),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'מפת השלבים',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
                ),
                Row(
                  children: [
                    Icon(AppColors.iconForWorldIndex(worldIndex), color: Colors.white70, size: 13),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        worldLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
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
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.9), borderRadius: BorderRadius.circular(20)),
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

/// תווית "פרק N" ליד השלב הראשון של פרק: פתוח (וי), סגור שאפשר כבר לפתוח
/// (סגול עם מנעול וכמות הכוכבים הנדרשת), או סגור עתידי (שקוף למחצה).
class _ChapterMarker extends StatelessWidget {
  final int chapter;
  final bool open;
  final bool reached;
  final int requiredStars;
  final VoidCallback onTap;

  const _ChapterMarker({
    required this.chapter,
    required this.open,
    required this.reached,
    required this.requiredStars,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final closedNow = !open && reached;
    final bg = open ? Colors.white.withValues(alpha: 0.92) : (closedNow ? const Color(0xFF7B3FF2) : Colors.black26);
    final fg = open ? AppColors.textDark : Colors.white;
    Widget chip = GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: Colors.white, width: closedNow ? 2 : 1),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              open ? Icons.check_circle_rounded : Icons.lock_rounded,
              size: 15,
              color: open ? AppColors.success : Colors.white,
            ),
            const SizedBox(width: 4),
            Text(
              'פרק $chapter',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: fg),
            ),
            if (!open) ...[
              const SizedBox(width: 4),
              const Icon(Icons.star_rounded, size: 13, color: AppColors.star),
              Text(
                '$requiredStars',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Colors.white),
              ),
            ],
          ],
        ),
        ),
      ),
    );
    if (closedNow) {
      chip = chip
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.06, duration: 800.ms, curve: Curves.easeInOut);
    }
    return chip;
  }
}
