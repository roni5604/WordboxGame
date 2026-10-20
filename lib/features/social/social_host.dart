import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/notifications/notification_service.dart';
import '../../core/ui/game_dialog.dart';
import '../../providers/auth_provider.dart';
import '../../providers/player_profile_provider.dart';
import '../../providers/social_provider.dart';
import 'models/social_models.dart';
import 'services/social_repository.dart';
import 'widgets/invite_dialog.dart';

/// מסכים שבהם לא קופצים חלונות ולא מפריעים - באמצע שלב או תחרות.
bool isGameplayLocation(String location) {
  final path = Uri.tryParse(location)?.path ?? location;
  if (path.startsWith('/level/') && path.endsWith('/play')) return true;
  if (path == '/multiplayer/race') return true;
  if (path.startsWith('/multiplayer/online/race/')) return true;
  if (path == '/daily/play') return true;
  return false;
}

/// "המנוע החברתי" שרץ ברקע לאורך כל חיי האפליקציה:
///
/// * מפרסם את הכרטיס הציבורי שלי (שם, אוואטאר, כוכבים) כשהם משתנים.
/// * שולח פעימת נוכחות כל דקה (מחובר/ת / באמצע משחק), ומסמן "לא מחובר/ת"
///   כשהאפליקציה יורדת לרקע.
/// * מציג חלון קופץ כשחבר/ה מזמין/ה אותי למשחק - אבל לא באמצע שלב: ההזמנה
///   ממתינה ומוצגת ברגע שיוצאים מהמשחק (אם עדיין בתוקף).
/// * מודיע בעדינות על בקשת חברות חדשה.
class SocialHost extends ConsumerStatefulWidget {
  final Widget child;
  final GoRouter router;
  final GlobalKey<NavigatorState> navigatorKey;

  const SocialHost({super.key, required this.child, required this.router, required this.navigatorKey});

  @override
  ConsumerState<SocialHost> createState() => _SocialHostState();
}

class _SocialHostState extends ConsumerState<SocialHost> with WidgetsBindingObserver {
  static const _heartbeatInterval = Duration(seconds: 60);

  late final SocialRepository _repo;
  Timer? _heartbeat;
  Timer? _publishDebounce;
  bool _foreground = true;
  PresenceStatus? _lastStatus;
  String _location = '/';

