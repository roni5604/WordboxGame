import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';
import '../../providers/multiplayer_repository_provider.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';
import '../game/widgets/mascot_widget.dart';

/// חדר המתנה: מציג את קוד החדר לשיתוף, רשימת שחקנים חיה, וכפתור
/// "התחל משחק" (למנהל/ת החדר בלבד). כשהמנהל/ת מתחיל/ה, כל השחקנים
/// מנותבים אוטומטית למסך המשחק (ראו online_race_screen.dart) ברגע
/// שסטטוס החדר משתנה ל-inProgress.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  final String roomCode;

  const RoomLobbyScreen({super.key, required this.roomCode});

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  late final MultiplayerRepository _repo;
  late final Stream<GameRoom> _roomStream;
  String? _myUid;
  bool _navigatedToRace = false;
  bool _isStarting = false;
  bool _isLeaving = false;
  String? _actionError;
  Timer? _clockTicker;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(multiplayerRepositoryProvider);
    _roomStream = _repo.watchRoom(widget.roomCode);
    _repo.ensureSignedIn().then((uid) {
      if (mounted) setState(() => _myUid = uid);
    });
    // רק כדי שספירת "ניתן להצטרף עוד X" תתקדם חיה בלי תלות בעדכון מרוחק.
    _clockTicker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _clockTicker?.cancel();
    super.dispose();
  }

  Future<void> _leave() async {
    setState(() => _isLeaving = true);
    try {
      await _repo.leaveRoom(widget.roomCode);
    } catch (_) {
      // עזיבה טובה-מאמץ - לא חוסמים את היציאה מהמסך גם אם נכשלה.
    }
    if (mounted) context.go('/multiplayer');
  }

  Future<void> _startGame() async {
    setState(() {
      _isStarting = true;
      _actionError = null;
    });
    try {
      await _repo.startGame(widget.roomCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isStarting = false;
        _actionError = 'לא הצלחנו להתחיל את המשחק: $e';
      });
    }
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('הקוד הועתק! שלחו אותו לחברים 📋')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('חדר המתנה'),
        backgroundColor: AppColors.primaryDark,
        leading: BackButton(onPressed: _isLeaving ? null : _leave),
      ),
      backgroundColor: AppColors.background,
      body: StreamBuilder<GameRoom>(
        stream: _roomStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'החדר לא נמצא, או שהתרחשה שגיאה.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            );
          }
          final room = snapshot.data;
          if (room == null) {
            return const Center(child: CircularProgressIndicator(color: Colors.white));
          }

          // המנהל/ת עדיין לא נעלם/ת מרשימת השחקנים כל עוד לא עזב/ה בעצמו/ה -
          // אם אין אף שחקן/ית עם isHost==true, המנהל/ת עזב/ה לפני שהמשחק התחיל.
          final hostStillPresent = room.players.any((p) => p.isHost);

          if (room.status == RoomStatus.inProgress && !_navigatedToRace) {
            _navigatedToRace = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) context.pushReplacement('/multiplayer/online/race/${room.roomCode}');
            });
          }

          final isHost = _myUid != null && _myUid == room.hostUid;
          final canStart = room.players.length >= 2 && !_isStarting;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Center(child: MascotWidget(mood: MascotMood.excited, size: 80)),
              const SizedBox(height: 16),
              _RoomCodeCard(roomCode: room.roomCode, onCopy: _copyCode),
              const SizedBox(height: 16),
              if (!hostStillPresent)
                Card(
                  color: AppColors.error.withValues(alpha: 0.9),
                  child: const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'מנהל/ת החדר עזב/ה לפני שהמשחק התחיל. אפשר לחזור ולהצטרף\n'
                      'לחדר אחר, או ליצור חדר חדש.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ).animate().fadeIn(),
              const SizedBox(height: 8),
              _SettingsSummary(room: room),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('שחקנים בחדר (${room.players.length}/${room.maxPlayers})',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 12),
                      for (final player in room.players)
                        _PlayerRow(player: player, isMe: player.uid == _myUid),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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
                  onPressed: (canStart && hostStillPresent) ? _startGame : null,
                  child: _isStarting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                        )
                      : Text(room.players.length < 2 ? 'ממתינים לשחקן/ית נוסף/ת...' : 'התחל משחק! 🚀'),
                ).animate().fadeIn(delay: 200.ms)
              else
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'ממתינים שמנהל/ת החדר ילחץ/תלחץ על "התחל משחק"...',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white),
                ),
                onPressed: _isLeaving ? null : _leave,
                child: const Text('יציאה מהחדר'),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoomCodeCard extends StatelessWidget {
  final String roomCode;
  final VoidCallback onCopy;

  const _RoomCodeCard({required this.roomCode, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Text('קוד החדר - שלחו לחברים', style: TextStyle(color: Colors.black54, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  roomCode,
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 8,
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_rounded, color: AppColors.primary),
                  tooltip: 'העתקה',
                ),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }
}

class _SettingsSummary extends StatelessWidget {
  final GameRoom room;

  const _SettingsSummary({required this.room});

  String get _joinWindowLabel {
    final deadline = room.joinDeadline;
    if (deadline == null) return '';
    final remaining = deadline.difference(DateTime.now());
    if (remaining.isNegative) return 'ההצטרפות נסגרה';
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;
    return 'ניתן להצטרף עוד $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final chips = <String>[
      '${room.gridSize}×${room.gridSize}',
      '${room.roundSeconds} שנ׳ לסבב',
      room.hasTargetScore ? 'יעד: ${room.targetScore} נק׳' : 'ללא יעד ניקוד',
      'עד ${room.maxPlayers} שחקנים',
    ];
    if (room.status == RoomStatus.waiting) chips.add(_joinWindowLabel);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: chips
          .where((c) => c.isNotEmpty)
          .map(
            (c) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(c, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ),
          )
          .toList(),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerInRoom player;
  final bool isMe;

  const _PlayerRow({required this.player, required this.isMe});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          MascotWidget(mood: player.isHost ? MascotMood.excited : MascotMood.idle, size: 30),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isMe ? '${player.displayName} (את/ה)' : player.displayName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (player.isHost)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('מנהל/ת', style: TextStyle(color: Colors.white, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}
