import 'dart:async';

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/social_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import '../share/share_achievement_sheet.dart';
import '../social/social_actions.dart';
import 'widgets/race_podium.dart';
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
    final byName = {for (final p in widget.result.rankedParticipants) p.name: p};
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
    final tied = standings.where((s) => s.wins == first.wins && s.lastScore == first.lastScore).toList();
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
      _potBanner = tied.length == 1 ? 'הזוכה מקבל/ת ${room.pot} מטבעות!' : 'תיקו — $share מטבעות לכל אחד';
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

  void _share(GameRoom? room) {
    final result = widget.result;
    final me = result.rankedParticipants.firstWhere((p) => p.isHuman, orElse: () => result.rankedParticipants.first);
    showShareAchievementSheet(
      context,
      ShareAchievement.raceWin(
        score: me.score,
        opponents: [
          for (final p in result.rankedParticipants)
            if (!p.isHuman) p.name,
        ],
        vsFriends: true,
        seriesLabel: room != null && room.isSeries ? '${room.wins[_myUid] ?? 0} ניצחונות בסדרה' : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final result = widget.result;
    final room = _room;
    final isHost = room != null && _myUid != null && _myUid == room.hostUid;
    final isFinale = room == null || room.isLastRound;
    final isSeriesFinale = room != null && room.isSeries && room.isLastRound;
    final iWonSeries = isSeriesFinale && _standingsFor(room).first.player.uid == _myUid;
    final canShare = result.humanWon || iWonSeries;
    final social = ref.watch(socialRepositoryProvider);
    final friendIds = {for (final f in ref.watch(friendsProvider).valueOrNull ?? const []) f.profile.uid};
    final strangers = [
      if (room != null && social.isAvailable)
        for (final p in room.players)
          if (p.uid != _myUid && !friendIds.contains(p.uid)) p,
    ];

    PlayerInRoom? playerNamed(String name) {
      if (room == null) return null;
      for (final p in room.players) {
        if (p.displayName == name) return p;
      }
      return null;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isLeaving) _exitToHome();
      },
      child: GameScaffold(
        colors: const [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
        header: GameHeader(
          title: _titleFor(result, room),
          subtitle: room != null && room.isSeries && !isSeriesFinale ? room.roundLabel : null,
          backIcon: Icons.home_rounded,
          onBack: _isLeaving ? null : _exitToHome,
          trailing: canShare
              ? CandyIconButton(icon: Icons.ios_share_rounded, tooltip: 'שיתוף', onPressed: () => _share(room))
              : null,
        ),
        bottomBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_actionError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                  _actionError!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            if (!isFinale && isHost)
              CandyButton(
                label: 'הסבב הבא',
                icon: Icons.rocket_launch_rounded,
                palette: CandyPalette.green,
                loading: _isAdvancing,
                onPressed: _isAdvancing ? null : _nextRound,
              ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack)
            else if (!isFinale)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        'ממתינים לסבב הבא...',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
            if (isFinale)
              CandyButton(
                label: 'יציאה לתפריט הראשי',
                icon: Icons.home_rounded,
                palette: CandyPalette.white,
                height: 56,
                fontSize: 18,
                loading: _isLeaving,
                onPressed: _isLeaving ? null : _exitToHome,
              ).animate().fadeIn(delay: 1000.ms).slideY(begin: 0.4, end: 0, curve: Curves.easeOutBack),
          ],
        ),
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
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
              children: [
                Center(
                  child: result.humanWon || iWonSeries
                      ? Image.asset('assets/avatar/detective_celebrate.png', height: 104)
                            .animate(onPlay: (c) => c.repeat(reverse: true))
                            .scaleXY(begin: 1, end: 1.06, duration: 500.ms, curve: Curves.easeInOut)
                      : const MascotWidget(mood: MascotMood.sad, size: 88),
                ),
                const SizedBox(height: 14),
                if (isSeriesFinale)
                  ..._championsTable(room)
                else
                  RacePodium(
                    entries: [
                      for (final p in result.rankedParticipants)
                        PodiumEntry(
                          name: p.name,
                          score: p.score,
                          wordsFound: p.wordsFound,
                          isMe: p.isHuman,
                          avatarId: playerNamed(p.name)?.avatarId ?? 'detective',
                          photoUrl: playerNamed(p.name)?.photoUrl,
                          wins: room != null && room.isSeries ? (room.wins[playerNamed(p.name)?.uid] ?? 0) : null,
                        ),
                    ],
                  ),
                if (room != null && room.wins.isNotEmpty && room.players.length >= 2 && !isSeriesFinale) ...[
                  const SizedBox(height: 20),
                  _HeadToHeadCard(room: room, myUid: _myUid).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, end: 0),
                ],
                if (_potBanner != null) ...[const SizedBox(height: 16), _PotBanner(text: _potBanner!)],
                if (strangers.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _AddPlayersCard(
                    players: strangers,
                    onAdd: (p) => SocialActions.sendFriendRequest(context, ref, uid: p.uid, name: p.displayName),
                  ).animate(delay: 1200.ms).fadeIn().slideY(begin: 0.15, end: 0),
                ],
              ],
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
        _ChampionRow(
          rank: i + 1,
          standing: standings[i],
          isMe: standings[i].player.uid == _myUid,
        ).animate(delay: (150 * i).ms).fadeIn().slideX(begin: 0.2, end: 0),
    ];
  }
}

class _Standing {
  final PlayerInRoom player;
  final int wins;
  final int lastScore;

  const _Standing({required this.player, required this.wins, required this.lastScore});
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
              child: Text(
                '$rank',
                style: const TextStyle(fontWeight: FontWeight.w800, color: Colors.white),
              ),
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
                Text('${standing.wins} ניצחונות', style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14)),
                Text('${standing.lastScore} נק׳ בסבב', style: const TextStyle(color: Colors.black45, fontSize: 11)),
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
                    Expanded(
                      child: Text(row.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
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

/// "שיחקתם יחד - רוצים להיות חברים?": כרטיס עם השחקנים מהחדר שעדיין לא
/// ברשימת החברים, וכפתור שליחת בקשה לכל אחד/ת.
class _AddPlayersCard extends StatefulWidget {
  final List<PlayerInRoom> players;
  final Future<void> Function(PlayerInRoom player) onAdd;

  const _AddPlayersCard({required this.players, required this.onAdd});

  @override
  State<_AddPlayersCard> createState() => _AddPlayersCardState();
}

class _AddPlayersCardState extends State<_AddPlayersCard> {
  final Set<String> _sent = {};

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'שיחקתם יחד - רוצים להיות חברים?',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF4A2F8F)),
          ),
          const SizedBox(height: 8),
          for (final p in widget.players)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  AvatarWidget(avatarId: p.avatarId ?? 'detective', photoUrl: p.photoUrl, size: 38, ring: false),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(p.displayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  ),
                  SizedBox(
                    width: 112,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                      child: _sent.contains(p.uid)
                          ? const Row(
                              key: ValueKey('sent'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
                                SizedBox(width: 4),
                                Text(
                                  'נשלח',
                                  style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
                                ),
                              ],
                            )
                          : CandyButton(
                              key: const ValueKey('add'),
                              label: 'הוספה',
                              icon: Icons.person_add_alt_1_rounded,
                              palette: CandyPalette.purple,
                              height: 40,
                              fontSize: 14,
                              radius: 14,
                              onPressed: () async {
                                await widget.onAdd(p);
                                if (mounted) setState(() => _sent.add(p.uid));
                              },
                            ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
