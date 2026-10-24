import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/feedback/haptics.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/ui/game_backdrop.dart';
import '../../../game_engine/scoring.dart';
import '../../game/widgets/connector_painter.dart';
import '../../game/widgets/letter_tile.dart';

/// ההדגמות החיות של מסך חוקי המשחק. כל הדגמה היא "במה" קטנה: חלקן
/// אינטראקטיביות (גוררים, נוגעים, בוחרים) וחלקן אנימציה שחוזרת בלולאה.
/// הניקוד והספים לקוחים מהמנוע עצמו (scoring.dart), כך שההסבר תמיד מדויק.

/// שעון לולאה משותף להדגמות. בבדיקות ובהפחתת תנועה - עומד במקום.
mixin _LoopClock<T extends StatefulWidget> on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController loop = AnimationController(vsync: this, duration: loopDuration);

  Duration get loopDuration;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!loop.isAnimating) loop.repeat();
    } else {
      loop
        ..stop()
        ..value = 0.999;
    }
  }

  @override
  void dispose() {
    loop.dispose();
    super.dispose();
  }
}

/// מעבר חלק 0..1 בין [from] ל-[to] בתוך מחזור הלולאה.
double _phase(double t, double from, double to) => ((t - from) / (to - from)).clamp(0.0, 1.0);

// ---------------------------------------------------------------- 1. גרירה

/// לוח 3×3 אמיתי: גוררים אצבע בין אותיות שכנות ומרכיבים מילה. אצבע
/// "רפאים" מדגימה עד שמתחילים לגעת.
class TraceWordDemo extends StatefulWidget {
  final double tileSize;

  const TraceWordDemo({super.key, this.tileSize = 62});

  static const letters = ['ב', 'י', 'ת', 'ל', 'ד', 'א', 'מ', 'ש', 'ה'];
  static const words = {'ילד', 'בית', 'דלי', 'ביד', 'ידה'};

  /// "ילד": י (0,1) → ל (1,0) → ד (1,1) - כולל אלכסון.
  static const hintPath = [1, 3, 4];

  @override
  State<TraceWordDemo> createState() => _TraceWordDemoState();
}

