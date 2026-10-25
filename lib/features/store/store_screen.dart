import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/feedback/haptics.dart';
import '../../core/purchases/iap_controller.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/celebration_layer.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/platform/top_bar_tint.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import 'widgets/cosmetic_shop.dart';
import 'widgets/hint_offers.dart';
import 'widgets/premium_offers.dart';
import 'widgets/store_hero.dart';
import 'widgets/store_kit.dart';

/// חנות: רמזים במטבעות, עיצובים, ורכישה בכסף אמיתי באפליקציה.
///
/// עיצוב "כספת אוצר": רקע סגול מלכותי, באנר הצעות מתחלף בראש המסך, תמונות
/// תלת-ממד (Blender) שמרחפות, כרטיסים שנוטים לכיוון האצבע, וחגיגת מטבעות
/// וניצוצות בכל רכישה.
class StoreScreen extends ConsumerStatefulWidget {
  /// Analytics store_open source (e.g. home, home_coins, profile,
  /// level_no_coins) - passed as `/store?from=...`.
  final String source;

  const StoreScreen({super.key, this.source = 'other'});

  @override
  ConsumerState<StoreScreen> createState() => _StoreScreenState();
}

enum StoreTab { shop, cosmetics }

class _StoreScreenState extends ConsumerState<StoreScreen> {
  final _fx = GlobalKey<CelebrationLayerState>();
  StoreTab _tab = StoreTab.shop;

  /// חבילות הכסף האמיתי - באותו עמוד כמו הרמזים, מתחתיהם.
  final _premiumKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    ref.read(analyticsProvider).storeOpen(source: widget.source);
  }

  /// חגיגת רכישה במקום [at] (קואורדינטות גלובליות).
  void celebrate(Offset at, {bool coinRain = false}) {
    final fx = _fx.currentState;
    final box = context.findRenderObject() as RenderBox?;
    if (fx == null || box == null) return;
    final local = box.globalToLocal(at);
    fx
      ..flash(local, StorePalette.gold, radius: 160)
      ..shockwave(local, StorePalette.gold, radius: 170)
      ..sparks(local, const [StorePalette.gold, Colors.white, StorePalette.pink, Color(0xFF8E7CFF)], count: 26);
    if (coinRain) fx.coinShower(count: 36);
    Haptics.success();
  }

  void _openTab(StoreTab tab) => setState(() => _tab = tab);

  /// "צריכים עוד מטבעות?": עוברים לעמוד הרמזים והמטבעות וגוללים לחבילות.
  void _showPremium() {
    _openTab(StoreTab.shop);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // ממתינים לסיום מעבר הלשונית לפני הגלילה.
      Future<void>.delayed(const Duration(milliseconds: 300), () {
        final target = _premiumKey.currentContext;
        if (target == null || !target.mounted) return;
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOutCubic,
          alignment: 0.15,
        );
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(playerProfileProvider);
    final authUser = ref.watch(authStateProvider).valueOrNull;
    final isGuest = authUser == null || authUser.isAnonymous;

    ref.listen<IapState>(iapProvider, (previous, next) {
      final message = next.message;
      if (message == null || message == previous?.message) return;
      final granted = message.startsWith('נוספו');
      if (granted) {
        final size = MediaQuery.sizeOf(context);
        celebrate(Offset(size.width / 2, size.height * 0.45), coinRain: true);
        ref.read(soundServiceProvider).playCoin();
      }
      showStoreToast(context, message, success: granted);
    });

    return TopBarTint(
      color: StorePalette.vaultTop,
      child: Scaffold(
        backgroundColor: StorePalette.vaultTop,
        body: Stack(
          children: [
            Positioned.fill(
              child: GameBackdrop(
                colors: const [StorePalette.vaultTop, StorePalette.vaultMid, StorePalette.vaultBottom],
                child: const SizedBox.expand(),
              ),
            ),
            SafeArea(
              bottom: false,
              child: profileAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
                error: (e, st) => const Center(
                  child: Text('לא הצלחנו לטעון את הנתונים. נסו שוב.', style: TextStyle(color: Colors.white)),
                ),
                data: (profile) => CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: _StoreHeader(coins: profile.coins, hints: profile.hints, isGuest: isGuest),
                    ),
                    SliverToBoxAdapter(
                      child: StoreHero(isGuest: isGuest, onOpenTab: _openTab),
                    ),
                    SliverPersistentHeader(
                      pinned: true,
                      delegate: _TabBarDelegate(
                        selected: _tab,
                        onSelect: (tab) {
                          Haptics.selection();
                          ref.read(soundServiceProvider).playButtonTap();
                          _openTab(tab);
                        },
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(16, 8, 16, context.safeBottom(min: 24, extra: 16)),
                      sliver: SliverToBoxAdapter(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          switchInCurve: Curves.easeOutCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                              child: child,
                            ),
                          ),
                          child: KeyedSubtree(
                            key: ValueKey(_tab),
                            child: switch (_tab) {
                              StoreTab.shop => Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  HintOffers(
                                    profile: profile,
                                    isGuest: isGuest,
                                    onCelebrate: celebrate,
                                    onNeedCoins: _showPremium,
                                  ),
                                  const SizedBox(height: 22),
                                  KeyedSubtree(key: _premiumKey, child: const PremiumOffers()),
                                ],
                              ),
                              StoreTab.cosmetics => CosmeticShop(
                                profile: profile,
                                onCelebrate: celebrate,
                                onNeedCoins: _showPremium,
                              ),
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(child: CelebrationLayer(key: _fx)),
            ),
          ],
        ),
      ),
    );
  }
}

