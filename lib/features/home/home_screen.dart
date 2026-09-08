import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/player_profile_provider.dart';
import '../game/widgets/mascot_widget.dart';

/// תפריט ראשי - שער הכניסה למשחק: התחלת קמפיין, רב-משתתפים, הדרכה
/// וחוקי המשחק. מפת השלבים עצמה נמצאת ב-/campaign (ראה [CampaignMapScreen]).
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(playerProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.primaryDark,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primaryDark, AppColors.primary],
          ),
        ),
        child: SafeArea(
          child: profileAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.white)),
            error: (e, st) => Center(
              child: Text('שגיאה בטעינת הפרופיל: $e', style: const TextStyle(color: Colors.white)),
            ),
            data: (profile) {
              // גלילה + גובה מינימלי = תוכן ממורכז יפה במסכים גבוהים, אך
              // לעולם לא "נחתך" מחוץ למסך במסכים קצרים/רחבים (למשל דפדפן
              // בחלון נמוך) - זו הייתה תקלה שראינו במסכים קודמים.
              return LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              child: Row(
                                children: [
                                  _Pill(
                                      icon: Icons.star_rounded,
                                      iconColor: AppColors.star,
                                      label: '${profile.totalStars}'),
                                  const SizedBox(width: 8),
                                  _Pill(
                                      icon: Icons.paid_rounded,
                                      iconColor: Colors.amberAccent,
                                      label: '${profile.coins}'),
                                  const Spacer(),
                                  IconButton(
                                    onPressed: () => context.push('/settings'),
                                    icon: const Icon(Icons.settings_rounded, color: Colors.white),
                                  ),
                                  IconButton(
                                    onPressed: () => context.push('/profile'),
                                    icon: const Icon(Icons.person_rounded, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            const MascotWidget(mood: MascotMood.happy, size: 110)
                                .animate(onPlay: (c) => c.repeat(reverse: true))
                                .moveY(begin: -6, end: 6, duration: 1600.ms, curve: Curves.easeInOut),
                            const SizedBox(height: 10),
                            Text(
                              'מילה־קסם',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                                shadows: [
                                  Shadow(
                                      color: Colors.black.withValues(alpha: 0.25), blurRadius: 12),
                                ],
                              ),
                            ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9)),
                            const Text(
                              'משחק המילים העברי המקורי',
                              style: TextStyle(color: Colors.white70, fontSize: 14),
                            ),
                            const Spacer(),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _MenuButton(
                                    icon: Icons.play_arrow_rounded,
                                    label:
                                        profile.highestUnlockedLevel > 1 ? 'המשך משחק' : 'שחקו!',
                                    color: AppColors.success,
                                    isPrimary: true,
                                    onTap: () => context.push('/campaign'),
                                  ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 14),
                                  _MenuButton(
                                    icon: Icons.groups_rounded,
                                    label: 'רב-משתתפים (2-4)',
                                    color: AppColors.accent,
                                    onTap: () => context.push('/multiplayer'),
                                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2, end: 0),
                                  const SizedBox(height: 14),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _MenuButton(
                                          icon: Icons.school_rounded,
                                          label: 'איך משחקים',
                                          color: Colors.white,
                                          textColor: AppColors.primaryDark,
                                          compact: true,
                                          onTap: () => context.push('/how-to-play'),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _MenuButton(
                                          icon: Icons.menu_book_rounded,
                                          label: 'חוקי המשחק',
                                          color: Colors.white,
                                          textColor: AppColors.primaryDark,
                                          compact: true,
                                          onTap: () => context.push('/rules'),
                                        ),
                                      ),
                                    ],
                                  ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.2, end: 0),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _Pill({required this.icon, required this.iconColor, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white)),
        ],
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color textColor;
  final bool isPrimary;
  final bool compact;
  final VoidCallback onTap;

  const _MenuButton({
    required this.icon,
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.isPrimary = false,
    this.compact = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(20),
      elevation: isPrimary ? 8 : 3,
      shadowColor: Colors.black38,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 20,
            vertical: compact ? 16 : (isPrimary ? 20 : 16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: textColor, size: isPrimary ? 28 : 22),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.w800,
                  fontSize: isPrimary ? 20 : 15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