class _TraceWordDemoState extends State<TraceWordDemo> with SingleTickerProviderStateMixin, _LoopClock<TraceWordDemo> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 2600);

  final _path = <int>[];
  bool _touched = false;
  bool? _result;
  String _found = '';

  double get _gap => widget.tileSize * 0.22;
  double get _cell => widget.tileSize + _gap;
  double get _side => _cell * 3 - _gap;

  Offset _center(int i) => Offset((i % 3) * _cell + widget.tileSize / 2, (i ~/ 3) * _cell + widget.tileSize / 2);

  int? _hit(Offset local) {
    for (var i = 0; i < 9; i++) {
      if ((local - _center(i)).distance < widget.tileSize * 0.46) return i;
    }
    return null;
  }

  bool _adjacent(int a, int b) => (a % 3 - b % 3).abs() <= 1 && (a ~/ 3 - b ~/ 3).abs() <= 1;

  /// בלוח RTL העמודה הראשונה מימין - ממפים את מיקום האצבע בהתאם.
  Offset _toGrid(Offset local) => Offset(_side - local.dx, local.dy);

  void _onStart(Offset local) {
    final i = _hit(_toGrid(local));
    setState(() {
      _touched = true;
      _result = null;
      _path
        ..clear()
        ..addAll([?i]);
    });
    if (i != null) Haptics.tile(0);
  }

  void _onMove(Offset local) {
    final i = _hit(_toGrid(local));
    if (i == null || _path.isEmpty || i == _path.last) return;
    if (_path.length > 1 && i == _path[_path.length - 2]) {
      setState(() => _path.removeLast());
      return;
    }
    if (_path.contains(i) || !_adjacent(i, _path.last)) return;
    setState(() => _path.add(i));
    Haptics.tile(_path.length - 1);
  }

  void _onEnd() {
    if (_path.isEmpty) return;
    final word = _path.map((i) => TraceWordDemo.letters[i]).join();
    final ok = TraceWordDemo.words.contains(word);
    setState(() {
      _result = ok;
      _found = word;
    });
    ok ? Haptics.success() : Haptics.error();
    Future<void>.delayed(const Duration(milliseconds: 1100), () {
      if (mounted && _found == word) setState(() => _path.clear());
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.tileSize;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: _side,
          height: _side,
          // אירועי האצבע נקראים ישירות (Listener), וה-GestureDetector "תופס"
          // את המחווה כדי שהדף לא יגלוש הצידה בזמן שמחברים אותיות.
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {},
            onPanUpdate: (_) {},
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e) => _onStart(e.localPosition),
              onPointerMove: (e) => _onMove(e.localPosition),
              onPointerUp: (_) => _onEnd(),
              onPointerCancel: (_) => _onEnd(),
              child: AnimatedBuilder(
                animation: loop,
                builder: (context, _) {
                  // אצבע הרפאים: עד הנגיעה הראשונה מדגימה את "ילד".
                  final ghost = !_touched;
                  final t = loop.value;
                  final hint = TraceWordDemo.hintPath;
                  final shown = ghost ? (_phase(t, 0.1, 0.75) * (hint.length - 1)).floor() + (t > 0.1 ? 1 : 0) : 0;
                  final ghostPath = ghost ? hint.take(shown.clamp(0, hint.length)).toList() : <int>[];
                  final active = ghost ? ghostPath : _path;
                  final points = [for (final i in active) _flip(_center(i))];
                  Offset? finger;
                  if (ghost && t > 0.05 && t < 0.85) {
                    final p = _phase(t, 0.1, 0.75) * (hint.length - 1);
                    final k = p.floor().clamp(0, hint.length - 2);
                    final f = p - k;
                    finger = Offset.lerp(_flip(_center(hint[k])), _flip(_center(hint[k + 1])), f);
                    // הקו נמשך אחרי אצבע הרפאים, כמו במשחק.
                    if (points.isNotEmpty && f > 0 && f < 1) points.add(finger!);
                  }
                  final state = _result == null
                      ? TileVisualState.selected
                      : (_result! ? TileVisualState.success : TileVisualState.error);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: [
                      // הקו מתחת לאריחים, כדי שהאותיות יישארו קריאות.
                      Positioned.fill(
                        child: IgnorePointer(
                          child: CustomPaint(
                            painter: ConnectorPainter(points: points, isError: _result == false),
                          ),
                        ),
                      ),
                      for (var i = 0; i < 9; i++)
                        Positioned(
                          left: _flip(_center(i)).dx - size / 2,
                          top: _center(i).dy - size / 2,
                          child: LetterTile(
                            letter: TraceWordDemo.letters[i],
                            size: size,
                            state: active.contains(i) ? state : TileVisualState.idle,
                          ),
                        ),
                      if (finger != null)
                        Positioned(
                          left: finger.dx - 4,
                          top: finger.dy - 2,
                          child: const IgnorePointer(child: _GhostFinger()),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: _ResultChip(
            key: ValueKey('$_result$_found'),
            text: switch (_result) {
              null => _touched ? 'גררו בין אותיות שכנות' : 'נסו בעצמכם: גררו את האצבע',
              true => '$_found ✓  +${scoreForWord(_found)} נקודות',
              false => '$_found ✗  לא מילה - נסו "ילד" או "בית"',
            },
            color: switch (_result) {
              null => const Color(0xFF6C5CE7),
              true => AppColors.success,
              false => AppColors.error,
            },
          ),
        ),
      ],
    );
  }

  /// מיקום על המסך (RTL): מימין לשמאל.
  Offset _flip(Offset p) => Offset(_side - p.dx, p.dy);
}

class _GhostFinger extends StatelessWidget {
  const _GhostFinger();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.85),
        border: Border.all(color: const Color(0xFF6C5CE7), width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: const Icon(Icons.touch_app_rounded, color: Color(0xFF6C5CE7), size: 20),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String text;
  final Color color;

  const _ResultChip({super.key, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 15),
      ),
    );
  }
}

// ---------------------------------------------------------------- 2. בלי חזרה

/// האצבע הולכת א → ב → ושוב לא' - והמשבצת מאדימה עם ✕.
class NoRepeatDemo extends StatefulWidget {
  const NoRepeatDemo({super.key});

  @override
  State<NoRepeatDemo> createState() => _NoRepeatDemoState();
}