/// הודעה קצרה בתחתית, בסגנון החנות.
void showStoreToast(BuildContext context, String text, {bool success = true}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: success ? const Color(0xFF1FB86A) : AppColors.error,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
        duration: const Duration(seconds: 2),
      ),
    );
}

class _StoreHeader extends StatelessWidget {
  final int coins;
  final int hints;
  final bool isGuest;

  const _StoreHeader({required this.coins, required this.hints, required this.isGuest});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          CandyIconButton(
            icon: Icons.arrow_back_rounded,
            tooltip: 'חזרה',
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
          const SizedBox(width: 10),
          const _ShinyTitle('החנות'),
          const Spacer(),
          if (!isGuest) ...[
            _BalancePill(
              value: hints,
              icon: const Icon(Icons.lightbulb_rounded, color: StorePalette.gold, size: 18),
            ),
            const SizedBox(width: 6),
          ],
          _BalancePill(value: coins, icon: const CoinGlyph(size: 18)),
        ],
      ),
    );
  }
}

class _ShinyTitle extends StatelessWidget {
  final String text;

  const _ShinyTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      shaderCallback: (rect) =>
          const LinearGradient(colors: [Colors.white, Color(0xFFFFE9A8), Colors.white]).createShader(rect),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
          shadows: [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
        ),
      ),
    );
  }
}

/// יתרה עם "קפיצה" כשהערך משתנה.
class _BalancePill extends StatelessWidget {
  final int value;
  final Widget icon;

  const _BalancePill({required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 12, 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          icon,
          const SizedBox(width: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 1.6, end: 1.0).animate(CurvedAnimation(parent: anim, curve: Curves.elasticOut)),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: Text(
              '$value',
              key: ValueKey(value),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final StoreTab selected;
  final ValueChanged<StoreTab> onSelect;

  _TabBarDelegate({required this.selected, required this.onSelect});

  @override
  double get minExtent => 64;

  @override
  double get maxExtent => 64;

  @override
  bool shouldRebuild(_TabBarDelegate old) => old.selected != selected;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    final pinned = overlapsContent || shrinkOffset > 0;
    final bar = Container(
      color: pinned ? StorePalette.vaultTop.withValues(alpha: 0.72) : Colors.transparent,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: _SegmentedTabs(selected: selected, onSelect: onSelect),
    );
    if (!pinned) return bar;
    // זכוכית חלבית: התוכן שנגלל מתחת לא מתערבב עם הלשוניות.
    return ClipRect(
      child: BackdropFilter(filter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14), child: bar),
    );
  }
}

class _SegmentedTabs extends StatelessWidget {
  final StoreTab selected;
  final ValueChanged<StoreTab> onSelect;

  const _SegmentedTabs({required this.selected, required this.onSelect});

