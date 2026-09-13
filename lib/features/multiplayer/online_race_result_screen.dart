import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/race_result.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';

/// מסך תוצאות ל"משחק מול חברים" - דומה חזותית ל-[RaceResultScreen] (הקיים
/// למשחק מול המחשב, לא נוגעים בו) אך עם שלושה דברים שרלוונטיים רק כשיש
/// שחקנים אמיתיים בחדר: יחס ניצחונות/הפסדים מצטבר בין חברי החדר, כפתור
/// "משחק חוזר" (רק למנהל/ת), וניווט אוטומטי חזרה ללובי לכל השחקנים כשה-
/// "משחק חוזר" מופעל (סטטוס החדר חוזר ל-waiting).
class OnlineRaceResultScreen extends ConsumerStatefulWidget {
  final String roomCode;
  final RaceResult result;

  const OnlineRaceResultScreen({super.key, required this.roomCode, required this.result});

  @override
  ConsumerState<OnlineRaceResultScreen> createState() => _OnlineRaceResultScreenState();
}

class _OnlineRaceResultScreenState extends ConsumerState<OnlineRaceResultScreen> {
  late final MultiplayerRepository _repo;
  late final ConfettiController _confetti;
  StreamSubscription<GameRoom>? _roomSub;

  String? _myUid;
  GameRoom? _room;
  bool _isRestarting = false;
  bool _isLeaving = false;
  bool _navigatedToLobby = false;
  String? _actionError;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(multiplayerRepositoryProvider);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _repo.ensureSignedIn().then((uid) {
      if (mounted) setState(() => _myUid = uid);
    });
    _roomSub = _repo.watchRoom(widget.roomCode).listen(_onRoomUpdate, onError: (_) {});

    Future.delayed(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      if (widget.result.humanWon) {
        ref.read(soundServiceProvider).playLevelComplete();
        _confetti.play();
      } else {
        ref.read(soundServiceProvider).playError();
      }
    });
  }

  void _onRoomUpdate(GameRoom room) {
    setState(() => _room = room);

    // ה"משחק חוזר" הופעל (ע"י מנהל/ת החדר, אצל כל שחקן/ית) - סטטוס החדר
    // חוזר ל-waiting, וכל הלקוחות (כולל המנהל/ת עצמו/ה) מנווטים חזרה
    // ללובי כדי ללחוץ שוב "התחל משחק" על הלוח החדש.
    if (room.status == RoomStatus.waiting && !_navigatedToLobby) {
      _navigatedToLobby = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/multiplayer/online/room/${widget.roomCode}');
      });
    }
  }

  Future<void> _playAgain() async {
    setState(() {
      _isRestarting = true;
      _actionError = null;
    });
    try {
      await _repo.restartRoom(widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRestarting = false;
        _actionError = 'לא הצלחנו להתחיל משחק חוזר: $e';
      });
    }
  }

  Future<void> _exitToHome() async {
    setState(() => _isLeaving = true);
    try {
      await _repo.leaveRoom(widget.roomCode);
    } catch (_) {
      // עזיבה טובה-מאמץ.
    }
    if (mounted) context.go('/home');
  }

  @override
  void dispose() {
    _roomSub?.cancel();
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final room = _room;
    final isHost = room != null && _myUid != null && _myUid == room.hostUid;

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
                    result.humanWon ? '🏆 ניצחת בסבב!' : 'הסבב הסתיים',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
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
                  if (room != null && room.wins.isNotEmpty && room.players.length >= 2) ...[
                    const SizedBox(height: 20),
                    _HeadToHeadCard(room: room, myUid: _myUid)
                        .animate(delay: 300.ms)
                        .fadeIn()
                        .slideY(begin: 0.1, end: 0),
                  ],
                  const SizedBox(height: 32),
                  if (_actionError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _actionError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                    ),
                  if (isHost)
                    ElevatedButton(
                      onPressed: _isRestarting ? null : _playAgain,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isRestarting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('משחק חוזר 🔁'),
                    ).animate().fadeIn(delay: 200.ms)
                  else if (room != null)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'ממתינים שמנהל/ת החדר ילחץ/תלחץ על "משחק חוזר"...',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                    ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                    ),
                    onPressed: _isLeaving ? null : _exitToHome,
                    child: const Text('יציאה לתפריט הראשי'),
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
              backgroundColor: _medalColor == Colors.transparent ? Colors.grey.shade300 : _medalColor,
              child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                participant.isHuman ? '${participant.name} (את/ה)' : participant.name,
                style: TextStyle(
                  fontWeight: participant.isHuman ? FontWeight.w900 : FontWeight.w700,
                  fontSize: participant.isHuman ? 16 : 15,
                  color: participant.isHuman ? AppColors.accent : Colors.black87,
                ),
              ),
            ),
            Text('${participant.wordsFound} מילים', style: const TextStyle(color: Colors.black45, fontSize: 12)),
            const SizedBox(width: 10),
            Text(
              '${participant.score} נק׳',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: participant.isHuman ? 18 : 16,
                color: participant.isHuman ? AppColors.accent : Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// כרטיס "יחס ניצחונות/הפסדים" בין חברי החדר על פני כמה סבבי "משחק
/// חוזר" - למשל "1 : 2" כשיש בדיוק שני שחקנים בחדר.
class _HeadToHeadCard extends StatelessWidget {
  final GameRoom room;
  final String? myUid;

  const _HeadToHeadCard({required this.room, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final player in room.players)
        (
          name: player.uid == myUid ? '${player.displayName} (את/ה)' : player.displayName,
          wins: room.wins[player.uid] ?? 0,
        ),
    ];

    return Card(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text('יחס ניצחונות בחדר הזה', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 10),
            if (rows.length == 2)
              Text(
                '${rows[0].wins} : ${rows[1].wins}',
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 30, color: AppColors.accent),
              ),
            const SizedBox(height: 10),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Expanded(child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                    Text('${row.wins} ניצחונות', style: const TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
