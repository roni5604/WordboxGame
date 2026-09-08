import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../game/widgets/mascot_widget.dart';

/// מסך רב-משתתפים: מציע תחרות מקומית מיידית (2-4 משתתפים, משחקים על
/// אותו מכשיר מול "בוטים" - ראה lib/game_engine/bot_player.dart), ומציג
/// תצוגה מקדימה של מצב אונליין אמיתי מול חברים שיגיע בהמשך (דורש שרת -
/// ראו lib/features/multiplayer/services/multiplayer_repository.dart
/// ו-docs/FIREBASE_SETUP.md).
class MultiplayerHomeScreen extends StatelessWidget {
  const MultiplayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('רב-משתתפים'),
        backgroundColor: AppColors.primaryDark,
        leading: BackButton(onPressed: () => context.pop()),
      ),
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const MascotWidget(mood: MascotMood.excited, size: 90),
            const SizedBox(height: 12),
            const Text(
              'תחרות 2-4 משתתפים',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'לוח משותף אחד - כל אחד/ת מוצא/ת מילים בעצמו/ה, ומי שצובר/ת\n'
              'הכי הרבה נקודות עד תום הזמן מנצח/ת!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.flash_on_rounded, color: AppColors.primary, size: 36),
                    const SizedBox(height: 8),
                    const Text(
                      'תחרות מהירה - זמינה עכשיו!',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'שחקו נגד יריבים מדומים על אותו מכשיר - מושלם לתרגול\n'
                      'ולבדיקת המשחק כבר עכשיו, בלי צורך בחיבור לאינטרנט.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => context.push('/multiplayer/setup'),
                        child: const Text('יצירת חדר תחרות'),
                      ),
                    ),
                  ],
                ),
              ),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'בקרוב - משחק אונליין אמיתי מול חברים',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 16),
            _MockMultiplayerHud(),
            const SizedBox(height: 12),
            const Text(
              'כשנחבר שרת (ראו docs/FIREBASE_SETUP.md), אותו מסך תחרות בדיוק\n'
              'יעבוד גם מול חברים אמיתיים דרך קוד חדר - במקום בוטים.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _MockMultiplayerHud extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF9A56), Color(0xFFFF6F91)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _MockPlayerBadge(name: 'דנה', score: 32, active: false),
              _MockPlayerBadge(name: 'את/ה', score: 20, active: true),
            ],
          ),
          const SizedBox(height: 12),
          _MockGrid(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              _MockPlayerBadge(name: 'עומר', score: 24, active: false),
              _MockPlayerBadge(name: 'נועה', score: 12, active: false),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0);
  }
}

class _MockPlayerBadge extends StatelessWidget {
  final String name;
  final int score;
  final bool active;

  const _MockPlayerBadge({required this.name, required this.score, required this.active});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.topRight,
          children: [
            const MascotWidget(mood: MascotMood.happy, size: 48),
            if (active)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$score', style: const TextStyle(color: Colors.white, fontSize: 11)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('$score', style: const TextStyle(fontSize: 11)),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          name,
          style: TextStyle(
            color: Colors.white,
            fontWeight: active ? FontWeight.w800 : FontWeight.w500,
            fontSize: 12,
          ),
        ),
        if (active)
          Container(
            margin: const EdgeInsets.only(top: 2),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('התור שלך', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

class _MockGrid extends StatelessWidget {
  static const letters = [
    ['ל', 'ד', 'ש'],
    ['ם', 'ו', 'ק'],
    ['ר', 'א', 'ת'],
  ];

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            for (final row in letters)
              Expanded(
                child: Row(
                  children: [
                    for (final letter in row)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.all(4),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              letter,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