class _NoRepeatDemoState extends State<NoRepeatDemo> with SingleTickerProviderStateMixin, _LoopClock<NoRepeatDemo> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3200);

  static const _letters = ['א', 'ב', 'א'];

  @override
  Widget build(BuildContext context) {
    const size = 62.0;
    const gap = 22.0;
    const width = size * 3 + gap * 2;
    Offset center(int i) => Offset(width - (i * (size + gap) + size / 2), size / 2 + 26);
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final toB = _phase(t, 0.08, 0.3);
        final back = _phase(t, 0.42, 0.62);
        final bad = t > 0.62;
        final points = <Offset>[center(0)];
        if (toB > 0) points.add(Offset.lerp(center(0), center(1), toB)!);
        if (back > 0) points.add(Offset.lerp(center(1), center(0), back)!.translate(0, -20 * math.sin(back * math.pi)));
        final shake = bad ? math.sin(t * 90) * 6 * (1 - _phase(t, 0.62, 0.9)) : 0.0;
        return SizedBox(
          width: width,
          height: size + 90,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // הקו מתחת לאריחים, כדי שהאותיות יישארו קריאות.
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: ConnectorPainter(points: points, isError: bad),
                  ),
                ),
              ),
              for (var i = 0; i < 3; i++)
                Positioned(
                  left: center(i).dx - size / 2 + (i == 0 ? shake : 0),
                  top: center(i).dy - size / 2,
                  child: LetterTile(
                    letter: _letters[i],
                    size: size,
                    state: i == 0
                        ? (bad ? TileVisualState.error : TileVisualState.selected)
                        : (i == 1 && toB >= 1
                              ? (bad ? TileVisualState.error : TileVisualState.selected)
                              : TileVisualState.idle),
                  ),
                ),
              if (bad)
                Positioned(
                  left: center(0).dx - 20,
                  top: center(0).dy - size / 2 - 40,
                  child: Transform.scale(
                    scale: Curves.elasticOut.transform(_phase(t, 0.62, 0.8)),
                    child: const _Badge(icon: Icons.close_rounded, color: AppColors.error),
                  ),
                ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Center(
                  child: Opacity(
                    opacity: _phase(t, 0.64, 0.72),
                    child: const _ResultChip(text: 'אותה משבצת פעמיים ✗', color: AppColors.error),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final Color color;

  const _Badge({required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 10)],
      ),
      child: Icon(icon, color: Colors.white, size: 24),
    );
  }
}

// ---------------------------------------------------------------- 3. מילים אמיתיות

/// שני קלפים: נוגעים כדי להפוך ולגלות אם זו מילה במילון.
class RealWordDemo extends StatefulWidget {
  const RealWordDemo({super.key});

  @override
  State<RealWordDemo> createState() => _RealWordDemoState();
}

class _RealWordDemoState extends State<RealWordDemo> {
  final _flipped = <int>{};

  static const _cards = [('שמש', true), ('שמק', false), ('ספר', true)];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < _cards.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  setState(() => _flipped.contains(i) ? _flipped.remove(i) : _flipped.add(i));
                  _cards[i].$2 ? Haptics.success() : Haptics.error();
                },
                child: _FlipCard(word: _cards[i].$1, valid: _cards[i].$2, flipped: _flipped.contains(i)),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        const _ResultChip(text: 'געו בקלף כדי לבדוק במילון', color: Color(0xFF6C5CE7)),
      ],
    );
  }
}

class _FlipCard extends StatelessWidget {
  final String word;
  final bool valid;
  final bool flipped;

