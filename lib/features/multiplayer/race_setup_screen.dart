import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/haptics.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../game_engine/bot_player.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/letter_tile.dart';
import '../profile/avatars/avatar_catalog.dart';
import '../profile/widgets/avatar_widget.dart';
import 'models/race_config.dart';

const _botNamePool = ['עומר', 'נועה', 'דנה', 'יובל', 'טל', 'מאיה', 'איתי', 'שירה'];

/// "שחק נגד המחשב": מסך אחד בלי גלילה. למעלה זירה - זואי הבלשית מול
/// הרובוטים היריבים (מספרם, צבעם והבעתם משתנים לפי הבחירה), ולמטה כרטיס
/// הגדרות קומפקטי עם בוררים מחליקים, וכפתור "בואו נתחרה!".
///
/// השם בתחרות לקוח מהפרופיל (בלי שדה עריכה). התחרות מקומית מול "בוטים";
/// כשיחובר שרת רב-משתתפים אמיתי אפשר להחליף אותם בשחקנים אמיתיים.
class RaceSetupScreen extends ConsumerStatefulWidget {
  const RaceSetupScreen({super.key});

  @override
  ConsumerState<RaceSetupScreen> createState() => _RaceSetupScreenState();
}

class _RaceSetupScreenState extends ConsumerState<RaceSetupScreen> {
  int _totalPlayers = 2;
  BotDifficulty _difficulty = BotDifficulty.normal;
  int _gridSize = 4;
  int _timeSeconds = 90;

  String _playerName() {
    final name = ref.read(playerProfileProvider).valueOrNull?.displayName.trim() ?? '';
    return name.isEmpty || name == 'שחקן/ית' ? 'את/ה' : name;
  }

  void _start() {
    final bots = List.generate(
      _totalPlayers - 1,
      (i) => BotSetup(name: _botNamePool[i % _botNamePool.length], difficulty: _difficulty),
    );
    context.push(
      '/multiplayer/race',
      extra: RaceConfig(
        gridSize: _gridSize,
        timeLimit: Duration(seconds: _timeSeconds),
        humanName: _playerName(),
        bots: bots,
      ),
    );
  }

  void _pick(VoidCallback change) {
    Haptics.selection();
    setState(change);
  }

  @override
  Widget build(BuildContext context) {
    // מאזינים לפרופיל כדי שהשם יהיה טעון עד הלחיצה על "בואו נתחרה!".
    ref.watch(playerProfileProvider);
    return GameScaffold(
      colors: kVsComputerGradient,
      header: GameHeader(
        title: 'שחק נגד המחשב',
        subtitle: 'מי מוצא/ת הכי הרבה מילים?',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.safeBottom(min: 14, extra: 6)),
        child: Column(
          children: [
            Expanded(
              child: _Arena(opponents: _totalPlayers - 1, difficulty: _difficulty),
            ),
            const SizedBox(height: 10),
            _SettingsCard(
              children: [
                _SettingRow<int>(
                  icon: Icons.groups_rounded,
                  label: 'יריבים',
                  values: const [1, 2, 3],
                  selected: _totalPlayers - 1,
                  labelOf: (v) => '$v',
                  onSelect: (v) => _pick(() => _totalPlayers = v + 1),
                ),
                _SettingRow<BotDifficulty>(
                  icon: Icons.psychology_rounded,
                  label: 'רמה',
                  values: BotDifficulty.values,
                  selected: _difficulty,
                  labelOf: (d) => d.labelHe,
                  onSelect: (d) => _pick(() => _difficulty = d),
                ),
                _SettingRow<int>(
                  icon: Icons.grid_view_rounded,
                  label: 'לוח',
                  values: const [3, 4, 5, 6],
                  selected: _gridSize,
                  labelOf: (v) => '$v×$v',
                  onSelect: (v) => _pick(() => _gridSize = v),
                ),
                _SettingRow<int>(
                  icon: Icons.timer_rounded,
                  label: 'זמן',
                  values: const [60, 90, 120],
                  selected: _timeSeconds,
                  labelOf: (v) => '$v שנ׳',
                  onSelect: (v) => _pick(() => _timeSeconds = v),
                ),
              ],
            ).animate().fadeIn(duration: 280.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
            const SizedBox(height: 12),
            CandyButton(
              label: 'בואו נתחרה!',
              icon: Icons.flag_rounded,
              palette: CandyPalette.green,
              height: 62,
              fontSize: 22,
              onPressed: _start,
            ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
          ],
        ),
      ),
    );
  }
}

/// צבעי "שחק נגד המחשב" - תואמים לכפתור הכחול במסך הבית.
const kVsComputerGradient = [Color(0xFF38BDF8), Color(0xFF3B82F6), Color(0xFF6366F1)];

extension _DifficultyLook on BotDifficulty {
  List<Color> get colors => switch (this) {
    BotDifficulty.easy => const [Color(0xFF7CEB6E), Color(0xFF2BB673)],
    BotDifficulty.normal => const [Color(0xFFFFD166), Color(0xFFFF9F1C)],
    BotDifficulty.hard => const [Color(0xFFFF6B6B), Color(0xFFD62246)],
  };
}

// ---------------------------------------------------------------- זירה

/// זואי מימין, "VS" זוהר באמצע, והרובוטים משמאל - כל אחד קופץ פנימה.
class _Arena extends StatefulWidget {
  final int opponents;
  final BotDifficulty difficulty;

