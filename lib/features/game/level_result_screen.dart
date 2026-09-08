import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../game_engine/models/level_config.dart';
import '../../providers/sound_provider.dart';
import 'game_screen.dart';
import 'widgets/mascot_widget.dart';

/// עבור תוצאה טובה (2-3 כוכבים) מציגים את הבלש מילולי חוגג עם השחקן/ית -
/// כדי שגם "מסך ההצלחה" יזכיר את הדמות המובילה של המשחק, כפי שהתבקש.
class _CelebrationCharacter extends StatelessWidget {
  final int stars;

  const _CelebrationCharacter({required this.stars});

  @override
  Widget build(BuildContext context) {
    if (stars >= 2) {
      return Image.asset('assets/avatar/detective_celebrate.png', height: 130)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.06, duration: 500.ms, curve: Curves.easeInOut);
    }
    final mood = stars == 1 ? MascotMood.happy : MascotMood.sad;
    return MascotWidget(mood: mood, size: 110);
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

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      ref.read(soundServiceProvider).playLevelComplete();
      if (widget.result.stars >= 2) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final config = CampaignLevels.byLevelNumber(widget.levelNumber);
    final result = widget.result;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: AppColors.gradientForWorldIndex(config.tier.index),
          ),
        ),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                shouldLoop: false,
                numberOfParticles: 24,
                gravity: 0.25,
                colors: const [
                  AppColors.star,
                  AppColors.primary,
                  AppColors.success,
                  Colors.white,
                ],
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const Spacer(),
                    Text(
                      result.stars > 0 ? 'כל הכבוד!' : 'כמעט הצלחת!',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.w900,
                      ),
                    ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                    const SizedBox(height: 12),
                    _CelebrationCharacter(stars: result.stars),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(3, (i) {
                        final filled = i < result.stars;
                        return Icon(
                          Icons.star_rounded,
                          size: 56,
                          color: filled ? AppColors.star : AppColors.starEmpty,
                        )
                            .animate(delay: (300 + i * 200).ms)
                            .scale(
                              begin: const Offset(0, 0),
                              end: const Offset(1, 1),
                              curve: Curves.elasticOut,
                              duration: 600.ms,
                            )
                            .then()
                            .shake(hz: filled ? 3 : 0, curve: Curves.easeInOut);
                      }),
                    ),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _StatRow(label: 'ניקוד', value: '${result.score}'),
                            const Divider(height: 20),
                            _StatRow(
                              label: 'מילים שנמצאו',
                              value: '${result.foundWordsCount} מתוך ${result.totalPossibleWords}',
                            ),
                            const Divider(height: 20),
                            _StatRow(
                              label: 'מטבעות שהורווחו',
                              value: '+${result.coinsEarned}',
                              valueColor: Colors.amber.shade800,
                            ),
                          ],
                        ),
                      ),
                    ).animate().fadeIn(delay: 900.ms).slideY(begin: 0.15, end: 0),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            onPressed: () =>
                                context.pushReplacement('/level/${widget.levelNumber}/intro'),
                            child: const Text('שחקו שוב'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              if (result.stars > 0) {
                                context.pushReplacement(
                                  '/level/${widget.levelNumber + 1}/intro',
                                );
                              } else {
                                context.go('/campaign');
                              }
                            },
                            child: Text(result.stars > 0 ? 'השלב הבא' : 'למפת השלבים'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
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
        Text(label, style: const TextStyle(fontSize: 15, color: Colors.black54)),
        const Spacer(),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16, color: valueColor),
        ),
      ],
    );
  }
}