import 'dart:math' as math;

import 'package:flutter/gestures.dart';
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
import '../../providers/sound_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import 'map/explorer_critters.dart';
import 'map/map_billboards.dart';
import 'map/map_layout.dart';
import 'map/sky_ladder.dart';
import 'map/world_scene_painter.dart';
import 'map/world_theme.dart';
import 'widgets/chapter_gate.dart';
import 'widgets/level_node.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../core/feedback/haptics.dart';

/// מפת השלבים (הקמפיין) - מגיעים לכאן בלחיצה על "שחקו!" בתפריט הראשי.
///
/// המפה מוצגת בפרספקטיבה תלת-ממדית: השביל של זואי מתפתל אל האופק, השלבים
/// הבאים מתרחקים ומתכווצים, וכל עולם הוא "רמה" בנוף עם צבעים, קישוטים וחיה
/// חוקרת משלו. בין העולמות זורם נהר זוהר עם גשר, וכשחוצים אותו השמיים
/// מתחלפים ונכנס כרטיס "עולם חדש". את הנוף מצייר [WorldScenePainter], ומעליו
/// "שלטים עומדים" (שלבים, זואי, חיות, שלטי עולם) שממוקמים לפי אותה הקרנה.
class CampaignMapScreen extends ConsumerStatefulWidget {
  const CampaignMapScreen({super.key});

  @override
  ConsumerState<CampaignMapScreen> createState() => _CampaignMapScreenState();
}

class _CampaignMapScreenState extends ConsumerState<CampaignMapScreen> with TickerProviderStateMixin {
  final CampaignMapLayout _layout = CampaignMapLayout.campaign;

  /// המצלמה: ה-u שנמצא על קו המיקוד. גרירה/טלטול/טיסה מזיזים אותה.
  late final AnimationController _camera = AnimationController.unbounded(vsync: this);

  /// שעון האווירה (מים זורמים, גחליליות, עננים, תנועות החיות).
  late final AnimationController _ambient = AnimationController(
    vsync: this,
    duration: Duration(seconds: WorldScenePainter.ambientSeconds.round()),
  )..repeat();

  /// השלב שאליו "טסנו" לאחרונה. טסים שוב רק כשהשלב הנוכחי משתנה (למשל
  /// הפרופיל נטען, או שלב חדש נפתח) - לא "חוטפים" גלילה ידנית.
  int? _scrolledForLevel;

  /// בזמן טיסה אוטומטית לא מציגים כרטיס עולם לכל נהר שחולפים מעליו.
  bool _autoFlight = false;
  bool _building = false;
  int _focusWorld = -1;
  int? _titleWorld;
  int _titleSerial = 0;
  double _dragY = 0;
  double _topInset = 0;

  double get _minCamera => _layout.firstU - 80;
  // אפשר לגלול עד הסולם לשמיים שבסוף הדרך.
  double get _maxCamera => _layout.skyLadderU - 300;

  @override
  void initState() {
    super.initState();
    _camera.addListener(_onCamera);
  }

  @override
  void dispose() {
    _camera.removeListener(_onCamera);
    _camera.dispose();
    _ambient.dispose();
    super.dispose();
  }

  int _worldAt(double camera) => _layout.zoneAt(camera + 180).worldIndex;

  void _onCamera() {
    final w = _worldAt(_camera.value);
    if (w == _focusWorld) return;
    final first = _focusWorld < 0;
    if (_building) {
      _focusWorld = w;
      return;
    }
    setState(() => _focusWorld = w);
    if (!first && !_autoFlight) _showTitle(w);
  }

  void _showTitle(int world) {
    Haptics.light();
    // צליל קריסטל עדין יחד עם כרטיס העולם (מעל מוזיקת התפריטים).
    ref.read(soundServiceProvider).playStarGained();
    setState(() {
      _titleWorld = world;
      _titleSerial++;
    });
  }

  void _flyTo(double target, {Duration? duration, Curve curve = Curves.easeInOutCubic}) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final from = _camera.value;
    final worldBefore = _worldAt(from);
    _autoFlight = true;
    void land() {
      _autoFlight = false;
      if (!mounted) return;
      final w = _worldAt(_camera.value);
      if (w != worldBefore) _showTitle(w);
    }

