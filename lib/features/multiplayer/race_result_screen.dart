import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/race_result.dart';

class RaceResultScreen extends StatefulWidget {
  final RaceResult result;

  const RaceResultScreen({super.key, required this.result});

  @override
  State<RaceResultScreen> createState() => _RaceResultScreenState();
}

class _RaceResultScreenState extends State<RaceResultScreen> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    if (widget.result.humanWon) {
      Future.delayed(const Duration(milliseconds: 400), () => _confetti.play());
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
          ),
        ),
        child: Stack(
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
            SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    result.humanWon ? '🏆 ניצחת בתחרות!' : 'התחרות הסתיימה',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w900,
                    ),
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                  const SizedBox(height: 12),
                  Center(
                    child: result.humanWon
                        ? Image.asset('assets/avatar/detective_celebrate.png', height: 120)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 1, end: 1.06, duration: 500.ms, curve: Curves.easeInOut)
                        : const MascotWidget(mood: MascotMood.sad, size: 100),
                  ),
                  const SizedBox(height: 24),
                  for (int i = 0; i < result.rankedParticipants.length; i++)
                    _RankRow(rank: i + 1, participant: result.rankedParticipants[i])
                        .animate(delay: (150 * i).ms)
                        .fadeIn()
                        .slideX(begin: 0.2, end: 0),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape:
                                RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          onPressed: () => context.pushReplacement('/multiplayer/setup'),
                          child: const Text('תחרות חדשה'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => context.go('/home'),
                          child: const Text('לתפריט הראשי'),
                        ),
                      ),
                    ],
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

class _RankRow extends StatelessWidget {
  final int rank;
  final RaceParticipantResult participant;

  const _RankRow({required this.rank, required this.participant});

  Color get _medalColor {
    switch (rank) {
      case 1:
        return AppColors.star;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.transparent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: participant.isHuman ? Colors.white : Colors.white.withValues(alpha: 0.85),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _medalColor == Colors.transparent
                  ? Colors.grey.shade300
                  : _medalColor,
              child: Text(
                '$rank',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                participant.isHuman ? '${participant.name} (את/ה)' : participant.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
            ),
            Text(
              '${participant.wordsFound} מילים',
              style: const TextStyle(color: Colors.black45, fontSize: 12),
            ),
            const SizedBox(width: 10),
            Text(
              '${participant.score} נק׳',
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
