import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ads/ads_runtime.dart';
import '../../core/cosmetics/cosmetic_catalog.dart';
import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/pressable.dart';
import '../share/share_achievement_sheet.dart';
import '../../providers/player_profile_provider.dart';
import '../ads/double_coins_cta.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/sound_provider.dart';
import 'game_screen.dart';
import 'widgets/fortune_wheel_dialog.dart';
import 'widgets/lucky_box_dialog.dart';
import 'widgets/mascot_widget.dart';

/// עבור תוצאה טובה (2-3 כוכבים) מציגים את הבלש מילולי חוגג עם השחקן/ית -
/// כדי שגם "מסך ההצלחה" יזכיר את הדמות המובילה של המשחק, כפי שהתבקש.
/// בשלב פינאלה (עולם חדש נפתח) הדמות גדולה יותר ורוקדת בעוצמה גבוהה יותר,
/// כדי שהרגע יורגש כמיוחד באמת.
class _CelebrationCharacter extends StatelessWidget {
  final int stars;
  final bool isBigCelebration;

  const _CelebrationCharacter({required this.stars, this.isBigCelebration = false});

  @override
  Widget build(BuildContext context) {
    if (stars >= 2 || isBigCelebration) {
      return Image.asset('assets/avatar/detective_celebrate.png', height: isBigCelebration ? 170 : 130)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: isBigCelebration ? 1.12 : 1.06,
            duration: isBigCelebration ? 380.ms : 500.ms,
            curve: Curves.easeInOut,
          );
    }
    final mood = stars == 1 ? MascotMood.happy : MascotMood.sad;
    return MascotWidget(mood: mood, size: 110);
  }
}

/// כרטיס "עולם חדש נפתח!" - מוצג רק בשלבי פינאלה שהושלמו בהצלחה (ראו
/// [LevelConfig.isWorldFinale] + lib/features/game/game_screen.dart).
/// מציג את שם העולם החדש, גודל הלוח החדש, ופרס נדיב (מטבעות + רמזים).
class _MilestoneBanner extends StatelessWidget {
  final String tierTitle;
  final int gridSize;
  final int bonusCoins;
  final int bonusHints;

  const _MilestoneBanner({
    required this.tierTitle,
    required this.gridSize,
    required this.bonusCoins,
    required this.bonusHints,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.star, Color(0xFFFF9A56)]),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16)],
          ),
          child: Column(
            children: [
              const Text(
                '🎉 עולם חדש נפתח!',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white),
              ),
              const SizedBox(height: 4),
              Text(
                '$tierTitle - לוח $gridSize×$gridSize',
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _PrizeChip(icon: Icons.monetization_on_rounded, label: '+$bonusCoins מטבעות'),
                  const SizedBox(width: 12),
                  _PrizeChip(icon: Icons.lightbulb_rounded, label: '+$bonusHints רמזים'),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 200.ms)
        .scale(begin: const Offset(0.85, 0.85), curve: Curves.elasticOut, duration: 700.ms);
  }
}

/// כרטיס "שלב מאסטר!" - מוצג כששלב מאסטר (ראו [LevelConfig.isMasterLevel])
/// הושלם בהצלחה. פחות "כבד" מ-[_MilestoneBanner] (אין פתיחת עולם), אבל
/// עדיין מדגיש שהמטבעות הוכפלו כתגמול על הקושי המוגבר.
class _MasterBanner extends StatelessWidget {
  const _MasterBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFFFA000), Color(0xFFFF7A45)]),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14)],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bolt_rounded, color: Colors.white, size: 22),
              SizedBox(width: 8),
              Text(
                'שלב מאסטר - מטבעות כפולות! ⚡',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 200.ms)
        .scale(begin: const Offset(0.85, 0.85), curve: Curves.elasticOut, duration: 600.ms);
  }
}

/// תג "סיימת לפני הזמן!" - מוצג כשהשלב הסתיים מיידית עם השגת יעד
/// המילים לפני שהשעון הגיע לאפס (ראו [GameScreenResult.finishedEarly]),
/// עם מספר השניות שנשארו כדי שההצלחה תורגש מוחשית וברורה.
class _EarlyFinishBadge extends StatelessWidget {
  final int secondsLeft;

  const _EarlyFinishBadge({required this.secondsLeft});

