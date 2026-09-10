import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/models/level_config.dart';
import 'widgets/mascot_widget.dart';

/// מסך "לפני השלב" - מציג את גודל הלוח, מגבלת הזמן ויעדי הכוכבים,
/// ומאפשר לשחקן להתכונן נפשית לפני שהטיימר מתחיל לרוץ.
class LevelIntroScreen extends StatelessWidget {
  final int levelNumber;

  const LevelIntroScreen({super.key, required this.levelNumber});

  @override
  Widget build(BuildContext context) {
    final config = CampaignLevels.byLevelNumber(levelNumber);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientForWorldIndex(config.tier.index),
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    onPressed: () => context.go('/campaign'),
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                  ),
                ),
                const Spacer(),
                const MascotWidget(mood: MascotMood.excited, size: 120),
                const SizedBox(height: 16),
                Text(
                  config.tier.titleHe,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'שלב $levelNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.w900,
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.8, 0.8)),
                const SizedBox(height: 28),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _InfoRow(
                          icon: Icons.grid_view_rounded,
                          label: 'גודל לוח',
                          value: '${config.gridSize}×${config.gridSize}',
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.timer_rounded,
                          label: 'זמן לשלב',
                          value: '${config.timeLimit.inSeconds} שניות',
                        ),
                        const Divider(height: 24),
                        _InfoRow(
                          icon: Icons.flag_rounded,
                          label: 'מטרה',
                          value:
                              '${config.wordsRequired} ${config.wordsRequired == 1 ? "מילה" : "מילים"}',
                        ),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _StarGoal(stars: 1, words: config.oneStarWords),
                            _StarGoal(stars: 2, words: config.twoStarWords),
                            _StarGoal(stars: 3, words: config.threeStarWords),
                          ],
                        ),
                      ],
                    ),
                  ),
                ).animate().fadeIn(delay: 150.ms).slideY(begin: 0.15, end: 0),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => context.pushReplacement('/level/$levelNumber/play'),
                    child: const Text('התחילו לשחק!'),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(fontSize: 15)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
      ],
    );
  }
}

class _StarGoal extends StatelessWidget {
  final int stars;
  final int words;

  const _StarGoal({required this.stars, required this.words});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: List.generate(
            stars,
            (i) => const Icon(Icons.star_rounded, color: AppColors.star, size: 18),
          ),
        ),
        const SizedBox(height: 4),
        Text('$words+ מ׳', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12)),
      ],
    );
  }
}
