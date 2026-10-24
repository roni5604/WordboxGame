import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/feedback/haptics.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import 'widgets/rule_demos.dart';

/// מסך "חוקי המשחק": מסע קצר של עשרה "שלבי הסבר". בכל אחד חוק אחד, משפט
/// קצר, והדגמה חיה גדולה - חלקן לנסות בעצמכם (לגרור, לגעת, לבחור). המעבר
/// בין החוקים הוא קובייה תלת-ממדית, וזואי הבלשית נותנת טיפ בכל שלב.
///
/// בנוי לפי עקרונות של הדרכות משחקים מודרניות: רעיון אחד בכל מסך,
/// "ללמוד תוך כדי עשייה", מעט טקסט, התקדמות גלויה, ואפשר לקפוץ לכל חוק.
class RulesScreen extends StatefulWidget {
  const RulesScreen({super.key});

  @override
  State<RulesScreen> createState() => _RulesScreenState();
}

class _Rule {
  final String title;
  final String text;
  final String tip;
  final IconData icon;
  final List<Color> colors;
  final Widget Function() demo;

  const _Rule({
    required this.title,
    required this.text,
    required this.tip,
    required this.icon,
    required this.colors,
    required this.demo,
  });
}

final _rules = <_Rule>[
  _Rule(
    title: 'חברו אותיות שכנות',
    text: 'גררו את האצבע בין אותיות צמודות - לצדדים, למעלה, למטה או באלכסון.',
    tip: 'נסו עכשיו: "ילד" או "בית"!',
    icon: Icons.gesture_rounded,
    colors: const [Color(0xFF7B5CFF), Color(0xFF4F46E5)],
    demo: () => const TraceWordDemo(),
  ),
  _Rule(
    title: 'כל משבצת - פעם אחת',
    text: 'באותה מילה אי אפשר לחזור לאותה משבצת. שתי משבצות עם אותה אות? מותר.',
    tip: 'התחרטתם? חזרו אחורה באצבע על הקו.',
    icon: Icons.block_rounded,
    colors: const [Color(0xFFFF6B8B), Color(0xFFE6397A)],
    demo: () => const NoRepeatDemo(),
  ),
  _Rule(
    title: 'רק מילים אמיתיות',
    text: 'המילה חייבת להיות במילון העברי של המשחק. מילה שלא קיימת - לא נחשבת.',
    tip: 'געו בקלפים - מי מהם מילה?',
    icon: Icons.menu_book_rounded,
    colors: const [Color(0xFF2EC4B6), Color(0xFF0E9AA7)],
    demo: () => const RealWordDemo(),
  ),
  _Rule(
    title: 'אותיות סופיות לבד',
    text: 'על הלוח כ מ נ פ צ רגילות, ובסוף מילה הן הופכות לבד ל-ך ם ן ף ץ.',
    tip: 'מחפשים "מלך"? חברו מ-ל-כ.',
    icon: Icons.auto_fix_high_rounded,
    colors: const [Color(0xFF4FACFE), Color(0xFF2B6CFF)],
    demo: () => const SofitDemo(),
  ),
  _Rule(
    title: 'ארוך = שווה יותר',
    text: 'ככל שהמילה ארוכה יותר, הניקוד קופץ. מילה של 6 אותיות שווה פי 5 משל 3.',
    tip: 'געו בעמודות כדי לראות כמה כל אורך שווה.',
    icon: Icons.trending_up_rounded,
    colors: const [Color(0xFFFFB347), Color(0xFFFF7A45)],
    demo: () => const LengthScoreDemo(),
  ),
  _Rule(
    title: 'אותיות קשות = בונוס',
    text: 'ז ט צ ג ס ק פ סגולות עם +1: כל אחת במילה מוסיפה נקודה.',
    tip: '"קפה" שווה 5 נקודות במקום 3!',
    icon: Icons.diamond_rounded,
    colors: const [Color(0xFFB57BFF), Color(0xFF7B3FF2)],
    demo: () => const HardLettersDemo(),
  ),
  _Rule(
    title: 'השעון מתקתק',
    text: 'לכל שלב יש זמן. כשהפס מאדים נשארו פחות מ-20% - זה הזמן לזרז!',
    tip: 'מילים קצרות מהר, ארוכות כשיש זמן.',
    icon: Icons.timer_rounded,
    colors: const [Color(0xFFFF8A65), Color(0xFFF2463D)],
    demo: () => const TimerDemo(),
  ),
  _Rule(
    title: 'כוכבים לפי יעד',
    text: 'לכל שלב יש יעד נקודות. כל שליש ממנו = כוכב, וכוכב אחד פותח את השלב הבא.',
    tip: 'שלושה כוכבים? שווה לחזור ולשפר!',
    icon: Icons.stars_rounded,
    colors: const [Color(0xFFFFD54F), Color(0xFFFF9F1C)],
    demo: () => const StarsDemo(),
  ),
  _Rule(
    title: 'פרקים נפתחים בכוכבים',
    text: 'כל 5 שלבים הם פרק. אוספים מספיק כוכבים - או פותחים במטבעות.',
    tip: 'חסרים כוכבים? שפרו שלב קודם.',
    icon: Icons.lock_open_rounded,
    colors: const [Color(0xFF43E97B), Color(0xFF11998E)],
    demo: () => const ChapterGateDemo(),
  ),
  _Rule(
    title: 'תחרות: אותו לוח לכולם',
    text: 'מול המחשב או חברים - כולם על אותו לוח, ומי שצובר הכי הרבה עד הסוף מנצח.',
    tip: 'רואים רק את הניקוד של היריבים, לא את המילים.',
    icon: Icons.emoji_events_rounded,
    colors: const [Color(0xFF38BDF8), Color(0xFF6366F1)],
    demo: () => const RaceDemo(),
  ),
];

