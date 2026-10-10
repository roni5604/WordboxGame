import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/social/models/social_models.dart';
import '../features/social/services/firestore_social_repository.dart';
import '../features/social/services/social_repository.dart';
import '../data/services/firebase_bootstrap.dart';

bool _firebaseReady() => isFirebaseBackendReady();

/// ה-repository החברתי הפעיל - Firestore אמיתי כש-Firebase אותחל בהצלחה,
/// אחרת מימוש אופליין (בלי קריסות, עם הודעה ידידותית).
final socialRepositoryProvider = Provider<SocialRepository>((ref) {
  if (_firebaseReady()) return FirestoreSocialRepository();
  return OfflineSocialRepository();
});

/// רשימת החברים שלי בזמן אמת (כולל נוכחות ומאזן ראש בראש).
final friendsProvider = StreamProvider<List<FriendEntry>>((ref) {
  return ref.watch(socialRepositoryProvider).watchFriends();
});

final incomingFriendRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  return ref.watch(socialRepositoryProvider).watchIncomingRequests();
});

final outgoingFriendRequestsProvider = StreamProvider<List<FriendRequest>>((ref) {
  return ref.watch(socialRepositoryProvider).watchOutgoingRequests();
});

final incomingInvitesProvider = StreamProvider<List<GameInvite>>((ref) {
  return ref.watch(socialRepositoryProvider).watchIncomingInvites();
});

/// כמה חברים מחוברים עכשיו (לתג במסך הבית).
final onlineFriendsCountProvider = Provider<int>((ref) {
  final friends = ref.watch(friendsProvider).valueOrNull ?? const [];
  final now = DateTime.now();
  return friends.where((f) => f.profile.isOnline(now)).length;
});

/// ה-uid שלי בשכבה החברתית (null עד ההתחברות / במצב אופליין).
final socialUidProvider = FutureProvider<String?>((ref) async {
  final repo = ref.watch(socialRepositoryProvider);
  if (!repo.isAvailable) return null;
  try {
    return await repo.ensureSignedIn();
  } catch (_) {
    return null;
  }
});

/// שחקנים ששיחקנו איתם לאחרונה בחדרים פרטיים - נשמר מקומית, ומוצע
/// בהוספת חברים ("שיחקתם יחד לאחרונה").
class RecentPlayersNotifier extends StateNotifier<List<RecentPlayer>> {
  static const _key = 'recent_players_v1';
  static const _max = 20;

  RecentPlayersNotifier() : super(const []) {
    _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final list = (jsonDecode(raw) as List)
          .whereType<Map<String, dynamic>>()
          .map(RecentPlayer.fromJson)
          .whereType<RecentPlayer>()
          .toList();
      if (mounted) state = list;
    } catch (_) {
      // קובץ פגום - מתחילים מחדש.
    }
  }

  Future<void> remember(List<RecentPlayer> players) async {
    if (players.isEmpty) return;
    final byUid = {for (final p in state) p.uid: p};
    for (final p in players) {
      byUid[p.uid] = p;
    }
    final next = byUid.values.toList()..sort((a, b) => b.playedAt.compareTo(a.playedAt));
    state = next.take(_max).toList();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, jsonEncode([for (final p in state) p.toJson()]));
    } catch (_) {}
  }
}

final recentPlayersProvider = StateNotifierProvider<RecentPlayersNotifier, List<RecentPlayer>>(
  (ref) => RecentPlayersNotifier(),
);