  @override
  Widget build(BuildContext context) {
    return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(20),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.bolt_rounded, color: AppColors.star, size: 20),
              const SizedBox(width: 6),
              Text(
                'סיימת לפני הזמן עם עוד $secondsLeft שניות בשעון! ⏱️',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(delay: 250.ms)
        .scale(begin: const Offset(0.85, 0.85), curve: Curves.elasticOut, duration: 600.ms);
  }
}

class _PrizeChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _PrizeChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryDark),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
        ],
      ),
    );
  }
}

/// מסך תוצאות שלב: חושף כוכבים אחד-אחד באנימציה, מציג קונפטי אם הושגו
/// לפחות 2 כוכבים, ומאפשר לשחק שוב או להמשיך לשלב הבא.
class LevelResultScreen extends ConsumerStatefulWidget {
  final int levelNumber;
  final GameScreenResult result;

  const LevelResultScreen({super.key, required this.levelNumber, required this.result});

  @override
  ConsumerState<LevelResultScreen> createState() => _LevelResultScreenState();
}

class _LevelResultScreenState extends ConsumerState<LevelResultScreen> {
  late final ConfettiController _confetti;
  late final Future<void> _levelRecorded;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _levelRecorded = ref.read(adsGatewayProvider).recordCampaignLevelFinished(widget.levelNumber);
    final isWorldFinale = widget.result.isWorldFinale;
    _confetti = ConfettiController(duration: Duration(seconds: isWorldFinale ? 4 : 2));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(soundServiceProvider).playLevelComplete();
      // חוגגים בקונפטי בכל שלב שהושלם בהצלחה (כוכב אחד ומעלה).
      if (widget.result.stars >= 1 || isWorldFinale) _confetti.play();
    });
    // תגמולי מזל (תיבת מזל / גלגל מזל) מוצגים כדיאלוג נפרד, אחרי שהחגיגה
    // הראשית על המסך כבר נראתה - גלגל המזל (סיום עולם) קודם לתיבת המזל
    // כי הוא הרגע הגדול יותר; שני אלה כמעט לעולם לא קורים באותו שלב
    // בפועל (25/50/75/100 אינם מתחלקים ב-7).
    Future.delayed(const Duration(milliseconds: 1400), _maybeShowRewardDialogs);
  }

  Future<void> _maybeShowRewardDialogs() async {
    if (!mounted || _leaving) return;
    final wheelPrize = widget.result.wheelPrize;
    final luckyBox = widget.result.luckyBoxReward;

    if (wheelPrize != null) {
      await FortuneWheelDialog.show(context, prizeIndex: widget.result.wheelPrizeIndex, prize: wheelPrize);
    }
    if (!mounted || _leaving) return;
    if (luckyBox != null) {
      await LuckyBoxDialog.show(context, luckyBox);
    }
  }

  Future<void> _skipFromResult() async {
    final cost = CoinCosts.skipLevel(widget.levelNumber);
    final ok = await ref.read(playerProfileProvider.notifier).skipLevel(levelNumber: widget.levelNumber, cost: cost);
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('אין מספיק מטבעות'),
          action: SnackBarAction(
            label: 'לחנות',
            onPressed: () {
              if (mounted) context.push('/store');
            },
          ),
        ),
      );
      return;
    }
    ref.read(soundServiceProvider).playCoin();
    final next = widget.levelNumber + 1;
    _exit(
      showAd: false,
      go: () {
        if (next > CampaignLevels.totalLevels) {
          context.go('/campaign');
        } else {
          context.pushReplacement('/level/$next/intro');
        }
      },
    );
  }

  /// "השלב הבא" יכול להציג אינטרסטיאל. "שחקו שוב" וחזרה לתפריט לא.
  Future<void> _exit({required bool showAd, required VoidCallback go}) async {
    if (_leaving) return;
    _leaving = true;
    try {
      await _levelRecorded;
      if (showAd && mounted) {
        await ref.read(adsGatewayProvider).showInterstitialIfAllowed(levelNumber: widget.levelNumber);
      }
    } finally {
      if (mounted) go();
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _goNext() {
    _exit(
      showAd: true,
      go: () {
        final next = widget.levelNumber + 1;
        if (next > CampaignLevels.totalLevels) {
          context.go('/campaign');
        } else {
          context.pushReplacement('/level/$next/intro');
        }
      },
    );
  }

  void _replay() => _exit(showAd: false, go: () => context.pushReplacement('/level/${widget.levelNumber}/intro'));

  void _share() {
    final config = CampaignLevels.byLevelNumber(widget.levelNumber);
    final result = widget.result;
    showShareAchievementSheet(
      context,
      ShareAchievement.level(
        levelNumber: widget.levelNumber,
        stars: result.stars,
        score: result.score,
        words: result.foundWordsCount,
        colors: AppColors.gradientForWorldIndex(config.tier.index),
        newWorld: result.isWorldFinale,
        worldTitle: result.newTierTitle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = CampaignLevels.byLevelNumber(widget.levelNumber);
    final result = widget.result;
    final passed = result.stars > 0;

    // "חזרה" של המערכת (כפתור באנדרואיד / החלקה) לא מחזירה לשלב שהסתיים
    // אלא למפת השלבים - בדיוק כמו כפתור הבית.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _exit(showAd: false, go: () => context.go('/campaign'));
      },
      child: GameScaffold(
        colors: AppColors.gradientForWorldIndex(config.tier.index),
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              CandyIconButton(
                icon: Icons.map_rounded,
                tooltip: 'מפת השלבים',
                onPressed: () => _exit(showAd: false, go: () => context.go('/campaign')),
              ),
              const Spacer(),
              Text(
                'שלב ${widget.levelNumber}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  shadows: [Shadow(color: Colors.black26, blurRadius: 6, offset: Offset(0, 2))],
                ),
              ),
              const Spacer(),
              CandyIconButton(
                icon: Icons.home_rounded,
                tooltip: 'תפריט ראשי',
                onPressed: () => _exit(showAd: false, go: () => context.go('/home')),
              ),
            ],
          ),
        ),
        bottomBar: Row(
          children: [
            Expanded(
              flex: 2,
              child: CandyButton(
                label: passed ? 'שחקו שוב' : 'נסו שוב',
                icon: Icons.replay_rounded,
                palette: passed ? CandyPalette.white : CandyPalette.green,
                height: 58,
                fontSize: 18,
                onPressed: _replay,
              ),
            ),
            if (passed) ...[
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: CandyButton(
                  label: 'השלב הבא',
                  icon: Icons.arrow_forward_rounded,
                  palette: CandyPalette.green,
                  height: 58,
                  fontSize: 20,
                  onPressed: _goNext,
                ),
              ),
            ],
          ],
        ).animate().fadeIn(delay: 1100.ms, duration: 300.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: result.isWorldFinale ? 60 : 24,
                gravity: 0.25,
                colors: const [AppColors.star, AppColors.primary, AppColors.success, Colors.white],
              ),
            ),
            LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 8),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                                result.finishedEarly
                                    ? 'סיימת לפני הזמן! 🎉'
                                    : (passed ? (result.stars >= 3 ? 'מושלם!' : 'כל הכבוד!') : 'כמעט הצלחת!'),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 34,
                                  fontWeight: FontWeight.w900,
                                  shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
                                ),
                              )
                              .animate()
                              .fadeIn(duration: 300.ms)
                              .scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 800.ms),
                          if (result.finishedEarly) ...[
                            const SizedBox(height: 10),
                            _EarlyFinishBadge(secondsLeft: result.secondsLeftWhenFinished),
                          ],
                          const SizedBox(height: 8),
                          _CelebrationCharacter(stars: result.stars, isBigCelebration: result.isWorldFinale),
                          if (result.isWorldFinale) ...[
                            const SizedBox(height: 14),
                            _MilestoneBanner(
                              tierTitle: result.newTierTitle ?? '',
                              gridSize: result.newGridSize ?? config.gridSize,
                              bonusCoins: result.bonusCoins,
                              bonusHints: result.bonusHints,
                            ),
                          ] else if (result.isMasterLevel) ...[
                            const SizedBox(height: 14),
                            const _MasterBanner(),
                          ],
                          const SizedBox(height: 14),
                          _StarsArc(stars: result.stars),
                          const SizedBox(height: 18),
                          _ResultCard(
                            result: result,
                            scoreRequired: config.scoreRequired,
                          ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.15, end: 0, curve: Curves.easeOutCubic),
                          if (passed) ...[
                            const SizedBox(height: 14),
                            _ShareAchievementButton(onTap: _share)
                                .animate()
                                .fadeIn(delay: 1300.ms)
                                .scale(begin: const Offset(0.8, 0.8), curve: Curves.easeOutBack),
                          ] else ...[
                            const SizedBox(height: 16),
                            Text(
                              'צריך לפחות כוכב אחד כדי לעבור שלב',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.95),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            CandyButton(
                              label: 'דלגו על השלב',
                              subtitle: '${CoinCosts.skipLevel(widget.levelNumber)} מטבעות',
                              icon: Icons.skip_next_rounded,
                              palette: CandyPalette.gold,
                              height: 54,
                              fontSize: 17,
                              onPressed: _skipFromResult,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// שלושה כוכבים בקשת (האמצעי גדול ומורם), שנחשפים בזה אחר זה בקפיצה -
/// הרגע הכי "מתגמל" במסך התוצאות.
class _StarsArc extends StatelessWidget {
  final int stars;
  const _StarsArc({required this.stars});

  @override
  Widget build(BuildContext context) {
    Widget star(int i, double size, double lift) {
      final filled = i < stars;
      return Transform.translate(
            offset: Offset(0, -lift),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.star_rounded, size: size, color: Colors.black.withValues(alpha: 0.12)),
                Icon(
                  Icons.star_rounded,
                  size: size * 0.94,
                  color: filled ? AppColors.star : Colors.white.withValues(alpha: 0.45),
                  shadows: filled ? const [Shadow(color: Color(0xAAFFC107), blurRadius: 18)] : null,
                ),
              ],
            ),
          )
          .animate(delay: (350 + i * 260).ms)
          .scale(begin: const Offset(0, 0), end: const Offset(1, 1), curve: Curves.elasticOut, duration: 700.ms)
          .rotate(begin: filled ? -0.15 : 0, end: 0, duration: 500.ms, curve: Curves.easeOut)
          .then()
          .shimmer(duration: filled ? 900.ms : 1.ms, color: Colors.white70);
    }

    // סדר התצוגה: ימין->שמאל ב-RTL, כך שהכוכב הראשון נחשף מימין.
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [star(0, 62, 0), const SizedBox(width: 6), star(1, 80, 14), const SizedBox(width: 6), star(2, 62, 0)],
    );
  }
}

