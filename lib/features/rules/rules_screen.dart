import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../onboarding/widgets/mini_grid_demo.dart';

/// מסך "חוקי המשחק" - הסבר חוקי המשחק המלאים עם תצוגה ויזואלית ואיורים
/// (לא רק טקסט), נגיש בכל שלב מהתפריט הראשי.
class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חוקי המשחק'),
        backgroundColor: AppColors.primaryDark,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
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
            title: 'הזמן רץ - מהרו!',
            description:
                'לכל שלב יש זמן קצוב. פס ההתקדמות בראש המסך יתחיל להאדים כשנשאר\n'
                'פחות מ-20% מהזמן - זה הרגע להתמקד במילה הבאה!',
            icon: Icons.timer_rounded,
          ),
          _RuleCard(
            index: 6,
            title: 'כוכבים בכל שלב',
            description:
                'בסיום שלב תקבלו 1-3 כוכבים לפי הניקוד שצברתם. כוכבים פותחים את\n'
                'השלבים הבאים ומצטברים לפרופיל שלכם.',
            icon: Icons.stars_rounded,
          ),
          _RuleCard(
            index: 7,
            title: 'רב-משתתפים: מי הכי מהיר/ה?',
            description:
                'ב"תחרות מקומית" (2-4 משתתפים) כולם פותרים את אותו לוח. מי שצובר/ת\n'
                'הכי הרבה נקודות (או מוצא/ת הכי הרבה מילים) עד תום הזמן מנצח/ת!',
            icon: Icons.groups_rounded,
          ),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: () => context.pop(),
              child: const Text('הבנתי, בואו נשחק!'),
            ),
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
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AppColors.primary,
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
            Text(description, style: const TextStyle(color: Colors.black54, height: 1.5)),
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
