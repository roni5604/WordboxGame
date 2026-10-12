import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/share/share_service.dart';
import '../../core/ui/candy_button.dart';
import '../../core/ui/game_backdrop.dart';
import '../../core/ui/game_dialog.dart';
import '../../core/ui/pressable.dart';
import '../../providers/social_provider.dart';
import '../profile/widgets/avatar_widget.dart';
import '../social/friends_screen.dart';
import '../social/models/social_models.dart';
import '../social/social_actions.dart';
import '../social/widgets/presence_avatar.dart';
import '../../providers/multiplayer_repository_provider.dart';
import '../../providers/player_profile_provider.dart';
import 'models/room_models.dart';
import 'services/multiplayer_repository.dart';

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
  GameRoom? _latestRoom;
  final Map<String, InviteStatus> _inviteStatuses = {};
  String? _rememberedKey;

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
    final room = _latestRoom;
    final shouldRefund = room != null &&
        room.status == RoomStatus.waiting &&
        room.entryFee > 0 &&
        (_myUid == null || room.paidUids[_myUid] == true);
    try {
      await _repo.leaveRoom(widget.roomCode);
      if (shouldRefund) {
        await ref.read(playerProfileProvider.notifier).addCoins(room.entryFee);
        AnalyticsService.instance.earnVirtualCurrency(
          currency: 'coins',
          value: room.entryFee,
          source: 'other',
          item: 'room_fee_refund',
        );
      }
    } catch (_) {
      // עזיבה טובה-מאמץ - לא חוסמים את היציאה מהמסך גם אם נכשלה.
    }
    if (mounted) context.go('/play/friends');
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
    AnalyticsService.instance.share(method: 'copy_code', contentType: 'room_invite');
    Clipboard.setData(ClipboardData(text: widget.roomCode));
    GameToast.show(context, message: 'הקוד הועתק! שלחו אותו לחברים 📋', icon: Icons.copy_rounded);
  }

  String get _inviteText {
    final room = _latestRoom;
    final details = room == null ? '' : ' (לוח ${room.gridSize}×${room.gridSize}, ${room.roundSeconds} שניות)';
    return 'בואו לשחק איתי "מצא ת׳מילה"! 🔤⚔️$details\n'
        'קוד החדר: ${widget.roomCode}\n'
        'כניסה ישירה: ${AppLinks.joinRoom(widget.roomCode)}';
  }

  Future<void> _copyLink() async {
    AnalyticsService.instance.share(method: 'copy_link', contentType: 'room_invite');
    await Clipboard.setData(ClipboardData(text: AppLinks.joinRoom(widget.roomCode)));
    if (mounted) GameToast.show(context, message: 'הקישור לחדר הועתק 🔗', icon: Icons.link_rounded);
  }

  Future<void> _confirmLeave() async {
    if (_isLeaving) return;
    final room = _latestRoom;
    final isHost = room != null && _myUid == room.hostUid;
    final ok = await showConfirmDialog(
      context,
      title: 'יציאה מהחדר',
      message: isHost
          ? 'את/ה מנהל/ת החדר - אם תצא/י, המשחק לא יוכל להתחיל. דמי הכניסה יוחזרו.'
          : 'לצאת מהחדר? דמי הכניסה יוחזרו.',
      confirmLabel: 'יציאה',
      confirmPalette: CandyPalette.red,
    );
    if (ok) await _leave();
  }

  void _onSentInvites(List<GameInvite> invites) {
    for (final invite in invites) {
      final previous = _inviteStatuses[invite.id];
      _inviteStatuses[invite.id] = invite.status;
      if (previous == null || previous == invite.status || !mounted) continue;
      if (invite.status == InviteStatus.accepted) {
        GameToast.show(context, message: '${invite.toName.isEmpty ? 'החבר/ה' : invite.toName} בדרך לחדר! 🎉', icon: Icons.directions_run_rounded);
      } else if (invite.status == InviteStatus.declined) {
        GameToast.show(
          context,
          message: '${invite.toName.isEmpty ? 'החבר/ה' : invite.toName} לא יכול/ה כרגע',
          icon: Icons.schedule_rounded,
          color: const Color(0xFFFF9800),
        );
      }
    }
  }

  void _rememberPlayers(GameRoom room) {
    final key = room.players.map((p) => p.uid).join(',');
    if (key == _rememberedKey || _myUid == null) return;
    _rememberedKey = key;
    final now = DateTime.now();
    final players = [
      for (final p in room.players)
        if (p.uid != _myUid)
          RecentPlayer(uid: p.uid, displayName: p.displayName, avatarId: p.avatarId ?? 'detective', playedAt: now),
    ];
    // לא משנים state של provider באמצע build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(recentPlayersProvider.notifier).remember(players);
    });
  }

  Future<void> _openInviteSheet(GameRoom room) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => _InviteFriendsSheet(room: room),
    );
  }

  @override
  Widget build(BuildContext context) {
    final social = ref.watch(socialRepositoryProvider);
    if (social.isAvailable) {
      ref.listen<AsyncValue<List<GameInvite>>>(_sentInvitesProvider(widget.roomCode), (_, next) {
        final list = next.valueOrNull;
        if (list != null) _onSentInvites(list);
      });
    }
    final sentInvites = social.isAvailable
        ? ref.watch(_sentInvitesProvider(widget.roomCode)).valueOrNull ?? const <GameInvite>[]
        : const <GameInvite>[];
    final friendIds = (ref.watch(friendsProvider).valueOrNull ?? const []).map((f) => f.uid).toSet();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: StreamBuilder<GameRoom>(
        stream: _roomStream,
        builder: (context, snapshot) {
          final room = snapshot.data;
          final isHost = room != null && _myUid != null && _myUid == room.hostUid;
          final hostStillPresent = room?.players.any((p) => p.isHost) ?? true;
          final canStart = room != null && room.players.length >= 2 && !_isStarting;

          if (room != null) {
            _latestRoom = room;
            _rememberPlayers(room);
            if (room.status == RoomStatus.inProgress && !_navigatedToRace) {
              _navigatedToRace = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) context.pushReplacement('/multiplayer/online/race/${room.roomCode}');
              });
            }
          }

          Widget body;
          if (snapshot.hasError) {
            body = Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'החדר לא נמצא, או שהתרחשה שגיאה.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            );
          } else if (room == null) {
            body = const Center(child: CircularProgressIndicator(color: Colors.white));
          } else {
            body = ListView(
              padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
              children: [
                _RoomCodeCard(
                  roomCode: room.roomCode,
                  onCopy: _copyCode,
                  onCopyLink: _copyLink,
                  onMore: () {
                    AnalyticsService.instance.share(method: 'system', contentType: 'room_invite');
                    ShareService.system(context, text: _inviteText);
                  },
                ),
                if (social.isAvailable) ...[
                  const SizedBox(height: 12),
                  CandyButton(
                    label: 'הזמנת חברים מהרשימה',
                    icon: Icons.person_add_alt_1_rounded,
                    palette: CandyPalette.pink,
                    height: 54,
                    fontSize: 17,
                    onPressed: () => _openInviteSheet(room),
                  ),
                ],
                if (sentInvites.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _SentInvitesRow(invites: sentInvites),
                ],
                const SizedBox(height: 12),
                if (!hostStillPresent)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.error.withValues(alpha: 0.92),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Text(
                      'מנהל/ת החדר עזב/ה לפני שהמשחק התחיל. אפשר לחזור ולהצטרף\n'
                      'לחדר אחר, או ליצור חדר חדש.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ).animate().fadeIn(),
                _SettingsSummary(room: room),
                if (room.wins.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _WinsSummary(room: room, myUid: _myUid),
                ],
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 5))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'שחקנים בחדר (${room.players.length})',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: Color(0xFF4A2F8F)),
                      ),
                      const SizedBox(height: 8),
                      for (final player in room.players)
                        _PlayerRow(
                          player: player,
                          isMe: player.uid == _myUid,
                          isFriend: friendIds.contains(player.uid),
                          canAddFriend: social.isAvailable && player.uid != _myUid && !friendIds.contains(player.uid),
                          onAddFriend: () => SocialActions.sendFriendRequest(
                            context,
                            ref,
                            uid: player.uid,
                            name: player.displayName,
                          ),
                        ).animate().fadeIn(duration: 250.ms).slideX(begin: 0.08, end: 0),
                      if (room.players.length < 2)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2.4, color: Color(0xFF7B3FF2)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'ממתינים לחברים... שלחו להם את הקישור',
                                  style: TextStyle(color: Colors.black.withValues(alpha: 0.55), fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }

          return GameScaffold(
            colors: kFriendsGradient,
            header: GameHeader(
              title: 'חדר המתנה',
              subtitle: room == null ? null : (room.isSeries ? room.roundLabel : null),
              onBack: _isLeaving ? null : _confirmLeave,
            ),
            body: body,
            bottomBar: room == null
                ? null
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_actionError != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            _actionError!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ),
                      if (isHost)
                        CandyButton(
                          label: room.players.length < 2 ? 'ממתינים לשחקן/ית נוסף/ת...' : 'התחל משחק! 🚀',
                          palette: CandyPalette.green,
                          height: 62,
                          loading: _isStarting,
                          onPressed: (canStart && hostStillPresent) ? _startGame : null,
                        )
                      else
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Text(
                            'ממתינים שמנהל/ת החדר ילחץ/תלחץ על "התחל משחק"...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

/// הזמנות ששלחתי לחדר הזה - חיווי חי למצב כל אחת.
final _sentInvitesProvider = StreamProvider.autoDispose.family<List<GameInvite>, String>((ref, roomCode) {
  return ref.watch(socialRepositoryProvider).watchSentInvites(roomCode);
});

class _RoomCodeCard extends StatelessWidget {
  final String roomCode;
  final VoidCallback onCopy;
  final VoidCallback onCopyLink;
  final VoidCallback onMore;

  const _RoomCodeCard({
    required this.roomCode,
    required this.onCopy,
    required this.onCopyLink,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        children: [
          const Text(
            'קוד החדר - שלחו לחברים',
            style: TextStyle(color: Color(0xFF7B6CA8), fontSize: 13, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Pressable(
            onTap: onCopy,
            semanticLabel: 'העתקת הקוד',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    roomCode,
                    style: const TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 8,
                      color: Color(0xFF5B2EC9),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.copy_rounded, color: Color(0xFF9D8FC4)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: CandyButton(
                  label: 'שיתוף ההזמנה',
                  subtitle: 'וואטסאפ, הודעה או כל אפליקציה',
                  icon: Icons.ios_share_rounded,
                  palette: CandyPalette.green,
                  height: 62,
                  fontSize: 19,
                  onPressed: onMore,
                ),
              ),
              const SizedBox(width: 10),
              _LabeledIconAction(icon: Icons.link_rounded, label: 'העתקת קישור', onTap: onCopyLink),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
  }
}

/// כפתור עגול קטן עם תווית מתחתיו (למשל "העתקת קישור").
class _LabeledIconAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _LabeledIconAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: SizedBox(
        width: 74,
        child: Column(
          children: [
            IgnorePointer(child: CandyIconButton(icon: icon, size: 48, onPressed: () {})),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5, color: Color(0xFF6B5E8F)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SentInvitesRow extends StatelessWidget {
  final List<GameInvite> invites;
  const _SentInvitesRow({required this.invites});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final i in invites)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: switch (i.status) {
                InviteStatus.accepted => const Color(0xFF33C24D),
                InviteStatus.declined => const Color(0xFFFF7043),
                _ => i.isActive() ? Colors.white.withValues(alpha: 0.25) : Colors.black.withValues(alpha: 0.18),
              },
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              switch (i.status) {
                InviteStatus.accepted => '✓ ${i.toName} מצטרף/ת',
                InviteStatus.declined => '✗ ${i.toName} לא יכול/ה',
                _ => i.isActive() ? '⏳ ${i.toName} הוזמן/ה' : '⌛ ${i.toName} לא ענה/תה',
              },
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13),
            ),
          ),
      ],
    );
  }
}

/// גיליון "הזמנת חברים": רשימת החברים (מחוברים קודם) עם כפתור הזמנה לכל אחד.
class _InviteFriendsSheet extends ConsumerStatefulWidget {
  final GameRoom room;
  const _InviteFriendsSheet({required this.room});

  @override
  ConsumerState<_InviteFriendsSheet> createState() => _InviteFriendsSheetState();
}

class _InviteFriendsSheetState extends ConsumerState<_InviteFriendsSheet> {
  final Set<String> _sending = {};
  final Set<String> _sent = {};

  Future<void> _invite(FriendEntry friend) async {
    setState(() => _sending.add(friend.uid));
    try {
      await ref.read(socialRepositoryProvider).sendInvite(
            toUid: friend.uid,
            toName: friend.profile.displayName,
            roomCode: widget.room.roomCode,
            gridSize: widget.room.gridSize,
            roundSeconds: widget.room.roundSeconds,
            entryFee: widget.room.entryFee,
          );
      if (mounted) setState(() => _sent.add(friend.uid));
    } catch (e) {
      if (mounted) GameToast.show(context, message: SocialActions.friendlyError(e), color: AppColors.error);
    } finally {
      if (mounted) setState(() => _sending.remove(friend.uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendsProvider).valueOrNull ?? const <FriendEntry>[];
    final inRoom = widget.room.players.map((p) => p.uid).toSet();
    final now = DateTime.now();
    final sorted = friends.where((f) => !inRoom.contains(f.uid)).toList()
      ..sort((a, b) => a.profile.effectiveStatus(now).index.compareTo(b.profile.effectiveStatus(now).index));

    return Padding(
      padding: EdgeInsets.fromLTRB(18, 0, 18, context.safeBottom()),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'הזמנת חברים לחדר',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppColors.textDark),
          ),
          const SizedBox(height: 4),
          const Text(
            'חברים מחוברים יקבלו חלון קופץ להצטרפות מיידית',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF7B6CA8)),
          ),
          const SizedBox(height: 12),
          if (sorted.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'אין עדיין חברים להזמנה.\nאפשר לשלוח הזמנה בכפתור "שיתוף ההזמנה".',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF6B5E8F)),
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: sorted.length,
                separatorBuilder: (_, __) => const Divider(height: 14),
                itemBuilder: (context, i) {
                  final f = sorted[i];
                  final online = f.profile.isOnline(now);
                  final sent = _sent.contains(f.uid);
                  return Row(
                    children: [
                      PresenceAvatar.of(f.profile, size: 46),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(f.profile.displayName, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                            Text(
                              f.profile.presenceLabel(now),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: online ? const Color(0xFF1FAE48) : const Color(0xFF9A93AE),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 104,
                        child: CandyButton(
                          label: sent ? 'נשלחה ✓' : 'הזמנה',
                          palette: sent ? CandyPalette.white : (online ? CandyPalette.green : CandyPalette.blue),
                          height: 42,
                          fontSize: 14,
                          radius: 16,
                          loading: _sending.contains(f.uid),
                          onPressed: sent ? null : () => _invite(f),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
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
      room.totalRounds == 1 ? 'משחקון אחד' : '${room.totalRounds} משחקונים',
      'דמי כניסה: ${room.entryFee}',
      'קופה: ${room.pot}',
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

/// תזכורת קטנה ליחס הניצחונות המצטבר בחדר, מוצגת בלובי בין סבבי "משחק
/// חוזר" (ראו online_race_result_screen.dart לתצוגה המלאה בסוף כל סבב).
class _WinsSummary extends StatelessWidget {
  final GameRoom room;
  final String? myUid;

  const _WinsSummary({required this.room, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final labels = [
      for (final player in room.players)
        '${player.uid == myUid ? '${player.displayName} (את/ה)' : player.displayName}: ${room.wins[player.uid] ?? 0}',
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white24,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        'ניצחונות עד כה - ${labels.join(' | ')}',
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
      ),
    );
  }
}

class _PlayerRow extends StatelessWidget {
  final PlayerInRoom player;
  final bool isMe;
  final bool isFriend;
  final bool canAddFriend;
  final VoidCallback onAddFriend;

  const _PlayerRow({
    required this.player,
    required this.isMe,
    this.isFriend = false,
    this.canAddFriend = false,
    required this.onAddFriend,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AvatarWidget(
                avatarId: player.avatarId ?? 'detective',
                photoUrl: player.photoUrl,
                size: 42,
                ring: false,
              ),
              if (player.isHost)
                const Positioned(
                  top: -10,
                  right: -4,
                  child: Text('👑', style: TextStyle(fontSize: 18)),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isMe ? '${player.displayName} (את/ה)' : player.displayName,
                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppColors.textDark),
                ),
                if (player.isHost || isFriend)
                  Text(
                    [if (player.isHost) 'מנהל/ת החדר', if (isFriend) 'חבר/ה'].join(' · '),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF7B6CA8)),
                  ),
              ],
            ),
          ),
          if (canAddFriend)
            CandyIconButton(
              icon: Icons.person_add_alt_1_rounded,
              palette: CandyPalette.purple,
              size: 38,
              tooltip: 'הוספה לחברים',
              onPressed: onAddFriend,
            ),
        ],
      ),
    );
  }
}