class _ResultCard extends StatelessWidget {
  final GameScreenResult result;
  final int scoreRequired;

  const _ResultCard({required this.result, required this.scoreRequired});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // הניקוד "רץ" מ-0 עד התוצאה - מרגיש כמו ספירת נקודות במשחק.
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: 0, end: result.score),
            duration: const Duration(milliseconds: 1100),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Column(
              children: [
                Text(
                  '$value',
                  style: const TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                    height: 1,
                  ),
                ),
                const Text(
                  'נקודות',
                  style: TextStyle(fontWeight: FontWeight.w700, color: Colors.black45),
                ),
              ],
            ),
          ),
          const Divider(height: 22),
          _StatRow(label: 'יעד נקודות', value: '$scoreRequired'),
          const SizedBox(height: 8),
          _StatRow(label: 'מילים שמצאת', value: '${result.foundWordsCount} מתוך ${result.totalPossibleWords}'),
          const SizedBox(height: 8),
          _StatRow(label: 'מטבעות שהורווחו', value: '+${result.coinsEarned}', valueColor: Colors.amber.shade800),
          if (result.stars > 0) DoubleCoinsCta(coins: result.coinsEarned),
        ],
      ),
    );
  }
}

/// כפתור "שתפו את ההישג" - גלולה לבנה עם סמלי פייסבוק ווואטסאפ.
class _ShareAchievementButton extends StatelessWidget {
  final VoidCallback onTap;
  const _ShareAchievementButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget dot(Color c, Widget child) => Container(
      width: 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
      child: child,
    );
    return Pressable(
      onTap: onTap,
      semanticLabel: 'שיתוף ההישג',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 5))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            dot(
              const Color(0xFF1877F2),
              const Text(
                'f',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
            const SizedBox(width: 4),
            dot(const Color(0xFF25D366), const Icon(Icons.chat_rounded, color: Colors.white, size: 16)),
            const SizedBox(width: 10),
            const Text(
              'שתפו את ההישג',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFF2D2250)),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _StatRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        ),
        const SizedBox(width: 8),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: valueColor),
        ),
      ],
    );
  }
}
