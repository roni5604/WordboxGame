import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../game/widgets/mascot_widget.dart';

/// מסך "רב-משתתפים" - שער הכניסה לשני מצבים נפרדים ומודגשים:
/// **משחק מול המחשב** (תחרות מקומית מיידית מול יריבים מדומים - ראה
/// lib/features/multiplayer/race_setup_screen.dart, לא נגענו בו) ו-
/// **משחק מול חברים** (חדרים פרטיים אמיתיים עם קוד, דרך Firestore - ראה
/// create_room_screen.dart/join_room_screen.dart/room_lobby_screen.dart).
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
              'איך תרצו לשחק?',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 8),
            const Text(
              'לוח משותף אחד - כל אחד/ת מוצא/ת מילים בעצמו/ה, ומי שצובר/ת\n'
              'הכי הרבה נקודות עד תום הזמן מנצח/ת!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 24),
            _ModeCard(
              icon: Icons.smart_toy_rounded,
              iconColor: AppColors.primary,
              title: 'משחק מול המחשב',
              subtitle:
                  'שחקו נגד יריבים מדומים על אותו מכשיר - מושלם לתרגול\n'
                  'ולבדיקת המשחק כבר עכשיו, בלי צורך בחיבור לאינטרנט.',
              buttonLabel: 'התחלת משחק',
              onTap: () => context.push('/multiplayer/setup'),
            ).animate().fadeIn().slideY(begin: 0.1, end: 0),
            const SizedBox(height: 20),
            if (AppConfig.multiplayerEnabled) ...[
              _ModeCard(
                icon: Icons.groups_rounded,
                iconColor: AppColors.accent,
                title: 'משחק מול חברים',
                subtitle:
                    'צרו חדר פרטי וקבלו קוד לשיתוף, או הצטרפו לחדר של חבר/ה\n'
                    'עם קוד - כולם משחקים בזמן אמת על אותו לוח!',
                highlight: true,
                actions: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.accent,
                        side: const BorderSide(color: AppColors.accent),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => context.push('/multiplayer/online/join'),
                      child: const Text('הצטרפות עם קוד'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => context.push('/multiplayer/online/create'),
                      child: const Text('יצירת חדר'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1, end: 0),
            ] else
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
          ],
        ),
      ),
    );
  }
}

class _ModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? buttonLabel;
  final VoidCallback? onTap;
  final List<Widget>? actions;
  final bool highlight;

  const _ModeCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.buttonLabel,
    this.onTap,
    this.actions,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: highlight ? const BorderSide(color: AppColors.accent, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(icon, color: iconColor, size: 40),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            if (actions != null)
              Row(children: actions!)
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onTap,
                  child: Text(buttonLabel ?? ''),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
