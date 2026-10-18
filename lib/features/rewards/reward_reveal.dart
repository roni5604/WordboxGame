import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/feedback/haptics.dart';
import '../../core/motion/motion.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/celebration_layer.dart';
import '../../core/ui/rarity_style.dart';
import '../../game_engine/rewards/reward_tables.dart';
import '../../providers/sound_provider.dart';
import 'drop_visuals.dart';
import 'reward_widgets.dart';

/// איך נראית ההפתעה לפני הפתיחה.
enum DropVisual { giftBox, star }

/// מה יש בתוך ההפתעה - מקור אחיד לכל סוגי המתנות במשחק.
class RewardContents {
  final Rarity rarity;
  final int coins;
  final int hints;
  final int doubleCoinsLevels;

  /// כותרת קטנה מעל ("תיבת מזל", "בונוס יומי · יום 5"...).
  final String title;
  final DropVisual visual;

  const RewardContents({
    required this.rarity,
    required this.title,
    this.coins = 0,
    this.hints = 0,
    this.doubleCoinsLevels = 0,
    this.visual = DropVisual.giftBox,
  });

  factory RewardContents.fromLuckyBox(LuckyBoxReward r) => RewardContents(
        rarity: r.rarity,
        coins: r.coins,
        hints: r.hints,
        doubleCoinsLevels: r.doubleCoinsLevels,
        title: r.kind == DropKind.starDrop ? 'כוכב מזל' : 'תיבת מזל',
        visual: r.kind == DropKind.starDrop ? DropVisual.star : DropVisual.giftBox,
      );

  factory RewardContents.fromWheel(FortuneWheelPrize p) => RewardContents(
        rarity: p.rarity,
        coins: p.coins,
        hints: p.hints,
        doubleCoinsLevels: p.doubleCoinsLevels,
        title: 'גלגל המזל',
      );
}

/// המסך שבו פותחים מתנה - הרגע הכי "דופמיני" במשחק.
///
/// 1. ההפתעה נוחתת סגורה, בצבע "רגיל".
/// 2. כל לחיצה מכווצת ומקפיצה אותה, מרעידה את הטלפון ומשמיעה צליל שעולה;
///    בחלק מהלחיצות היא *עולה דרגה* - הבזק, גל הלם, צבע חדש, גודל גדול יותר
///    ותגית ("נדיר!"). מספר הלחיצות והעליות נקבע מראש לפי הדרגה הסופית.
/// 3. הלחיצה האחרונה פותחת: המכסה עף, הבזק, זיקוקים/קונפטי/גשם מטבעות לפי
///    הדרגה, ורטט חגיגי.
/// 4. כרטיס הפרס: המספרים "סופרים" למעלה, וכפתור האיסוף נדלק רק אחרי רגע
///    (כדי שלחיצה מהירה לא תסגור את החגיגה לפני שראו אותה).
///
/// כש-[charge] כבוי (גלגל המזל - שכבר בנה מתח) מדלגים ישר לפתיחה.
class RewardReveal extends ConsumerStatefulWidget {
  final RewardContents contents;
  final bool charge;
  final Rarity startRarity;
  final WidgetBuilder? extraAction;

  /// תוכן אופציונלי מתחת לכותרת (למשל מסלול 7 הימים של הבונוס היומי).
  final WidgetBuilder? header;
  final math.Random? random;

  const RewardReveal({
    super.key,
    required this.contents,
    this.charge = true,
    this.startRarity = Rarity.common,
    this.extraAction,
    this.header,
    this.random,
  });

  static Future<void> show(
    BuildContext context,
    RewardContents contents, {
    bool charge = true,
    Rarity startRarity = Rarity.common,
    WidgetBuilder? extraAction,
    WidgetBuilder? header,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: contents.title,
      barrierColor: const Color(0xD9100822),
      transitionDuration: Motion.standard,
      transitionBuilder: (context, a, _, child) => FadeTransition(opacity: CurvedAnimation(parent: a, curve: Motion.out), child: child),
      pageBuilder: (context, _, __) => RewardReveal(
        contents: contents,
        charge: charge,
        startRarity: startRarity,
        extraAction: extraAction,
        header: header,
      ),
    );
  }

