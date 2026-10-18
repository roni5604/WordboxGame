import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/game_backdrop.dart';
import '../game/widgets/letter_tile.dart';
import '../onboarding/widgets/mini_grid_demo.dart';
import '../../core/ui/candy_button.dart';

/// מסך "חוקי המשחק" - הסבר חוקי המשחק המלאים עם תצוגה ויזואלית ואיורים
/// (לא רק טקסט), נגיש בכל שלב מהתפריט הראשי.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return GameScaffold(
      colors: AppColors.gradientForWorldIndex(1),
      header: GameHeader(
        title: 'חוקי המשחק',
        onBack: () => context.canPop() ? context.pop() : context.go('/home'),
      ),
      body: ListView(
        physics: const ClampingScrollPhysics(),
        padding: EdgeInsets.fromLTRB(16, 0, 16, context.safeBottom(min: 24, extra: 24)),
        children: [
          Center(
            child: Column(
              children: [
                Image.asset('assets/avatar/detective_explain.png', height: 140)
                    .animate()
                    .fadeIn()
                    .slideY(begin: 0.15, end: 0),
                const SizedBox(height: 8),
                const Text(
                  'הבלש מילולי כאן כדי לעזור לכם להבין את כל החוקים 🔍',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _RuleCard(
            index: 0,
            title: 'חברו אותיות שכנות',
            description:
                'גררו בין אותיות הנמצאות זו לצד זו - אופקית, אנכית או באלכסון - '
                'כדי להרכיב מילה. אפשר גם לשנות כיוון תוך כדי גרירה!',
            demo: const Center(
              child: AnimatedMiniGridDemo(
                letters: ['ל', 'ב', 'י', 'ז', 'ת', 'ק'],
                columns: 3,
                path: [1, 2, 4],
              ),
            ),
          ),
          _RuleCard(
            index: 1,
            title: 'אין חזרה על אותה משבצת',
            description:
                'אסור להשתמש באותה משבצת פעמיים באותה מילה. אם יש שתי משבצות עם\n'
                'האות "א" בלוח, מותר להשתמש בשתיהן - אך לא באותה משבצת פעמיים.',
            icon: Icons.block_rounded,
          ),
          _RuleCard(
            index: 2,
            title: 'רק מילים אמיתיות נחשבות',
            description:
                'המילה שהרכבתם חייבת להיות מילה תקנית וקיימת במילון העברי של\n'
                'המשחק - אחרת היא תיסרב (בליווי רטט/הבהוב אדום).',
            icon: Icons.menu_book_rounded,
          ),
          _RuleCard(
            index: 3,
            title: 'אותיות סופיות אוטומטיות',
            description:
                'בלוח מוצגות האותיות בצורתן הרגילה (כ מ נ פ צ) כדי לא לבלבל -\n'
                'אך כשמילה שמסתיימת בהן חוקית, היא תוצג עם הצורה הסופית הנכונה\n'
                '(ך ם ן ף ץ), למשל "מלך" ולא "מלכ".',
            demo: const Center(
              child: _SofitDemo(),
            ),
          ),
          _RuleCard(
            index: 4,
            title: 'ניקוד לפי אורך המילה',
            description:
                'מילים ארוכות יותר שוות יותר נקודות! מילה של 2-3 אותיות שווה מעט,\n'
                'ואילו מילה של 5-6 אותיות ומעלה שווה בונוס נקודות משמעותי.',
            icon: Icons.star_rounded,
          ),
          _RuleCard(
            index: 5,
            title: 'אותיות קשות שוות יותר',
            description:
                'האותיות ז ט צ ג ס ק פ מופיעות בפחות מילים, ולכן הן סגולות\n'
                'ומסומנות ב-+1. כל אות קשה במילה מוסיפה נקודה. "קפה" שווה 5\n'
                'נקודות במקום 3 - שווה לחפש אותן!',
            demo: const Center(child: _HardLettersDemo()),
          ),
          _RuleCard(
            index: 6,
            title: 'הזמן רץ - מהרו!',
            description:
                'לכל שלב יש זמן קצוב. פס ההתקדמות בראש המסך יתחיל להאדים כשנשאר\n'
                'פחות מ-20% מהזמן - זה הרגע להתמקד במילה הבאה!',
            icon: Icons.timer_rounded,
          ),
          _RuleCard(
            index: 7,
            title: 'כוכבים בכל שלב',
            description:
                'היעד של כל שלב הוא כמות נקודות. מילה ארוכה מקרבת אתכם ליעד\n'
                'מהר יותר ממילה קצרה. 1-3 כוכבים לפי הניקוד, ובלי כוכב אחד\n'
                'לפחות השלב הבא נשאר נעול.',
            icon: Icons.stars_rounded,
          ),
          _RuleCard(
            index: 8,
            title: 'פרקים: כוכבים פותחים את הדרך',
            description:
                'כל 5 שלבים הם פרק. כדי להיכנס לפרק הבא צריך מספיק כוכבים\n'
                'מהשלבים הקודמים - או לפתוח אותו במטבעות. חסרים כוכבים?\n'
                'חזרו לשלב קודם ונסו להגיע לשלושה כוכבים.',
            icon: Icons.lock_open_rounded,
          ),
          _RuleCard(
            index: 9,
            title: 'רב-משתתפים: מי הכי מהיר/ה?',
            description:
                'בתחרות (נגד המחשב או נגד חברים בזמן אמת) כולם פותרים את אותו לוח.\n'
                'מי שצובר/ת הכי הרבה נקודות עד תום הזמן מנצח/ת! המילים שהיריבים\n'
                'מוצאים נשארות סודיות - רואים רק כמה נקודות הם צברו.',
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 12),
          CandyButton(
            label: 'הבנתי, בואו נשחק!',
            icon: Icons.play_arrow_rounded,
            palette: CandyPalette.green,
            height: 58,
            onPressed: () => context.canPop() ? context.pop() : context.go('/home'),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  final int index;
  final String title;
  final String description;
  final IconData? icon;
  final Widget? demo;

  const _RuleCard({
    required this.index,
    required this.title,
    required this.description,
    this.icon,
    this.demo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primaryDark,
                  child: icon != null
                      ? Icon(icon, color: Colors.white, size: 22)
                      : Text('${index + 1}',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(color: Color(0xFF5E5578), height: 1.5, fontWeight: FontWeight.w600),
            ),
            if (demo != null) ...[
              const SizedBox(height: 14),
              demo!,
            ],
          ],
        ),
      ),
    ).animate(delay: (80 * index).ms).fadeIn().slideY(begin: 0.08, end: 0);
  }
}

/// הדגמה ויזואלית ממוקדת למנגנון האותיות הסופיות: מציגה את הלוח (עם
/// האות הרגילה "כ") לצד "צ'יפ" המילה שנמצאה, המוצג עם הצורה הסופית "ך".
class _SofitDemo extends StatelessWidget {
  const _SofitDemo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const MiniGridDemo(
          letters: ['מ', 'ל', 'כ'],
          columns: 3,
          path: [0, 1, 2],
          highlightedCount: 3,
          tileSize: 48,
        ),
        const SizedBox(height: 12),
        const Icon(Icons.arrow_downward_rounded, color: Colors.black38),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.success,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Text(
            'מלך ✓',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ),
      ],
    );
  }
}

/// הדגמה של אריחים רגילים מול אריחים "קשים" (סגולים עם +1), באותו עיצוב
/// כמו בלוח עצמו.
class _HardLettersDemo extends StatelessWidget {
  const _HardLettersDemo();

  @override
  Widget build(BuildContext context) {
    return const Directionality(
      textDirection: TextDirection.rtl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          LetterTile(letter: 'ק', size: 46, hard: true),
          SizedBox(width: 10),
          LetterTile(letter: 'פ', size: 46, hard: true),
          SizedBox(width: 10),
          LetterTile(letter: 'ה', size: 46),
        ],
      ),
    );
  }
}