  const _FlipCard({required this.word, required this.valid, required this.flipped});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? 1 : 0),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutBack,
      builder: (context, v, _) {
        final angle = v * math.pi;
        final back = angle > math.pi / 2;
        final face = back
            ? _CardFace(
                colors: valid
                    ? const [Color(0xFF5BE3B0), Color(0xFF1FB86A)]
                    : const [Color(0xFFFF8A80), Color(0xFFF2463D)],
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(valid ? Icons.check_circle_rounded : Icons.cancel_rounded, color: Colors.white, size: 34),
                    const SizedBox(height: 4),
                    Text(
                      valid ? 'במילון' : 'לא מילה',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 13),
                    ),
                  ],
                ),
              )
            : _CardFace(
                colors: const [Colors.white, Color(0xFFF1ECFF)],
                child: Text(
                  word,
                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w900, fontSize: 24),
                ),
              );
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0015)
            ..rotateY(angle),
          child: back
              ? Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi), child: face)
              : face,
        );
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  final List<Color> colors;
  final Widget child;

  const _CardFace({required this.colors, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 92,
      height: 118,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 14, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

// ---------------------------------------------------------------- 4. סופיות

/// מ → ל → כ, ואז המילה "מלכ" הופכת ל"מלך" בהיפוך של האות האחרונה.
class SofitDemo extends StatefulWidget {
  const SofitDemo({super.key});

  @override
  State<SofitDemo> createState() => _SofitDemoState();
}

class _SofitDemoState extends State<SofitDemo> with SingleTickerProviderStateMixin, _LoopClock<SofitDemo> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 3600);

  @override
  Widget build(BuildContext context) {
    const size = 60.0;
    const gap = 20.0;
    const width = size * 3 + gap * 2;
    Offset center(int i) => Offset(width - (i * (size + gap) + size / 2), size / 2);
    const letters = ['מ', 'ל', 'כ'];
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final drawn = _phase(t, 0.05, 0.4) * 2;
        final points = <Offset>[center(0)];
        for (var i = 0; i < 2; i++) {
          final f = (drawn - i).clamp(0.0, 1.0);
          if (f > 0) points.add(Offset.lerp(center(i), center(i + 1), f)!);
        }
        final morph = _phase(t, 0.5, 0.72);
        final angle = morph * math.pi;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: width,
              height: size,
              child: Stack(
                children: [
                  // הקו מתחת לאריחים, כדי שהאותיות יישארו קריאות.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(painter: ConnectorPainter(points: points)),
                    ),
                  ),
                  for (var i = 0; i < 3; i++)
                    Positioned(
                      left: center(i).dx - size / 2,
                      top: 0,
                      child: LetterTile(
                        letter: letters[i],
                        size: size,
                        state: drawn >= i ? TileVisualState.selected : TileVisualState.idle,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Icon(Icons.arrow_downward_rounded, color: Colors.black.withValues(alpha: 0.3)),
            const SizedBox(height: 8),
            Opacity(
              opacity: _phase(t, 0.38, 0.46),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  color: morph >= 1 ? AppColors.success : const Color(0xFF6C5CE7),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('מל', style: _chipStyle),
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.003)
                        ..rotateX(angle),
                      child: Text(angle > math.pi / 2 ? 'ך' : 'כ', style: _chipStyle),
                    ),
                    if (morph >= 1) const Text('  ✓', style: _chipStyle),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static const _chipStyle = TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24);
}

// ---------------------------------------------------------------- 5. אורך = ניקוד

/// בוחרים אורך מילה ורואים כמה נקודות היא שווה - גרף עמודות חי.
class LengthScoreDemo extends StatefulWidget {
  const LengthScoreDemo({super.key});

  @override
  State<LengthScoreDemo> createState() => _LengthScoreDemoState();
}

class _LengthScoreDemoState extends State<LengthScoreDemo> {
  int _selected = 5;

  static const _lengths = [2, 3, 4, 5, 6, 7];

  @override
  Widget build(BuildContext context) {
    final maxScore = scoreForWordLength(_lengths.last);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(end: scoreForWordLength(_selected).toDouble()),
          duration: const Duration(milliseconds: 500),
          builder: (context, v, _) => Text(
            '+${v.round()} נקודות',
            style: const TextStyle(color: AppColors.textDark, fontSize: 30, fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 130,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (final len in _lengths)
                GestureDetector(
                  onTap: () {
                    Haptics.selection();
                    setState(() => _selected = len);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          '${scoreForWordLength(len)}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: len == _selected ? const Color(0xFF6C5CE7) : Colors.black45,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 420),
                          curve: Curves.easeOutBack,
                          width: 34,
                          height: 12 + 86 * scoreForWordLength(len) / maxScore,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: len == _selected
                                  ? const [Color(0xFFFFE27A), Color(0xFFFF9F1C)]
                                  : const [Color(0xFFD9D2F5), Color(0xFFB9AEE8)],
                            ),
                            boxShadow: len == _selected
                                ? [BoxShadow(color: const Color(0xFFFF9F1C).withValues(alpha: 0.5), blurRadius: 12)]
                                : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final len in _lengths)
              SizedBox(
                width: 44,
                child: Text(
                  '$len',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: len == _selected ? const Color(0xFF6C5CE7) : Colors.black54,
                  ),
                ),
              ),
          ],
        ),
        const Text(
          'אותיות במילה - געו בעמודה',
          style: TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 6. אותיות קשות

/// "קפה": 3 נקודות על האורך + 1 לכל אות קשה (ק, פ) = 5. בוחרים מילה ורואים פירוט.
class HardLettersDemo extends StatefulWidget {
  const HardLettersDemo({super.key});

  @override
  State<HardLettersDemo> createState() => _HardLettersDemoState();
}

class _HardLettersDemoState extends State<HardLettersDemo> {
  String _word = 'קפה';

  static const _options = ['קפה', 'בית', 'צבע'];

  @override
  Widget build(BuildContext context) {
    final base = scoreForWordLength(_word.length);
    final bonus = HardLetters.bonusFor(_word);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final ch in _word.split(''))
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey('$_word$ch'),
                  tween: Tween(begin: 0.4, end: 1),
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.elasticOut,
                  builder: (context, s, child) => Transform.scale(scale: s, child: child),
                  child: LetterTile(letter: ch, size: 58, hard: HardLetters.isHard(ch)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ScorePart(label: 'אורך', value: '$base', color: const Color(0xFF6C5CE7)),
            const Text('  +  ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            _ScorePart(label: 'אותיות קשות', value: '$bonus', color: const Color(0xFF9B5CF6)),
            const Text('  =  ', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20)),
            _ScorePart(label: 'סה״כ', value: '${base + bonus}', color: AppColors.success),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final w in _options)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  label: Text(w, style: const TextStyle(fontWeight: FontWeight.w900)),
                  selected: w == _word,
                  onSelected: (_) {
                    Haptics.selection();
                    setState(() => _word = w);
                  },
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _ScorePart extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _ScorePart({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
          child: Container(
            key: ValueKey(value),
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 8, offset: const Offset(0, 3))],
            ),
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black54),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------- 7. טיימר

/// פס זמן שמתרוקן ומאדים כשנשאר פחות מ-20%.
class TimerDemo extends StatefulWidget {
  const TimerDemo({super.key});

  @override
  State<TimerDemo> createState() => _TimerDemoState();
}

class _TimerDemoState extends State<TimerDemo> with SingleTickerProviderStateMixin, _LoopClock<TimerDemo> {
  @override
  Duration get loopDuration => const Duration(seconds: 6);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final left = 1 - _phase(loop.value, 0.05, 0.92);
        final danger = left < 0.2;
        final color = danger ? AppColors.error : Color.lerp(AppColors.success, const Color(0xFFFFB300), 1 - left)!;
        final seconds = (left * 90).ceil();
        final wobble = danger ? math.sin(loop.value * 120) * 0.12 : 0.0;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.rotate(
              angle: wobble,
              child: Icon(Icons.alarm_rounded, size: 64, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              '0:${seconds.toString().padLeft(2, '0')}',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(height: 12),
            Container(
              width: 250,
              height: 22,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: AlignmentDirectional.centerStart,
              child: FractionallySizedBox(
                widthFactor: left.clamp(0.02, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9),
                    gradient: LinearGradient(colors: [color.withValues(alpha: 0.75), color]),
                    boxShadow: danger ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 10)] : null,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            AnimatedOpacity(
              opacity: danger ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: const _ResultChip(text: 'פחות מ-20% - מהרו!', color: AppColors.error),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 8. כוכבים

/// הניקוד מטפס אל היעד; בכל שליש נדלק כוכב.
class StarsDemo extends StatefulWidget {
  const StarsDemo({super.key});

  @override
  State<StarsDemo> createState() => _StarsDemoState();
}

class _StarsDemoState extends State<StarsDemo> with SingleTickerProviderStateMixin, _LoopClock<StarsDemo> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 5200);

  static const _goal = 30;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final p = Curves.easeInOut.transform(_phase(loop.value, 0.05, 0.8));
        final score = (p * _goal).round();
        final stars = (score * 3 / _goal).floor().clamp(0, 3);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 3; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedScale(
                      scale: i < stars ? (i == 1 ? 1.25 : 1.05) : 0.8,
                      duration: const Duration(milliseconds: 420),
                      curve: Curves.elasticOut,
                      child: Icon(
                        Icons.star_rounded,
                        size: i == 1 ? 72 : 56,
                        color: i < stars ? AppColors.star : Colors.black.withValues(alpha: 0.12),
                        shadows: i < stars
                            ? [Shadow(color: AppColors.star.withValues(alpha: 0.8), blurRadius: 18)]
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$score / $_goal נקודות',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.textDark),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: 250,
              height: 20,
              child: Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  FractionallySizedBox(
                    alignment: AlignmentDirectional.centerStart,
                    widthFactor: p.clamp(0.0, 1.0),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: const LinearGradient(colors: [Color(0xFFFFE27A), Color(0xFFFF9F1C)]),
                      ),
                    ),
                  ),
                  for (final k in const [1 / 3, 2 / 3])
                    Align(
                      alignment: AlignmentDirectional(k * 2 - 1, 0),
                      child: Container(width: 3, height: 20, color: Colors.white),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'כל שליש מהיעד = כוכב. כוכב אחד פותח את השלב הבא',
              style: TextStyle(color: Colors.black54, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 9. פרקים

/// הכוכבים מתמלאים, והמנעול של הפרק הבא נפתח.
class ChapterGateDemo extends StatefulWidget {
  const ChapterGateDemo({super.key});

  @override
  State<ChapterGateDemo> createState() => _ChapterGateDemoState();
}

class _ChapterGateDemoState extends State<ChapterGateDemo>
    with SingleTickerProviderStateMixin, _LoopClock<ChapterGateDemo> {
  @override
  Duration get loopDuration => const Duration(milliseconds: 4200);

  static const _need = 9;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = loop.value;
        final have = (_phase(t, 0.05, 0.55) * _need).floor();
        final open = _phase(t, 0.6, 0.75);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < 5; i++)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [Color(0xFFFFB259), Color(0xFFFF7A45)]),
                      boxShadow: const [BoxShadow(color: Color(0xFFC94A1C), offset: Offset(0, 3))],
                    ),
                    child: Text(
                      '${i + 1}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.star_rounded, color: AppColors.star, size: 30),
                const SizedBox(width: 4),
                Text(
                  '$have / $_need',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textDark),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Transform.scale(
              scale: 1 + 0.25 * math.sin(open * math.pi),
              child: Container(
                height: 64,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: LinearGradient(
                    colors: open >= 1
                        ? const [Color(0xFF5BE3B0), Color(0xFF1FB86A)]
                        : const [Color(0xFFB57BFF), Color(0xFF7B3FF2)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (open >= 1 ? const Color(0xFF1FB86A) : const Color(0xFF7B3FF2)).withValues(alpha: 0.5),
                      blurRadius: 14,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(open >= 0.5 ? Icons.lock_open_rounded : Icons.lock_rounded, color: Colors.white, size: 26),
                    const SizedBox(width: 6),
                    const Text(
                      'פרק 2',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- 10. תחרות

/// שלושה משתתפים על אותו לוח: עמודות הניקוד רצות, והמילים של היריבים מוסתרות.
class RaceDemo extends StatefulWidget {
  const RaceDemo({super.key});

  @override
  State<RaceDemo> createState() => _RaceDemoState();
}

class _RaceDemoState extends State<RaceDemo> with SingleTickerProviderStateMixin, _LoopClock<RaceDemo> {
  @override
  Duration get loopDuration => const Duration(seconds: 6);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: loop,
      builder: (context, _) {
        final t = _phase(loop.value, 0.05, 0.9);
        double ease(double speed, double wiggle) => (t * speed + math.sin(t * 9 + wiggle) * 0.04).clamp(0.0, 1.0);
        final rows = [
          ('את/ה', ease(1.0, 0), const Color(0xFFFF7A45), true),
          ('עומר', ease(0.82, 1.4), const Color(0xFF2E8BFF), false),
          ('נועה', ease(0.7, 2.6), const Color(0xFF9B5CF6), false),
        ];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 54,
                      child: Text(r.$1, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
                    ),
                    Container(
                      width: 170,
                      height: 26,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.07),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      alignment: AlignmentDirectional.centerStart,
                      child: FractionallySizedBox(
                        widthFactor: math.max(0.08, r.$2),
                        child: Container(
                          decoration: BoxDecoration(
                            color: r.$3,
                            borderRadius: BorderRadius.circular(13),
                            boxShadow: [BoxShadow(color: r.$3.withValues(alpha: 0.4), blurRadius: 6)],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 56,
                      child: Text(
                        r.$4 ? '${(r.$2 * 42).round()} נק׳' : '•••',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          color: r.$4 ? AppColors.textDark : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const _ResultChip(text: 'אותו לוח לכולם · המילים של היריבים סודיות', color: Color(0xFF2E8BFF)),
          ],
        );
      },
    );
  }
}
