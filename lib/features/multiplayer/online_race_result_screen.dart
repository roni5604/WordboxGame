import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/sound_provider.dart';
import '../game/widgets/mascot_widget.dart';
import 'models/race_result.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';

/// מסך תוצאות ל"משחק מול חברים": סבב ביניים (הסבב הבא) או חגיגת סיום
/// עם טבלת אלופים ומסירת הקופה לזוכה.
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
  bool _isAdvancing = false;
  bool _isLeaving = false;
  bool _navigatedAway = false;
  bool _potCredited = false;
  String? _actionError;
  String? _potBanner;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(multiplayerRepositoryProvider);
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _repo.ensureSignedIn().then((uid) {
      if (!mounted) return;
      setState(() => _myUid = uid);
      final room = _room;
      if (room != null) _maybeAwardPot(room);
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
    _maybeAwardPot(room);

    if (_navigatedAway) return;

    if (room.status == RoomStatus.inProgress) {
      _navigatedAway = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/multiplayer/online/race/${widget.roomCode}');
      });
      return;
    }

    if (room.status == RoomStatus.waiting) {
      _navigatedAway = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.pushReplacement('/multiplayer/online/room/${widget.roomCode}');
      });
    }
  }

  List<_Standing> _standingsFor(GameRoom room) {
    final byName = {
      for (final p in widget.result.rankedParticipants) p.name: p,
    };
    return [
      for (final player in room.players)
        _Standing(
          player: player,
          wins: room.wins[player.uid] ?? 0,
          lastScore: byName[player.displayName]?.score ?? player.score,
        ),
    ]..sort((a, b) {
        final winCompare = b.wins.compareTo(a.wins);
        if (winCompare != 0) return winCompare;
        return b.lastScore.compareTo(a.lastScore);
      });
  }

  void _maybeAwardPot(GameRoom room) {
    if (_potCredited || !room.isLastRound || room.pot <= 0 || _myUid == null) return;
    if (room.players.isEmpty) return;

    final standings = _standingsFor(room);
    if (standings.isEmpty) return;
    final first = standings.first;
    final tied = standings
        .where((s) => s.wins == first.wins && s.lastScore == first.lastScore)
        .toList();
    if (!tied.any((s) => s.player.uid == _myUid)) {
      _potCredited = true;
      if (tied.length == 1) {
        _potBanner = '${tied.single.player.displayName} מקבל/ת ${room.pot} מטבעות!';
      } else {
        final share = room.pot ~/ tied.length;
        _potBanner = 'תיקו — $share מטבעות לכל אחד';
      }
      return;
    }

    _potCredited = true;
    final share = room.pot ~/ tied.length;
    if (share > 0) {
      ref.read(playerProfileProvider.notifier).addCoins(share);
    }
    setState(() {
      _potBanner = tied.length == 1
          ? 'הזוכה מקבל/ת ${room.pot} מטבעות!'
          : 'תיקו — $share מטבעות לכל אחד';
    });
    _confetti.play();
  }

  Future<void> _nextRound() async {
    setState(() {
      _isAdvancing = true;
      _actionError = null;
    });
    try {
      await _repo.startNextRound(widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAdvancing = false;
        _actionError = 'לא הצלחנו להתחיל את הסבב הבא: $e';
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
    final isFinale = room == null || room.isLastRound;
    final isSeriesFinale = room != null && room.isSeries && room.isLastRound;

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
                    _titleFor(result, room),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
                  ).animate().fadeIn().slideY(begin: -0.2, end: 0),
                  if (room != null && room.isSeries) ...[
                    const SizedBox(height: 8),
                    Text(
                      room.roundLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Center(
                    child: result.humanWon || isSeriesFinale
                        ? Image.asset('assets/avatar/detective_celebrate.png', height: 120)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 1, end: 1.06, duration: 500.ms, curve: Curves.easeInOut)
                        : const MascotWidget(mood: MascotMood.sad, size: 100),
                  ),
                  const SizedBox(height: 24),
                  if (isSeriesFinale)
                    ..._championsTable(room)
                  else
                    for (int i = 0; i < result.rankedParticipants.length; i++)
                      _RankRow(rank: i + 1, participant: result.rankedParticipants[i])
                          .animate(delay: (150 * i).ms)
                          .fadeIn()
                          .slideX(begin: 0.2, end: 0),
                  if (room != null && room.wins.isNotEmpty && room.players.length >= 2 && !isSeriesFinale) ...[
                    const SizedBox(height: 20),
                    _HeadToHeadCard(room: room, myUid: _myUid)
                        .animate(delay: 300.ms)
                        .fadeIn()
                        .slideY(begin: 0.1, end: 0),
                  ],
                  if (_potBanner != null) ...[
                    const SizedBox(height: 16),
                    _PotBanner(text: _potBanner!),
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
                  if (!isFinale && isHost)
                    ElevatedButton(
                      onPressed: _isAdvancing ? null : _nextRound,
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: _isAdvancing
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                            )
                          : const Text('הסבב הבא 🚀'),
                    ).animate().fadeIn(delay: 200.ms)
                  else if (!isFinale)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'ממתינים לסבב הבא...',
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

  String _titleFor(RaceResult result, GameRoom? room) {
    if (room != null && room.isSeries && room.isLastRound) return 'טבלת האלופים';
    if (room != null && room.isSeries) return 'הסבב הסתיים';
    return result.humanWon ? '🏆 ניצחת בסבב!' : 'הסבב הסתיים';
  }

  List<Widget> _championsTable(GameRoom room) {
    final standings = _standingsFor(room);
    return [
      for (int i = 0; i < standings.length; i++)
        _ChampionRow(rank: i + 1, standing: standings[i], isMe: standings[i].player.uid == _myUid)
            .animate(delay: (150 * i).ms)
            .fadeIn()
            .slideX(begin: 0.2, end: 0),
    ];
  }
}

class _Standing {
  final PlayerInRoom player;
  final int wins;
  final int lastScore;

  const _Standing({required this.player, required this.wins, required this.lastScore});
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

class _ChampionRow extends StatelessWidget {
  final int rank;
  final _Standing standing;
  final bool isMe;

  const _ChampionRow({required this.rank, required this.standing, required this.isMe});

  Color get _medalColor {
    switch (rank) {
      case 1:
        return AppColors.star;
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = isMe ? '${standing.player.displayName} (את/ה)' : standing.player.displayName;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: isMe ? Colors.white : Colors.white.withValues(alpha: 0.88),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: _medalColor,
              child: Text('$rank', style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontWeight: isMe ? FontWeight.w900 : FontWeight.w700,
                  fontSize: 16,
                  color: isMe ? AppColors.accent : Colors.black87,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${standing.wins} ניצחונות',
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14),
                ),
                Text(
                  '${standing.lastScore} נק׳ בסבב',
                  style: const TextStyle(color: Colors.black45, fontSize: 11),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PotBanner extends StatelessWidget {
  final String text;

  const _PotBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.star,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const Icon(Icons.monetization_on_rounded, color: AppColors.textDark, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: AppColors.textDark),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.94, 0.94));
  }
}

/// כרטיס ניצחונות מצטבר בין חברי החדר על פני סבבי הסדרה.
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
            const Text('ניצחונות עד כה', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
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