  const _Arena({required this.opponents, required this.difficulty});

  @override
  State<_Arena> createState() => _ArenaState();
}

class _ArenaState extends State<_Arena> with SingleTickerProviderStateMixin {
  late final AnimationController _clock = AnimationController(vsync: this, duration: const Duration(seconds: 4));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (AmbientMotion.enabledFor(context)) {
      if (!_clock.isAnimating) _clock.repeat();
    } else {
      _clock.stop();
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        // הכל מתכווץ יחד במסכים נמוכים, כך שהמסך לעולם לא צריך גלילה.
        final h = c.maxHeight;
        final zoey = (h * 0.68).clamp(90.0, 290.0);
        final bot = (h * 0.3).clamp(46.0, 112.0);
        // גובה התוכן (דמות + תגית שם), כדי להציב את הבמה בדיוק מתחת לרגליים.
        final contentH = zoey + 40;
        final feetY = (h + contentH) / 2 - 40;
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final t = _clock.value * math.pi * 2;
            return Stack(
              alignment: Alignment.center,
              children: [
                // אותיות מרחפות ברקע הזירה - עומק ותחושת משחק מילים.
                for (final f in _floaters)
                  Positioned(
                    left: c.maxWidth * f.x,
                    top: h * f.y + math.sin(t + f.phase) * 8,
                    child: Opacity(
                      opacity: 0.55,
                      child: Transform.rotate(
                        angle: math.sin(t * 0.5 + f.phase) * 0.18,
                        child: LetterTile(letter: f.letter, size: f.size, hard: f.hard),
                      ),
                    ),
                  ),
                // במה זוהרת בבסיס הזירה.
                Positioned(
                  top: feetY - h * 0.06,
                  child: Container(
                    width: c.maxWidth * 0.95,
                    height: h * 0.14,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.elliptical(c.maxWidth, h * 0.14)),
                      gradient: RadialGradient(
                        colors: [Colors.white.withValues(alpha: 0.45), Colors.white.withValues(alpha: 0)],
                      ),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // זואי (בצד ימין ב-RTL).
                    Expanded(
                      flex: 6,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Transform.translate(
                            offset: Offset(0, math.sin(t) * 4),
                            child: Image.asset('assets/avatar/detective_celebrate.png', height: zoey),
                          ),
                          const _NameTag(text: 'זואי ואת/ה', colors: [Color(0xFFFFB259), Color(0xFFFF7A45)]),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 64,
                      child: Padding(
                        padding: EdgeInsets.only(bottom: zoey * 0.45),
                        child: _VsBadge(pulse: 0.5 + 0.5 * math.sin(t * 2)),
                      ),
                    ),
                    // הרובוטים.
                    Expanded(
                      flex: 5,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          _RobotSquad(
                            count: widget.opponents,
                            maxSize: bot,
                            // עמודת הרובוטים: 4 מתוך 10 חלקים (זואי 6), פחות תג ה-VS.
                            width: (c.maxWidth - 64) * 0.4,
                            maxHeight: zoey,
                            difficulty: widget.difficulty,
                            t: t,
                          ),
                          const SizedBox(height: 6),
                          _NameTag(
                            text: widget.opponents == 1
                                ? 'יריב ${widget.difficulty.labelHe}'
                                : '${widget.opponents} יריבים',
                            colors: widget.difficulty.colors,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// אותיות הרקע של הזירה: מיקום יחסי, גודל ופאזה לריחוף.
const _floaters = [
  (letter: 'א', x: 0.04, y: 0.04, size: 34.0, phase: 0.0, hard: false),
  (letter: 'ק', x: 0.30, y: 0.12, size: 28.0, phase: 1.3, hard: true),
  (letter: 'מ', x: 0.56, y: 0.02, size: 30.0, phase: 2.1, hard: false),
  (letter: 'ש', x: 0.82, y: 0.10, size: 36.0, phase: 3.4, hard: false),
  (letter: 'צ', x: 0.12, y: 0.28, size: 24.0, phase: 4.2, hard: true),
  (letter: 'ל', x: 0.72, y: 0.30, size: 26.0, phase: 5.0, hard: false),
];

/// הרובוטים היריבים: אחד גדול, שניים זה לצד זה, או שלושה בפירמידה (שניים
/// למעלה ואחד למטה). הגודל מחושב מהרוחב והגובה הפנויים, כך שאין גלישה.
class _RobotSquad extends StatelessWidget {
  final int count;
  final double maxSize;
  final double width;
  final double maxHeight;
  final BotDifficulty difficulty;
  final double t;

  const _RobotSquad({
    required this.count,
    required this.maxSize,
    required this.width,
    required this.maxHeight,
    required this.difficulty,
    required this.t,
  });

  @override
  Widget build(BuildContext context) {
    const gap = 6.0;
    final perRow = count == 1 ? 1 : 2;
    final rows = (count / perRow).ceil();
    final size = math.min(
      count == 1 ? maxSize : maxSize * 0.8,
      math.min((width - gap * (perRow - 1)) / perRow, (maxHeight - gap * (rows - 1)) / rows / 1.15),
    );
    Widget robot(int i) => Transform.translate(
      offset: Offset(0, math.sin(t + i * 1.7) * 5),
      child: _BotFace(key: ValueKey('bot-$i'), name: _botNamePool[i % _botNamePool.length], size: size, difficulty: difficulty)
          .animate(key: ValueKey('in-$i-$count'))
          .scale(begin: const Offset(0.3, 0.3), curve: Curves.elasticOut, duration: 600.ms),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var r = 0; r < rows; r++) ...[
          if (r > 0) const SizedBox(height: gap),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = r * perRow; i < math.min(count, (r + 1) * perRow); i++) ...[
                if (i > r * perRow) const SizedBox(width: gap),
                robot(i),
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _NameTag extends StatelessWidget {
  final String text;
  final List<Color> colors;

  const _NameTag({required this.text, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: colors),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(color: colors.last.withValues(alpha: 0.5), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Text(
        text,
        maxLines: 1,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 14),
      ),
    );
  }
}

class _VsBadge extends StatelessWidget {
  final double pulse;

  const _VsBadge({required this.pulse});

  @override
  Widget build(BuildContext context) {
    return Transform.scale(
      scale: 1 + pulse * 0.08,
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            center: Alignment(-0.3, -0.4),
            colors: [Color(0xFFFFF3B0), Color(0xFFFFC93C), Color(0xFFFF8A00)],
          ),
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFFC93C).withValues(alpha: 0.4 + pulse * 0.4),
              blurRadius: 18 + pulse * 10,
            ),
          ],
        ),
        child: const Text(
          'VS',
          style: TextStyle(
            color: Color(0xFF7A2E00),
            fontWeight: FontWeight.w900,
            fontSize: 20,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}

/// יריב: הדמות הייחודית שלו (לפי שמו) בטבעת בצבע הרמה, ותג "רמה" קטן -
/// קליל ירוק 🙂, בינוני כתום 😎, מומחה אדום 🔥.
class _BotFace extends StatelessWidget {
  final String name;
  final double size;
  final BotDifficulty difficulty;

  const _BotFace({super.key, required this.name, required this.size, required this.difficulty});

  @override
  Widget build(BuildContext context) {
    final colors = difficulty.colors;
    final badge = switch (difficulty) {
      BotDifficulty.easy => '🙂',
      BotDifficulty.normal => '😎',
      BotDifficulty.hard => '🔥',
    };
    return SizedBox(
      width: size,
      height: size * 1.15,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(size * 0.06),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              boxShadow: [
                BoxShadow(color: colors.last.withValues(alpha: 0.55), blurRadius: 14, offset: const Offset(0, 6)),
              ],
            ),
            child: AvatarWidget(avatarId: botAvatarId(name), size: size * 0.88, ring: false),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: size * 0.1, vertical: 1),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colors.last, width: 1.5),
              ),
              child: Text(
                '$badge $name',
                maxLines: 1,
                style: TextStyle(fontSize: math.max(10, size * 0.15), fontWeight: FontWeight.w900, color: colors.last),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- הגדרות

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFEFF5FF)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E3A8A).withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(height: 8), children[i]],
        ],
      ),
    );
  }
}

/// שורת הגדרה: אייקון + שם, ובורר מחליק עם "גלולה" שזזה לבחירה.
class _SettingRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<T> values;
  final T selected;
  final String Function(T) labelOf;
  final ValueChanged<T> onSelect;

