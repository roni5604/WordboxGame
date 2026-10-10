import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/player_profile_provider.dart';
import 'widgets/mascot_widget.dart';

/// מסך "לפני השלב" בסגנון חלון-שלב של משחקי פאזל: כרטיס גדול עם סרט
/// כותרת, הכוכבים הטובים ביותר שהושגו עד עכשיו, היעד, ופרטי הלוח - וכפתור
/// "שחקו!" פועם. מאפשר להתכונן לפני שהשעון מתחיל לרוץ.
class LevelIntroScreen extends ConsumerWidget {
  final int levelNumber;

  const LevelIntroScreen({super.key, required this.levelNumber});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final config = CampaignLevels.byLevelNumber(levelNumber);
    final colors = AppColors.gradientForWorldIndex(config.tier.index);
    final progress = ref.watch(playerProfileProvider).valueOrNull?.progressFor(levelNumber);
    final bestStars = progress?.stars ?? 0;
    final bestScore = progress?.bestScore ?? 0;
    final ribbon = config.isWorldFinale
        ? CandyPalette.purple
        : config.isMasterLevel
        ? CandyPalette.gold
        : CandyPalette.orange;

    void play() => context.pushReplacement('/level/$levelNumber/play');

    return GameScaffold(
      colors: colors,
      header: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: Row(
          children: [
            CandyIconButton(icon: Icons.close_rounded, tooltip: 'חזרה למפה', onPressed: () => context.go('/campaign')),
            const Spacer(),
            Row(
              children: [
                Icon(AppColors.iconForWorldIndex(config.tier.index), color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  'עולם ${config.tier.index + 1} · ${config.tier.titleHe}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ],
            ),
            const Spacer(),
            const SizedBox(width: 44),
          ],
        ),
      ),
      bottomBar: CandyButton(
        label: bestStars > 0 ? 'שחקו שוב!' : 'שחקו!',
        icon: Icons.play_arrow_rounded,
        palette: CandyPalette.green,
        height: 66,
        fontSize: 26,
        onPressed: play,
      )
          .animate()
          .fadeIn(delay: 350.ms, duration: 300.ms)
          .slideY(begin: 0.5, end: 0, curve: Curves.easeOutBack)
          .then(delay: 400.ms)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.035, duration: 800.ms, curve: Curves.easeInOut),
      body: Center(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Container(
                  margin: const EdgeInsets.only(top: 26),
                  padding: const EdgeInsets.fromLTRB(18, 44, 18, 18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: ribbon.top.withValues(alpha: 0.7), width: 3),
                    boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 26, offset: Offset(0, 12))],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const MascotWidget(mood: MascotMood.excited, size: 96),
                      const SizedBox(height: 6),
                      _BestStars(stars: bestStars),
                      if (bestScore > 0) ...[
                        const SizedBox(height: 2),
                        Text(
                          'השיא שלך: $bestScore נקודות',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF8A80A8)),
                        ),
                      ],
                      if (config.isMasterLevel || config.isWorldFinale) ...[
                        const SizedBox(height: 10),
                        _LevelKindBadge(isFinale: config.isWorldFinale),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF5E8),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'המטרה',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFB0703A)),
                            ),
                            Text(
                              '${config.scoreRequired} נקודות',
                              style: const TextStyle(
                                fontWeight: FontWeight.w900,
                                fontSize: 28,
                                color: AppColors.primaryDark,
                                height: 1.15,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _StarGoal(stars: 1, points: config.oneStarScore),
                                _StarGoal(stars: 2, points: config.twoStarScore),
                                _StarGoal(stars: 3, points: config.threeStarScore),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _InfoChip(
                            icon: Icons.grid_view_rounded,
                            color: const Color(0xFF3A7BFF),
                            value: '${config.gridSize}×${config.gridSize}',
                            label: 'לוח',
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.timer_rounded,
                            color: const Color(0xFFFF7A45),
                            value: '${config.timeLimit.inSeconds}',
                            label: 'שניות',
                          ),
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.text_fields_rounded,
                            color: const Color(0xFF7B3FF2),
                            value: '${config.minWordLength}',
                            label: 'אותיות לפחות',
                          ),
                        ],
                      ),
                    ],
                  ),
                ).animate().fadeIn(duration: 250.ms).scale(
                  begin: const Offset(0.85, 0.85),
                  curve: Curves.easeOutBack,
                  duration: 450.ms,
                ),
                // סרט הכותרת "שלב N".
                Container(
                  constraints: const BoxConstraints(minWidth: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [ribbon.top, ribbon.bottom],
                    ),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(color: ribbon.lip, offset: const Offset(0, 5)),
                      const BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 8)),
                    ],
                  ),
                  child: Text(
                    'שלב $levelNumber',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: ribbon.text,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                      shadows: const [Shadow(color: Colors.black26, offset: Offset(0, 2), blurRadius: 2)],
                    ),
                  ),
                ).animate().fadeIn(delay: 120.ms).scale(
                  begin: const Offset(0.5, 0.5),
                  curve: Curves.elasticOut,
                  duration: 800.ms,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// הכוכבים הטובים ביותר שהושגו בשלב (ריקים בשלב חדש).
class _BestStars extends StatelessWidget {
  final int stars;
  const _BestStars({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i == 1 ? 8 : 0),
            child: Icon(
              Icons.star_rounded,
              size: i == 1 ? 46 : 38,
              color: i < stars ? AppColors.star : const Color(0xFFE6E0F3),
              shadows: i < stars ? const [Shadow(color: Color(0x88FFC107), blurRadius: 12)] : null,
            ),
          ).animate(delay: (200 + 120 * i).ms).scale(
            begin: const Offset(0.3, 0.3),
            curve: Curves.elasticOut,
            duration: 650.ms,
          ),
      ],
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;

  const _InfoChip({required this.icon, required this.color, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1.5),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17, color: color)),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11, color: Color(0xFF6B5E8F)),
            ),
          ],
        ),
      ),
    );
  }
}

/// תג "שלב מאסטר"/"שלב פינאלה" - מוצג רק על שלבים מיוחדים (ראו
/// [LevelConfig.isMasterLevel]/[LevelConfig.isWorldFinale]), כדי שהשחקן/ית
/// ידע/תדע מראש שהשלב הבא קשה יותר מהרגיל ומזכה בתגמול נדיב יותר.
class _LevelKindBadge extends StatelessWidget {
  final bool isFinale;

  const _LevelKindBadge({required this.isFinale});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isFinale ? const Color(0xFF7C4DFF) : const Color(0xFFFFA000),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isFinale ? Icons.emoji_events_rounded : Icons.bolt_rounded, color: Colors.white, size: 16),
          const SizedBox(width: 6),
          Text(
            isFinale ? 'שלב פינאלה - גלגל מזל בסיום!' : 'שלב מאסטר - מטבעות כפולות!',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 150.ms).scale(begin: const Offset(0.85, 0.85));
  }
}

class _StarGoal extends StatelessWidget {
  final int stars;
  final int points;

  const _StarGoal({required this.stars, required this.points});

  @override
  Widget build(BuildContext context) {
    // 3 כוכבים הם היעד המלא בדיוק (השלב מסתיים באותו רגע).
    final unit = points == 1 ? 'נקודה' : 'נקודות';
    final label = stars >= 3 ? '$points $unit' : '$points+ $unit';
    return Column(
      children: [
        Row(
          children: List.generate(stars, (i) => const Icon(Icons.star_rounded, color: AppColors.star, size: 18)),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: Color(0xFF4A3F6B)),
        ),
      ],
    );
  }
}
