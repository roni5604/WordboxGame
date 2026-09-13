import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// בועת "המילה בבנייה" - מוצגת מעל הלוח ומתעדכנת בזמן אמת תוך כדי גרירה
/// (ראו [GridBoard.onWordChanged]), כדי שתמיד יהיה ברור אילו אותיות כבר
/// נבחרו ואיזו מילה עומדים ליצור - בדיוק כמו ב"מד המילה" שמופיע במשחקי
/// חיבור-אותיות מוכרים. משותפת לשלושת מסכי המשחק (קמפיין, תחרות מקומית
/// מול המחשב, ומשחק מול חברים) כך שהמראה עקבי בכל מקום.
///
/// כשאין גרירה פעילה היא נעלמת בעדינות אך משאירה את הגובה שמור, כדי
/// שהלוח לא "יקפוץ" מעלה-מטה בכל תחילת/סוף גרירה.
class CurrentWordBadge extends StatelessWidget {
  final String word;

  const CurrentWordBadge({super.key, required this.word});

  @override
  Widget build(BuildContext context) {
    final isActive = word.isNotEmpty;
    return SizedBox(
      height: 42,
      child: Center(
        child: AnimatedScale(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          scale: isActive ? 1 : 0.85,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 140),
            opacity: isActive ? 1 : 0,
            child: Container(
              constraints: const BoxConstraints(minWidth: 72),
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 9),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black26,
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                word,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  letterSpacing: 4,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