  /// מסלול הדרגות לאורך הלחיצות: [0] = הדרגה בהתחלה, [i] = אחרי לחיצה i.
  /// עליות הדרגה מפוזרות אקראית, עם נטייה ללחיצות המאוחרות (מתח!), ואף
  /// לחיצה לא מקפיצה יותר משתי דרגות.
  static List<Rarity> chargePath(Rarity finalRarity, Rarity start, math.Random rnd) {
    final steps = math.max(0, finalRarity.index - start.index);
    final taps = steps.clamp(2, 4);
    final ups = List<int>.filled(taps, 0);
    for (var s = 0; s < steps; s++) {
      final open = [for (var i = 0; i < taps; i++) if (ups[i] < 2) i];
      // משקל גבוה יותר ללחיצות מאוחרות.
      final weights = [for (final i in open) 1 + i * 1.5];
      var roll = rnd.nextDouble() * weights.fold<double>(0, (a, b) => a + b);
      var pick = open.last;
      for (var k = 0; k < open.length; k++) {
        roll -= weights[k];
        if (roll <= 0) {
          pick = open[k];
          break;
        }
      }
      ups[pick]++;
    }
    final path = <Rarity>[start];
    var cur = start.index;
    for (final u in ups) {
      cur += u;
      path.add(Rarity.values[cur]);
    }
    return path;
  }

  @override
  ConsumerState<RewardReveal> createState() => _RewardRevealState();
}

enum _Phase { intro, charging, opening, revealed }

class _RewardRevealState extends ConsumerState<RewardReveal> with TickerProviderStateMixin {
  final _celebration = GlobalKey<CelebrationLayerState>();
  final _itemKey = GlobalKey();
  late final math.Random _rnd = widget.random ?? math.Random();