class _RulesScreenState extends State<RulesScreen> {
  final _pages = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _pages.addListener(() => setState(() => _page = _pages.page ?? 0));
  }

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  int get _index => _page.round().clamp(0, _rules.length - 1);

  void _go(int i) {
    Haptics.selection();
    _pages.animateToPage(i, duration: const Duration(milliseconds: 520), curve: Curves.easeInOutCubic);
  }

  void _close() => context.canPop() ? context.pop() : context.go('/home');

  /// צבעי הרקע זורמים בין צבעי החוק הנוכחי לבא.
  List<Color> _backdrop() {
    final i = _page.floor().clamp(0, _rules.length - 1);
    final j = math.min(i + 1, _rules.length - 1);
    final f = (_page - i).clamp(0.0, 1.0);
    return [
      Color.lerp(_rules[i].colors[0], _rules[j].colors[0], f)!,
      Color.lerp(_rules[i].colors[1], _rules[j].colors[1], f)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final last = _index == _rules.length - 1;
    return GameScaffold(
      colors: _backdrop(),
      header: GameHeader(title: 'חוקי המשחק', subtitle: '${_index + 1} מתוך ${_rules.length}', onBack: _close),
      body: Column(
        children: [
          _ProgressSegments(count: _rules.length, page: _page, onTap: _go),
          const SizedBox(height: 8),
          Expanded(
            child: PageView.builder(
              controller: _pages,
              itemCount: _rules.length,
              itemBuilder: (context, i) => _CubePage(
                offset: _page - i,
                child: _RulePage(rule: _rules[i], index: i),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(18, 8, 18, context.safeBottom(min: 16, extra: 8)),
            child: Row(
              children: [
                if (_index > 0) ...[
                  // ב-RTL "אחורה" מצביע ימינה.
                  CandyIconButton(
                    icon: Icons.arrow_back_rounded,
                    tooltip: 'הקודם',
                    size: 56,
                    onPressed: () => _go(_index - 1),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: CandyButton(
                    label: last ? 'הבנתי, בואו נשחק!' : 'הבא',
                    icon: last ? Icons.play_arrow_rounded : Icons.arrow_forward_rounded,
                    palette: last ? CandyPalette.green : CandyPalette.orange,
                    height: 56,
                    onPressed: last ? _close : () => _go(_index + 1),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// סרגל התקדמות מקוטע; נגיעה בקטע קופצת לחוק.
class _ProgressSegments extends StatelessWidget {
  final int count;
  final double page;
  final ValueChanged<int> onTap;

  const _ProgressSegments({required this.count, required this.page, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onTap(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    alignment: AlignmentDirectional.centerStart,
                    child: FractionallySizedBox(
                      widthFactor: (page + 1 - i).clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          boxShadow: [BoxShadow(color: Colors.white.withValues(alpha: 0.6), blurRadius: 6)],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// מעבר "קובייה": הדף הנוכחי מסתובב סביב הציר האנכי כמו פאה של קובייה.
class _CubePage extends StatelessWidget {
  final double offset;
  final Widget child;

  const _CubePage({required this.offset, required this.child});

  @override
  Widget build(BuildContext context) {
    final o = offset.clamp(-1.0, 1.0);
    // ב-RTL הדף הבא נכנס משמאל - הכיוון מתהפך.
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final angle = (rtl ? -o : o) * math.pi / 2.6;
    return Transform(
      alignment: (rtl ? -o : o) > 0 ? Alignment.centerRight : Alignment.centerLeft,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.0011)
        ..rotateY(angle),
      child: Opacity(opacity: (1 - o.abs() * 0.6).clamp(0.0, 1.0), child: child),
    );
  }
}

class _RulePage extends StatelessWidget {
  final _Rule rule;
  final int index;

  const _RulePage({required this.rule, required this.index});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Column(
        children: [
          // כותרת החוק: אייקון במדליה תלת-ממדית + כותרת + משפט אחד.
          Row(
            children: [
              _Medal(icon: rule.icon, colors: rule.colors, number: index + 1),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rule.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 23,
                        fontWeight: FontWeight.w900,
                        height: 1.1,
                        shadows: [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 4)],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rule.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // הבמה: כרטיס לבן עם עומק, וההדגמה החיה במרכזו.
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(30),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white, Color(0xFFF3EEFF)],
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 12)),
                  BoxShadow(color: rule.colors.last.withValues(alpha: 0.35), blurRadius: 40, spreadRadius: -6),
                ],
              ),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
                      child: Center(
                        child: FittedBox(fit: BoxFit.scaleDown, child: rule.demo()),
                      ),
                    ),
                  ),
                  PositionedDirectional(start: 8, end: 8, bottom: 6, child: _ZoeyTip(text: rule.tip)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// מדליה עגולה ומבריקה עם אייקון החוק ומספרו.
class _Medal extends StatelessWidget {
  final IconData icon;
  final List<Color> colors;
  final int number;

  const _Medal({required this.icon, required this.colors, required this.number});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 62,
      height: 62,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const RadialGradient(center: Alignment(-0.3, -0.4), colors: [Colors.white, Color(0xFFEDE7FF)]),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 10, offset: const Offset(0, 5)),
              ],
            ),
            alignment: Alignment.center,
            child: ShaderMask(
              shaderCallback: (r) => LinearGradient(colors: colors).createShader(r),
              child: Icon(icon, size: 32, color: Colors.white),
            ),
          ),
          PositionedDirectional(
            end: -4,
            bottom: -2,
            child: Container(
              width: 24,
              height: 24,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(colors: colors),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '$number',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// זואי הבלשית עם בועת טיפ.
class _ZoeyTip extends StatelessWidget {
  final String text;

  const _ZoeyTip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Image.asset('assets/avatar/detective_explain.png', height: 74),
        const SizedBox(width: 4),
        Expanded(
          child: Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0xFF2B2440),
              borderRadius: const BorderRadiusDirectional.only(
                topStart: Radius.circular(16),
                topEnd: Radius.circular(16),
                bottomEnd: Radius.circular(16),
                bottomStart: Radius.circular(4),
              ),
              boxShadow: [
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3)),
              ],
            ),
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13.5, height: 1.3),
            ),
          ),
        ),
      ],
    );
  }
}