    if (reduceMotion) {
      _camera.value = target;
      land();
      return;
    }
    final ms = duration ?? Duration(milliseconds: (420 + (target - from).abs() / 30).clamp(420, 900).round());
    _camera.animateTo(target, duration: ms, curve: curve).whenCompleteOrCancel(land);
  }

  double _targetFor(PlayerProfile profile) => _layout.nodeFor(profile.highestUnlockedLevel).u;

  // ---------------------------------------------------------------- גרירה

  MapProjection _projection(Size size) => MapProjection.screen(size, _topInset, _camera.value);

  void _onDragStart(DragStartDetails d) {
    _camera.stop();
    _autoFlight = false;
    _dragY = d.localPosition.dy;
  }

  void _onDragUpdate(DragUpdateDetails d, Size size) {
    final from = _dragY;
    _dragY = d.localPosition.dy;
    var du = _projection(size).dragDelta(from, _dragY);
    final c = _camera.value;
    // התנגדות "גומי" מעבר לקצוות.
    if ((c < _minCamera && du < 0) || (c > _maxCamera && du > 0)) du *= 0.3;
    _camera.value = c + du;
  }

  void _onDragEnd(DragEndDetails d, Size size) {
    final v = _projection(size).flingVelocity(d.velocity.pixelsPerSecond.dy).clamp(-16000.0, 16000.0);
    _camera.animateWith(
      BouncingScrollSimulation(
        spring: SpringDescription.withDampingRatio(mass: 0.5, stiffness: 100, ratio: 1.1),
        position: _camera.value,
        velocity: v,
        leadingExtent: _minCamera,
        trailingExtent: _maxCamera,
      ),
    );
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    _camera.stop();
    _camera.value = (_camera.value - event.scrollDelta.dy * 2.4).clamp(_minCamera, _maxCamera);
  }

  // ---------------------------------------------------------------- בנייה

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);
    _topInset = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: WorldTheme.of(math.max(0, _focusWorld)).sky.first,
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => const Center(child: Text('לא הצלחנו לטעון את הפרופיל. נסו שוב.')),
        data: (profile) {
          final target = _targetFor(profile);
          if (_scrolledForLevel != profile.highestUnlockedLevel) {
            final firstTime = _scrolledForLevel == null;
            _scrolledForLevel = profile.highestUnlockedLevel;
            if (firstTime) {
              // כניסה קולנועית: מתחילים מעט "מאחור" ומרחפים קדימה אל השלב הנוכחי,
              // וכרטיס העולם יורד מלמעלה.
              _autoFlight = true;
              _building = true;
              _camera.value = target - 900;
              _building = false;
              _titleWorld = _worldAt(target);
              _titleSerial++;
            }
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (firstTime) {
                _flyTo(target, duration: const Duration(milliseconds: 1250), curve: Curves.easeOutCubic);
              } else {
                _flyTo(target);
              }
            });
          }

          final sky = WorldTheme.of(math.max(0, _focusWorld)).sky;
          final tier = _tierFor(math.max(0, _focusWorld));
          return TopBarTint(
            color: sky.first,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return Listener(
                  onPointerSignal: _onPointerSignal,
                  child: GestureDetector(
                    key: const ValueKey('campaign-map'),
                    behavior: HitTestBehavior.opaque,
                    onVerticalDragStart: _onDragStart,
                    onVerticalDragUpdate: (d) => _onDragUpdate(d, size),
                    onVerticalDragEnd: (d) => _onDragEnd(d, size),
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: RepaintBoundary(
                            child: CustomPaint(
                              painter: WorldScenePainter(
                                layout: _layout,
                                camera: _camera,
                                ambient: _ambient,
                                topInset: _topInset,
                                trailU: target,
                              ),
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: AnimatedBuilder(
                            animation: _camera,
                            builder: (context, _) => Stack(
                              clipBehavior: Clip.none,
                              children: _billboards(context, profile, size, target),
                            ),
                          ),
                        ),
                        // הסרגל העליון "צף" על השמיים.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.only(top: _topInset),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [sky.first, sky.first.withValues(alpha: 0.85), sky.first.withValues(alpha: 0)],
                                stops: const [0, 0.6, 1],
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: _TopBar(
                                coins: profile.coins,
                                totalStars: profile.totalStars,
                                worldLabel: 'עולם ${tier.index + 1} · ${tier.titleHe}',
                                worldIndex: tier.index,
                              ),
                            ),
                          ),
                        ),
                        if (_titleWorld != null)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _topInset + 70,
                            child: Center(
                              child: WorldTitleCard(
                                key: ValueKey('title-$_titleSerial'),
                                tier: _tierFor(_titleWorld!),
                                worldIndex: _titleWorld!,
                                ambient: _ambient,
                              ),
                            ),
                          ),
                        // כפתור צף "לשלב שלי" - מופיע רק כשמתרחקים מהשלב הנוכחי.
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: MediaQuery.paddingOf(context).bottom + 18,
                          child: AnimatedBuilder(
                            animation: _camera,
                            builder: (context, _) => _jumpButton(profile, target),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _jumpButton(PlayerProfile profile, double target) {
    final rel = target - _camera.value;
    final away = !_autoFlight && (rel > 1350 || rel < -300);
    return Center(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        transitionBuilder: (child, a) => ScaleTransition(
          scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
          child: FadeTransition(opacity: a, child: child),
        ),
        child: away
            ? SizedBox(
                key: const ValueKey('jump'),
                width: 200,
                child: CandyButton(
                  label: 'לשלב שלי',
                  subtitle: 'שלב ${profile.highestUnlockedLevel}',
                  icon: rel > 0 ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                  palette: CandyPalette.green,
                  height: 54,
                  fontSize: 17,
                  onPressed: () => _flyTo(target),
                ),
              )
            : const SizedBox.shrink(key: ValueKey('none')),
      ),
    );
  }

  /// כל מה ש"עומד" על הקרקע - ממוקם וממוזער לפי ההקרנה, מהרחוק לקרוב.
  List<Widget> _billboards(BuildContext context, PlayerProfile profile, Size size, double target) {
    final p = _projection(size);
    final items = <(double, Widget)>[];

    void place({
      required String id,
      required double u,
      required double lateral,
      required double width,
      required double height,
      required double anchorY,
      required Widget child,
      bool keepOnScreen = false,
      double maxAhead = MapProjection.visibleAhead,
    }) {
      final rel = u - p.camera;
      if (rel < -MapProjection.visibleBehind || rel > maxAhead) return;
      var point = p.point(u, lateral);
      if (point.dx < -width || point.dx > size.width + width) return;
      final s = p.billboardScale(u);
      if (keepOnScreen) {
        final half = width * s / 2 + 4;
        point = Offset(point.dx.clamp(half, math.max(half, size.width - half)), point.dy);
      }
      // נמוג בעדינות לכיוון האופק.
      final fade = ((maxAhead - rel) / 420).clamp(0.0, 1.0);
      Widget body = Transform.scale(
        scale: s,
        alignment: Alignment(0, anchorY / height * 2 - 1),
        child: child,
      );
      if (fade < 1) body = Opacity(opacity: fade, child: body);
      items.add((
        u,
        Positioned(
          key: ValueKey(id),
          left: point.dx - width / 2,
          top: point.dy - anchorY,
          width: width,
          height: height,
          child: body,
        ),
      ));
    }

    final current = _layout.nodeFor(profile.highestUnlockedLevel);
    // זואי עומדת בצד שממנו השביל *לא* ממשיך, כדי לא להסתיר את השלב הבא.
    final next = _layout.nodes[math.min(current.level.levelNumber, _layout.nodes.length - 1)];
    final zoeySide = next.lateral >= current.lateral ? -1.0 : 1.0;
    final zoeyLateral = (current.lateral + zoeySide * 0.46).clamp(-0.92, 0.92);

    for (final node in _layout.nodes) {
      final level = node.level;
      final size = LevelNode.sizeFor(level);
      place(
        id: 'node-${level.levelNumber}',
        u: node.u,
        lateral: node.lateral,
        width: 124,
        height: 152,
        anchorY: 14 + size / 2,
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: LevelNode(
              config: level,
              progress: profile.progressFor(level.levelNumber),
              isUnlocked: profile.canPlayLevel(level.levelNumber),
              isNextToPlay: level.levelNumber == profile.highestUnlockedLevel && profile.canPlayLevel(level.levelNumber),
              onTap: () => context.push('/level/${level.levelNumber}/intro'),
              onLockedTap: () => _onLockedTap(profile, level.levelNumber),
            ),
          ),
        ),
      );

      // תווית "פרק N" ליד השלב הראשון של כל פרק, בצד הנגדי לשביל.
      if (CampaignChapters.isGateLevel(level.levelNumber)) {
        final chapter = CampaignChapters.chapterOf(level.levelNumber);
        place(
          id: 'chapter-$chapter',
          u: node.u + 0.5,
          lateral: node == current
              ? (current.lateral - zoeySide * 0.6).clamp(-0.95, 0.95)
              // בשלב הראשון של עולם - בצד החיצוני, כי בצד השני עומד שלט העולם.
              : ((level.levelNumber - 1) % CampaignLevels.levelsPerWorld == 0 ? _outsideLateral(node.lateral, 0.6) : _besideLateral(node.lateral, 0.6)),
          width: 104,
          height: 34,
          anchorY: 17,
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

      // החיות החוקרות של העולם - שתיים בכל עולם, ליד השביל.
      final inWorld = (level.levelNumber - 1) % CampaignLevels.levelsPerWorld;
      if ((inWorld == 3 || inWorld == 14) && node != current) {
        final theme = WorldTheme.of(level.tier.index);
        place(
          id: 'critter-${level.levelNumber}',
          u: node.u - 30,
          lateral: _besideLateral(node.lateral, 0.66),
          width: 70,
          height: 80,
          anchorY: 80,
          child: ExplorerCritter(kind: theme.explorer, ambient: _ambient, size: 70, phase: inWorld * 1.3),
        );
      }
    }

    // שלטי עולם ליד כל גשר.
    for (final river in _layout.rivers) {
      final firstNode = _layout.nodes.firstWhere((n) => n.u > river.u);
      final firstLevel = firstNode.level;
      place(
        id: 'sign-${river.toWorldIndex}',
        // שלט דרך בגדה הקרובה, ליד הגשר: "מכאן נכנסים לעולם הבא".
        u: river.u - CampaignMapLayout.riverHalfWidth - 20,
        lateral: firstNode.lateral >= 0 ? -0.62 : 0.62,
        keepOnScreen: true,
        width: 150,
        height: 118,
        anchorY: 118,
        child: Transform.scale(
          scale: 0.86,
          alignment: Alignment.bottomCenter,
          child: WorldSign(
            tier: firstLevel.tier,
            worldIndex: river.toWorldIndex,
            locked: !profile.isLevelUnlocked(firstLevel.levelNumber),
          ),
        ),
      );
    }

    // סוף הדרך: סולם לשמיים, ושלט "שלבים חדשים בדרך!" לצידו.
    place(
      id: 'sky-ladder',
      u: _layout.skyLadderU,
      lateral: 0,
      width: SkyLadder.width,
      height: SkyLadder.height,
      anchorY: SkyLadder.height - 8,
      // ציון דרך: הסולם לשמיים נראה מרחוק, כמו השמיים עצמם.
      maxAhead: 5200,
      child: SkyLadder(ambient: _ambient, onTap: _onLadderTap),
    );
    place(
      id: 'sky-ladder-sign',
      u: _layout.skyLadderU - 150,
      lateral: _layout.nodes.last.lateral >= 0 ? -0.6 : 0.6,
      keepOnScreen: true,
      width: LadderSign.width,
      height: LadderSign.height,
      anchorY: LadderSign.height,
      child: LadderSign(ambient: _ambient),
    );

    // זואי ליד השלב הבא, ומעליו הסיכה עם האוואטאר של השחקן/ית (אם בחרו אחר).
    place(
      id: 'zoey',
      u: current.u - 70,
      lateral: zoeyLateral,
      width: 84,
      height: 92,
      anchorY: 88,
      keepOnScreen: true,
      child: const ZoeyGuide(height: 92),
    );
    final photoUrl = ref.watch(authStateProvider).valueOrNull?.photoUrl;
    if (profile.avatarId != 'detective' || photoUrl != null) {
      final nodeSize = LevelNode.sizeFor(current.level);
      place(
        id: 'you',
        u: current.u - 1,
        lateral: current.lateral,
        width: 52,
        height: 66,
        anchorY: 66 + nodeSize / 2 + 4,
        child: IgnorePointer(child: _YouAreHereMarker(avatarId: profile.avatarId, photoUrl: photoUrl)),
      );
    }

    items.sort((a, b) => b.$1.compareTo(a.$1));
    return [for (final item in items) item.$2];
  }

  WorldTier _tierFor(int worldIndex) => WorldTier.values[worldIndex.clamp(0, WorldTier.values.length - 1)];

  /// מיקום צידי ליד שלב - בצד שפונה למרכז, כדי לא לכסות את השביל.
  double _besideLateral(double nodeLateral, double gap) =>
      (nodeLateral >= 0 ? nodeLateral - gap : nodeLateral + gap).clamp(-0.95, 0.95);

  double _outsideLateral(double nodeLateral, double gap) =>
      (nodeLateral >= 0 ? nodeLateral + gap : nodeLateral - gap).clamp(-0.95, 0.95);

  void _onLadderTap() {
    Haptics.medium();
    GameToast.show(
      context,
      message: 'עולם חדש בבנייה בשמיים! כשייפתח - מטפסים בסולם ✨',
      icon: Icons.cloud_rounded,
      color: const Color(0xFF7B3FF2),
    );
  }

  void _onLockedTap(PlayerProfile profile, int levelNumber) {
    Haptics.medium();
    if (profile.isBlockedByChapterGate(levelNumber)) {
      showChapterGateDialog(context, CampaignChapters.chapterOf(levelNumber));
      return;
    }
    GameToast.show(
      context,
      message: 'שלב $levelNumber עוד נעול - סיימו את שלב ${profile.highestUnlockedLevel} כדי להתקדם',
      icon: Icons.lock_rounded,
      color: const Color(0xFF7B3FF2),
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