  late final List<Rarity> _path;
  int _taps = 0;
  _Phase _phase = _Phase.intro;
  // זמני הפריים (ולא שעון הקיר) - כך גם בבדיקות הזמן "זז" עם pump.
  Duration _lastTap = const Duration(days: -1);
  Duration _lastPop = const Duration(days: -1);
  Duration get _now => SchedulerBinding.instance.currentSystemFrameTimeStamp;
  bool _canCollect = false;
  bool _idleHint = false;

  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
  late final AnimationController _ambient = AnimationController(vsync: this, duration: const Duration(seconds: 12));
  late final AnimationController _punch = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _morph = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final AnimationController _flash = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));

  RarityStyle _from = RarityStyle.of(Rarity.common);
  RarityStyle _to = RarityStyle.of(Rarity.common);
  Rarity _shown = Rarity.common;
  int _badgeVersion = 0;

  int get _chargeTaps => _path.length - 1;
  bool get _reduced => Motion.reduced(context);

  @override
  void initState() {
    super.initState();
    _path = widget.charge
        ? RewardReveal.chargePath(widget.contents.rarity, widget.startRarity, _rnd)
        : [widget.contents.rarity];
    _shown = _path.first;
    _from = _to = RarityStyle.of(_shown);
    _ambient.repeat();
    _intro.forward().whenComplete(() {
      if (!mounted) return;
      if (widget.charge) {
        setState(() => _phase = _Phase.charging);
        _scheduleIdleHint();
      } else {
        _openNow();
      }
    });
    Haptics.light();
  }

  @override
  void dispose() {
    for (final c in [_intro, _ambient, _punch, _morph, _flash, _open]) {
      c.dispose();
    }
    super.dispose();
  }

  void _scheduleIdleHint() {
    final at = _taps;
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted && _phase == _Phase.charging && _taps == at) setState(() => _idleHint = true);
    });
  }

  Offset get _itemCenter {
    final box = _itemKey.currentContext?.findRenderObject() as RenderBox?;
    final layer = _celebration.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || layer == null || !box.hasSize) return MediaQuery.sizeOf(context).center(Offset.zero);
    return layer.globalToLocal(box.localToGlobal(box.size.center(Offset.zero)));
  }

  RarityStyle get _style {
    final t = Motion.out.transform(_morph.value);
    if (t >= 1) return _to;
    return RarityStyle(
      base: Color.lerp(_from.base, _to.base, t)!,
      light: Color.lerp(_from.light, _to.light, t)!,
      dark: Color.lerp(_from.dark, _to.dark, t)!,
      glow: Color.lerp(_from.glow, _to.glow, t)!,
      particles: _to.particles,
      intensity: _from.intensity + (_to.intensity - _from.intensity) * t,
      fireworks: _to.fireworks,
    );
  }

  void _onTap() {
    if (_phase != _Phase.charging) return;
    final now = _now;
    // לחיצות מהירות מדי נבלעות - כל לחיצה צריכה רגע "לנחות".
    if (now - _lastTap < const Duration(milliseconds: 230)) return;
    _lastTap = now;
    _idleHint = false;

    if (_taps >= _chargeTaps) {
      _openNow();
      return;
    }
    _taps++;
    final sound = ref.read(soundServiceProvider);
    final next = _path[_taps];
    final upgraded = next.index > _shown.index;
    _punch.forward(from: 0);
    if (upgraded) {
      _from = _style;
      _to = RarityStyle.of(next);
      _shown = next;
      _badgeVersion++;
      _morph.forward(from: 0);
      _flash.forward(from: 0);
      sound.playRarityUp();
      Haptics.upgrade(next);
      final c = _itemCenter;
      _celebration.currentState
        ?..shockwave(c, _to.glow, radius: 230, width: 12)
        ..sparks(c, _to.particles, count: 34, speed: 640, life: 0.75)
        ..flash(c, _to.light, radius: 240, life: 0.4);
    } else {
      sound.playCharge(_taps - 1);
      Haptics.charge(_taps - 1);
      _celebration.currentState?.sparks(_itemCenter, _to.particles, count: 12, speed: 380, life: 0.45);
    }
    setState(() {});
    _scheduleIdleHint();
  }

  Future<void> _openNow() async {
    if (_phase == _Phase.opening || _phase == _Phase.revealed) return;
    final rarity = widget.contents.rarity;
    setState(() {
      _phase = _Phase.opening;
      _idleHint = false;
      if (_shown != rarity) {
        _from = _style;
        _to = RarityStyle.of(rarity);
        _shown = rarity;
        _badgeVersion++;
        _morph.forward(from: 0);
      }
    });
    _punch.forward(from: 0);
    _open.forward(from: 0);
    await Future.delayed(const Duration(milliseconds: 260));
    if (!mounted) return;
    _flash.forward(from: 0);
    ref.read(soundServiceProvider).playReveal(rarity.index);
    Haptics.celebrate(rarity);
    _celebration.currentState?.celebrate(rarity, _itemCenter);
    setState(() => _phase = _Phase.revealed);
    // כפתור האיסוף נדלק רק אחרי שהחגיגה "נחתה".
    Future.delayed(Duration(milliseconds: 650 + 150 * rarity.index), () {
      if (mounted) setState(() => _canCollect = true);
    });
  }

  void _onFireworkPop() {
    final now = _now;
    if (now - _lastPop < const Duration(milliseconds: 140)) return;
    _lastPop = now;
    ref.read(soundServiceProvider).playFirework();
  }

  Future<void> _collect() async {
    if (!_canCollect) return;
    setState(() => _canCollect = false);
    ref.read(soundServiceProvider).playCollect();
    Haptics.success();
    await Future.delayed(const Duration(milliseconds: 180));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final itemSize = math.min(size.width * 0.56, math.min(230.0, size.height * 0.29));
    return PopScope(
      canPop: _phase == _Phase.revealed && _canCollect,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // כל המסך לחיץ בזמן הטעינה - מטרה ענקית לאצבע.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _onTap(),
              child: SafeArea(
                child: AnimatedBuilder(
                  animation: Listenable.merge([_intro, _ambient, _punch, _morph, _open]),
                  builder: (context, _) => _buildStage(itemSize),
                ),
              ),
            ),
            // הבזק לבן מלא-מסך בעליית דרגה ובפתיחה.
            IgnorePointer(
              child: AnimatedBuilder(
                animation: _flash,
                builder: (context, _) {
                  final v = _flash.value;
                  final a = v < 0.25 ? v / 0.25 : (1 - v) / 0.75;
                  return ColoredBox(color: Colors.white.withValues(alpha: (a * (_reduced ? 0.25 : 0.55)).clamp(0.0, 1.0)));
                },
              ),
            ),
            CelebrationLayer(key: _celebration, onFireworkPop: _onFireworkPop),
          ],
        ),
      ),
    );
  }

  Widget _buildStage(double itemSize) {
    final style = _style;
    final revealed = _phase == _Phase.revealed;
    final intro = Motion.backOut.transform(_intro.value);
    final open = _open.value;

    // "פאנץ'": כיווץ קצר, קפיצה מעל הגודל, ונחיתה - כמו לחיצה על כפתור גומי.
    final p = _punch.value;
    double punchScale;
    if (p < 0.15) {
      punchScale = 1 - 0.14 * (p / 0.15);
    } else if (p < 0.45) {
      punchScale = 0.86 + 0.3 * Motion.out.transform((p - 0.15) / 0.3);
    } else {
      punchScale = 1.16 - 0.16 * Motion.backOut.transform((p - 0.45) / 0.55);
    }
    final shake = _reduced ? 0.0 : math.sin(p * math.pi * 7) * (1 - p) * (0.08 + 0.04 * _taps);
    final bob = _reduced ? 0.0 : math.sin(_ambient.value * math.pi * 2 * 5) * 6;
    final tierGrow = 1 + 0.06 * _shown.index;
    final openScale = 1 + 0.35 * Motion.out.transform(open);
    final itemOpacity = revealed ? (1 - Motion.out.transform(((open - 0.25) / 0.5).clamp(0.0, 1.0))) : 1.0;
    final charge = _chargeTaps == 0 ? 0.0 : _taps / _chargeTaps;

    final item = Transform.translate(
      offset: Offset(0, -(1 - intro) * 420 + bob),
      child: Transform.rotate(
        angle: shake,
        child: Transform.scale(
          scale: (0.9 + 0.1 * intro) * punchScale * tierGrow * openScale,
          child: Opacity(
            opacity: (_intro.value * 3).clamp(0.0, 1.0) * itemOpacity,
            child: SizedBox(
              key: _itemKey,
              width: itemSize,
              height: itemSize,
              child: CustomPaint(
                painter: widget.contents.visual == DropVisual.star
                    ? StarDropPainter(style: style, shimmer: _ambient.value * 6, crack: charge)
                    : GiftBoxPainter(style: style, shimmer: _ambient.value * 6, crack: charge, lid: Motion.out.transform(open)),
              ),
            ),
          ),
        ),
      ),
    );

    final raysStrength = (0.25 + 0.75 * style.intensity) * (revealed ? 1 : 0.55 + 0.45 * charge) * _intro.value;

    return Column(
      children: [
        const SizedBox(height: 18),
        Text(
          widget.contents.title,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.9),
            fontSize: 20,
            fontWeight: FontWeight.w900,
            shadows: const [Shadow(color: Colors.black45, blurRadius: 8)],
          ),
        ).animate().fadeIn(duration: Motion.standard).slideY(begin: -0.4, curve: Motion.out),
        if (widget.header != null)
          AnimatedSize(
            duration: Motion.standard,
            curve: Motion.out,
            child: revealed ? const SizedBox(width: double.infinity) : Padding(padding: const EdgeInsets.only(top: 12), child: widget.header!(context)),
          ),
        const SizedBox(height: 10),
        SizedBox(
          height: 44,
          child: Center(
            child: KeyedSubtree(
              key: ValueKey(_badgeVersion),
              child: RarityBadge(rarity: _shown, fontSize: 19)
                  .animate()
                  .scaleXY(begin: _badgeVersion == 0 ? 0.9 : 0.5, end: 1, duration: 420.ms, curve: Motion.pop)
                  .fadeIn(duration: 160.ms),
            ),
          ),
        ),
        Expanded(
          flex: revealed ? 4 : 6,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: OverflowBox(
                  maxWidth: itemSize * 3.2,
                  maxHeight: itemSize * 3.2,
                  child: CustomPaint(
                    size: Size.square(itemSize * 3.2),
                    painter: RaysPainter(
                      color: style.glow,
                      rotation: _reduced ? 0 : _ambient.value * math.pi * 2,
                      strength: raysStrength,
                      count: 10 + _shown.index * 2,
                    ),
                  ),
                ),
              ),
              item,
            ],
          ),
        ),
        if (!revealed) _buildChargeHud() else Expanded(flex: 6, child: _buildCard()),
      ],
    );
  }

  Widget _buildChargeHud() {
    final remaining = _chargeTaps - _taps;
    final label = _phase == _Phase.intro
        ? ''
        : remaining <= 0
            ? 'עוד לחיצה - ופותחים!'
            : _taps == 0
                ? 'הקישו כדי לפתוח!'
                : 'עוד! הקישו שוב';
    return Padding(
      padding: const EdgeInsets.only(bottom: 48, top: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // נקודות התקדמות - כמה לחיצות נשארו (כולל הפתיחה).
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i <= _chargeTaps; i++)
                AnimatedContainer(
                  duration: Motion.quick,
                  curve: Motion.out,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  width: i < _taps ? 22 : 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: i < _taps ? RarityStyle.of(_path[i + 1 < _path.length ? i + 1 : _path.length - 1]).light : Colors.white24,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white54, width: 1.5),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          AnimatedSwitcher(
            duration: Motion.quick,
            child: Row(
              key: ValueKey(label),
              mainAxisSize: MainAxisSize.min,
              children: [
                if (label.isNotEmpty)
                  const Icon(Icons.touch_app_rounded, color: Colors.white, size: 26)
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .moveY(begin: 0, end: -5, duration: 520.ms, curve: Curves.easeInOut),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.fade,
                    style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
          )
              .animate(target: _idleHint ? 1 : 0)
              .scaleXY(end: 1.12, duration: 300.ms, curve: Motion.backOut),
        ],
      ),
    );
  }

  Widget _buildCard() {
    final c = widget.contents;
    final s = RarityStyle.of(c.rarity);
    final items = <Widget>[
      if (c.coins > 0) _RewardItem(icon: Icons.monetization_on_rounded, color: const Color(0xFFFFB800), value: c.coins, label: 'מטבעות'),
      if (c.hints > 0) _RewardItem(icon: Icons.lightbulb_rounded, color: const Color(0xFFFFD84D), value: c.hints, label: c.hints == 1 ? 'רמז' : 'רמזים'),
      if (c.doubleCoinsLevels > 0)
        _RewardItem(icon: Icons.bolt_rounded, color: const Color(0xFFB04DFF), value: c.doubleCoinsLevels, label: 'שלבים x2', prefix: ''),
    ];
    return SingleChildScrollView(
      physics: const ClampingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _headline(c.rarity),
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 30,
              fontWeight: FontWeight.w900,
              shadows: [Shadow(color: s.glow, blurRadius: 18), const Shadow(color: Colors.black54, offset: Offset(0, 3))],
            ),
          ).animate().fadeIn(duration: 200.ms).scaleXY(begin: 0.7, curve: Motion.pop, duration: 520.ms),
          const SizedBox(height: 18),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < items.length; i++)
                items[i]
                    .animate(delay: (180 + i * 110).ms)
                    .fadeIn(duration: 200.ms)
                    .slideY(begin: 0.35, curve: Motion.out, duration: 420.ms)
                    .scaleXY(begin: 0.85, curve: Motion.backOut, duration: 420.ms),
            ],
          ),
          const SizedBox(height: 26),
          AnimatedOpacity(
            opacity: _canCollect ? 1 : 0,
            duration: Motion.standard,
            curve: Motion.out,
            child: AnimatedSlide(
              offset: _canCollect ? Offset.zero : const Offset(0, 0.3),
              duration: Motion.emphasis,
              curve: Motion.out,
              child: Column(
                children: [
                  CandyButton(
                    label: 'אספו!',
                    icon: Icons.check_rounded,
                    palette: CandyPalette.gold,
                    height: 62,
                    fontSize: 22,
                    onPressed: _canCollect ? _collect : null,
                  ),
                  if (widget.extraAction != null) ...[
                    const SizedBox(height: 12),
                    widget.extraAction!(context),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _headline(Rarity r) => switch (r) {
        Rarity.common => 'יש!',
        Rarity.uncommon => 'יפה מאוד!',
        Rarity.rare => 'וואו! נדיר!',
        Rarity.epic => 'אפי!!',
        Rarity.legendary => 'אגדי!!!',
      };
}

class _RewardItem extends StatelessWidget {
  final IconData icon;
  final Color color;
  final int value;
  final String label;
  final String prefix;

  const _RewardItem({required this.icon, required this.color, required this.value, required this.label, this.prefix = '+'});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 104,
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.55), blurRadius: 18),
          const BoxShadow(color: Color(0x33000000), offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [Color.lerp(color, Colors.white, 0.45)!, color]),
            ),
            child: Icon(icon, color: Colors.white, size: 28, shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 1))]),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: CountUpText(
              value: value,
              prefix: prefix,
              delay: 250.ms,
              style: const TextStyle(color: Color(0xFF2B2440), fontSize: 26, fontWeight: FontWeight.w900, height: 1.1),
            ),
          ),
          Text(label, style: const TextStyle(color: Color(0xFF6B6385), fontSize: 13, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
