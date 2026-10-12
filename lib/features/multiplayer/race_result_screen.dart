import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/mascot_widget.dart';
import '../share/share_achievement_sheet.dart';
import 'models/race_result.dart';
import 'widgets/race_podium.dart';
import '../../core/feedback/haptics.dart';
import '../../game_engine/rewards/rarity.dart';

class RaceResultScreen extends ConsumerStatefulWidget {
  final RaceResult result;

  const RaceResultScreen({super.key, required this.result});

  @override
  ConsumerState<RaceResultScreen> createState() => _RaceResultScreenState();
}

class _RaceResultScreenState extends ConsumerState<RaceResultScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (widget.result.humanWon) {
        ref.read(soundServiceProvider).playLevelComplete();
        _confetti.play();
        Haptics.celebrate(Rarity.rare);
      } else {
        ref.read(soundServiceProvider).playError();
      }
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _share() {
    final result = widget.result;
    final me = result.rankedParticipants.firstWhere((p) => p.isHuman);
    showShareAchievementSheet(
      context,
      ShareAchievement.raceWin(
        score: me.score,
        opponents: [
          for (final p in result.rankedParticipants)
            if (!p.isHuman) p.name,
        ],
        vsFriends: false,
      ),
    );
  }

  void _again() {
    final config = widget.result.config;
    if (config != null) {
      context.pushReplacement('/multiplayer/race', extra: config);
    } else {
      context.pushReplacement('/multiplayer/setup');
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final profile = ref.watch(playerProfileProvider).valueOrNull;
    final photo = ref.watch(authStateProvider).valueOrNull?.photoUrl;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/home');
      },
      child: GameScaffold(
        colors: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
        header: GameHeader(
          title: 'תוצאות התחרות',
          backIcon: Icons.home_rounded,
          onBack: () => context.go('/home'),
          trailing: result.humanWon
              ? CandyIconButton(icon: Icons.ios_share_rounded, tooltip: 'שיתוף', onPressed: _share)
              : null,
        ),
        bottomBar: Row(
          children: [
            Expanded(
              flex: 2,
              child: CandyButton(
                label: 'הגדרות',
                icon: Icons.tune_rounded,
                palette: CandyPalette.white,
                height: 56,
                fontSize: 16,
                onPressed: () => context.pushReplacement('/multiplayer/setup'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: CandyButton(
                label: result.humanWon ? 'עוד סיבוב' : 'נקמה!',
                icon: Icons.replay_rounded,
                palette: CandyPalette.green,
                height: 56,
                fontSize: 19,
                onPressed: _again,
              ),
            ),
          ],
        ).animate().fadeIn(delay: 1100.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
        body: Stack(
          children: [
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                numberOfParticles: 26,
                shouldLoop: false,
                colors: const [AppColors.star, AppColors.primary, Colors.white],
              ),
            ),
            ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              children: [
                Text(
                  result.humanWon ? 'ניצחת! 🏆' : (result.humanRank == 2 ? 'כמעט! מקום שני' : 'התחרות הסתיימה'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    shadows: [Shadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, 3))],
                  ),
                ).animate().fadeIn().scale(begin: const Offset(0.6, 0.6), curve: Curves.elasticOut, duration: 800.ms),
                const SizedBox(height: 8),
                Center(
                  child: result.humanWon
                      ? Image.asset('assets/avatar/detective_celebrate.png', height: 110)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 1, end: 1.06, duration: 500.ms, curve: Curves.easeInOut)
                      : const MascotWidget(mood: MascotMood.sad, size: 92),
                ),
                const SizedBox(height: 18),
                RacePodium(
                  entries: [
                    for (final p in result.rankedParticipants)
                      PodiumEntry(
                        name: p.name,
                        score: p.score,
                        wordsFound: p.wordsFound,
                        isMe: p.isHuman,
                        avatarId: p.isHuman ? (profile?.avatarId ?? 'detective') : null,
                        photoUrl: p.isHuman ? photo : null,
                      ),
                  ],
                ),
                if (result.humanWon) ...[
                  const SizedBox(height: 20),
                  Center(
                    child: TextButton.icon(
                      onPressed: _share,
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('שתפו את הניצחון', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                    ),
                  ).animate().fadeIn(delay: 1300.ms),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