  final Set<String> _seenInvites = {};
  final List<GameInvite> _pendingInvites = [];
  bool _showingInvite = false;
  Set<String> _knownRequestIds = {};
  bool _requestsPrimed = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(socialRepositoryProvider);
    if (!_repo.isAvailable) return;
    WidgetsBinding.instance.addObserver(this);
    widget.router.routerDelegate.addListener(_onRouteChanged);
    _onRouteChanged();
    _heartbeat = Timer.periodic(_heartbeatInterval, (_) => _beat(force: true));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _schedulePublish();
      _beat(force: true);
    });
  }

  @override
  void dispose() {
    if (_repo.isAvailable) {
      WidgetsBinding.instance.removeObserver(this);
      widget.router.routerDelegate.removeListener(_onRouteChanged);
    }
    _heartbeat?.cancel();
    _publishDebounce?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    if (foreground) {
      _beat(force: true);
    } else {
      _repo.goOffline().catchError((_) {});
      _lastStatus = PresenceStatus.offline;
    }
  }

  void _onRouteChanged() {
    final config = widget.router.routerDelegate.currentConfiguration;
    _location = config.isEmpty ? '/' : config.uri.toString();
    _beat();
    if (!isGameplayLocation(_location)) _drainInvites();
  }

  PresenceStatus get _currentStatus =>
      isGameplayLocation(_location) ? PresenceStatus.playing : PresenceStatus.online;

  void _beat({bool force = false}) {
    if (!_foreground) return;
    final status = _currentStatus;
    if (!force && status == _lastStatus) return;
    _lastStatus = status;
    _repo.heartbeat(status).catchError((_) {});
  }

  void _schedulePublish() {
    _publishDebounce?.cancel();
    _publishDebounce = Timer(const Duration(milliseconds: 1200), () {
      final profile = ref.read(playerProfileProvider).valueOrNull;
      if (profile == null) return;
      final auth = ref.read(authStateProvider).valueOrNull;
      _repo
          .publishMyProfile(MyPublicInfo(
            displayName: profile.displayName,
            avatarId: profile.avatarId,
            photoUrl: auth?.photoUrl,
            totalStars: profile.totalStars,
            highestLevel: profile.highestUnlockedLevel,
            dailyDate: profile.dailyChallengeDate,
            dailyScore: profile.dailyChallengeScore,
            dailyStreak: profile.dailyChallengeStreak,
          ))
          .catchError((_) {});
    });
  }

  /// האפליקציה (או לשונית האתר) לא מול העיניים - אז חלון בתוך המשחק לא
  /// יראה אף אחד, ושולחים התראה של המערכת במקום.
  bool get _inBackground => !_foreground || NotificationService.instance.webTabHidden;

  void _onInvites(List<GameInvite> invites) {
    for (final invite in invites) {
      if (_seenInvites.add(invite.id)) {
        _pendingInvites.add(invite);
        if (_inBackground && invite.isActive()) {
          NotificationService.instance.showSocial(
            id: 2000 + invite.id.hashCode % 1000,
            title: '🎮 ${invite.fromName} מזמין/ה אתכם למשחק',
            body: 'לוח ${invite.gridSize}×${invite.gridSize} · ההזמנה בתוקף לדקה. היכנסו עכשיו!',
            route: '/home',
          );
        }
      }
    }
    _drainInvites();
  }

  Future<void> _drainInvites() async {
    if (_showingInvite || isGameplayLocation(_location)) return;
    _pendingInvites.removeWhere((i) => !i.isActive());
    if (_pendingInvites.isEmpty) return;
    final dialogContext = widget.navigatorKey.currentContext;
    if (dialogContext == null) return;

    final invite = _pendingInvites.removeAt(0);
    _showingInvite = true;
    try {
      final accepted = await showInviteDialog(dialogContext, invite);
      await _repo.respondToInvite(invite, accept: accepted).catchError((_) {});
      if (accepted && mounted) {
        widget.router.push(
          '/multiplayer/online/join?code=${Uri.encodeComponent(invite.roomCode)}',
          extra: {'autoJoin': true, 'expectedFee': invite.entryFee},
        );
      }
    } finally {
      _showingInvite = false;
    }
    if (mounted) unawaited(_drainInvites());
  }

  void _onRequests(List<FriendRequest> requests) {
    final ids = requests.map((r) => r.id).toSet();
    if (_requestsPrimed && _inBackground) {
      final fresh = requests.where((r) => !_knownRequestIds.contains(r.id)).toList();
      if (fresh.isNotEmpty) {
        NotificationService.instance.showSocial(
          id: 3000,
          title: '💌 בקשת חברות חדשה',
          body: fresh.length == 1 ? '${fresh.first.fromName} רוצה להיות חבר/ה שלכם' : 'יש ${fresh.length} בקשות חברות חדשות',
          route: '/friends?tab=1',
        );
      }
    } else if (_requestsPrimed && !isGameplayLocation(_location)) {
      final fresh = requests.where((r) => !_knownRequestIds.contains(r.id)).toList();
      final context = widget.navigatorKey.currentContext;
      if (fresh.isNotEmpty && context != null) {
        GameToast.show(
          context,
          message: fresh.length == 1
              ? '${fresh.first.fromName} שלח/ה לך בקשת חברות 💌'
              : 'יש לך ${fresh.length} בקשות חברות חדשות 💌',
          icon: Icons.person_add_alt_1_rounded,
          color: const Color(0xFF7B3FF2),
          duration: const Duration(seconds: 4),
          actionLabel: 'לצפייה',
          onTap: () => widget.router.push('/friends?tab=1'),
        );
      }
    }
    _requestsPrimed = true;
    _knownRequestIds = ids;
  }

  @override
  Widget build(BuildContext context) {
    if (_repo.isAvailable) {
      ref.listen(playerProfileProvider, (_, _) => _schedulePublish());
      ref.listen(authStateProvider, (_, _) => _schedulePublish());
      ref.listen<AsyncValue<List<GameInvite>>>(incomingInvitesProvider, (_, next) {
        final invites = next.valueOrNull;
        if (invites != null) _onInvites(invites);
      });
      ref.listen<AsyncValue<List<FriendRequest>>>(incomingFriendRequestsProvider, (_, next) {
        final requests = next.valueOrNull;
        if (requests != null) _onRequests(requests);
      });
    }
    return widget.child;
  }
}