  static const _tabs = [
    (StoreTab.shop, 'רמזים ומטבעות', Icons.lightbulb_rounded),
    (StoreTab.cosmetics, 'עיצובים', Icons.palette_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere((t) => t.$1 == selected);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final step = 2 / (_tabs.length - 1);
    final x = -1 + index * step;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.28),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            alignment: Alignment(rtl ? -x : x, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _tabs.length,
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFFE27A), StorePalette.gold, StorePalette.goldDeep],
                  ),
                  boxShadow: [BoxShadow(color: StorePalette.gold.withValues(alpha: 0.5), blurRadius: 12)],
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final tab in _tabs)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onSelect(tab.$1),
                    child: SizedBox(
                      height: 40,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(tab.$3, size: 17, color: tab.$1 == selected ? const Color(0xFF5A2A00) : Colors.white70),
                          const SizedBox(width: 5),
                          Text(
                            tab.$2,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: tab.$1 == selected ? const Color(0xFF5A2A00) : Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// קרני אור מסתובבות לאט מאחורי תמונת ההצעה.
class LightRays extends StatefulWidget {
  final Color color;
  final double size;

  const LightRays({super.key, this.color = StorePalette.gold, this.size = 200});

  @override
  State<LightRays> createState() => _LightRaysState();
}

class _LightRaysState extends State<LightRays> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 18));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!_c.isAnimating) _c.repeat();
    } else {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(painter: _RaysPainter(_c.value * math.pi * 2, widget.color)),
      ),
    );
  }
}

class _RaysPainter extends CustomPainter {
  final double angle;
  final Color color;

  _RaysPainter(this.angle, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    final paint = Paint()
      ..shader = RadialGradient(
        colors: [color.withValues(alpha: 0.5), color.withValues(alpha: 0)],
      ).createShader(Rect.fromCircle(center: c, radius: r));
    const rays = 12;
    for (var i = 0; i < rays; i++) {
      final a = angle + i * math.pi * 2 / rays;
      final path = Path()
        ..moveTo(c.dx, c.dy)
        ..lineTo(c.dx + math.cos(a - 0.11) * r, c.dy + math.sin(a - 0.11) * r)
        ..lineTo(c.dx + math.cos(a + 0.11) * r, c.dy + math.sin(a + 0.11) * r)
        ..close();
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_RaysPainter old) => old.angle != angle || old.color != color;
}

/// כפתור "עוד מטבעות" שמופיע כשאין מספיק לקנייה.
class NeedCoinsHint extends StatelessWidget {
  final VoidCallback onTap;

  const NeedCoinsHint({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton.icon(
        onPressed: onTap,
        style: TextButton.styleFrom(foregroundColor: StorePalette.gold),
        icon: const Icon(Icons.add_circle_rounded),
        label: const Text('צריכים עוד מטבעות?', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

/// קנייה במטבעות עם משוב מלא: רכישה מוצלחת = חגיגה, חוסר = רעידה והודעה.
Future<bool> buyWithCoins({
  required BuildContext context,
  required WidgetRef ref,
  required Future<bool> Function() purchase,
  required GlobalKey<ShakeBoxState> shakeKey,
  required void Function(Offset at, {bool coinRain}) onCelebrate,
  required String successText,
  required VoidCallback onNeedCoins,
}) async {
  final ok = await purchase();
  if (!context.mounted) return ok;
  final sound = ref.read(soundServiceProvider);
  if (ok) {
    sound.playCoin();
    final box = shakeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box != null) onCelebrate(box.localToGlobal(box.size.center(Offset.zero)));
    showStoreToast(context, successText);
  } else {
    sound.playError();
    Haptics.error();
    shakeKey.currentState?.shake();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.error,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          content: const Text('אין מספיק מטבעות', style: TextStyle(fontWeight: FontWeight.w800)),
          action: SnackBarAction(label: 'להשיג עוד', textColor: Colors.white, onPressed: onNeedCoins),
          // עם כפתור, SnackBar נשאר עד שלוחצים - persist: false מחזיר היעלמות.
          persist: false,
          duration: const Duration(milliseconds: 1800),
        ),
      );
  }
  return ok;
}

/// טיימר להחלפה אוטומטית - לא בבדיקות ולא כשביקשו פחות תנועה.
Timer? periodicIfMotion(BuildContext context, Duration every, VoidCallback tick) {
  if (!AmbientMotion.enabledFor(context)) return null;
  return Timer.periodic(every, (_) => tick());
}