  const _SettingRow({
    required this.icon,
    required this.label,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final index = values.indexOf(selected);
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final x = values.length == 1 ? 0.0 : -1 + index * 2 / (values.length - 1);
    return Row(
      children: [
        SizedBox(
          width: 78,
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF3B82F6)),
              const SizedBox(width: 5),
              // גדלי טקסט גדולים (נגישות) מקטינים את התווית במקום לגלוש.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF1E3A8A)),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(color: const Color(0xFFE3EDFF), borderRadius: BorderRadius.circular(14)),
            child: Stack(
              children: [
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                  alignment: Alignment(rtl ? -x : x, 0),
                  child: FractionallySizedBox(
                    widthFactor: 1 / values.length,
                    heightFactor: 1,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(11),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Color(0xFF6FD3FF), Color(0xFF2E8BFF)],
                        ),
                        boxShadow: const [BoxShadow(color: Color(0xFF1A5BC4), offset: Offset(0, 3))],
                      ),
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (final v in values)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: v == selected,
                          label: '$label ${labelOf(v)}',
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onSelect(v),
                            child: Center(
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 200),
                                style: TextStyle(
                                  fontFamily: DefaultTextStyle.of(context).style.fontFamily,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: v == selected ? Colors.white : const Color(0xFF3B5BA9),
                                ),
                                child: FittedBox(fit: BoxFit.scaleDown, child: Text(labelOf(v), maxLines: 1)),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
