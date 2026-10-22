import 'dart:async';

import 'package:wordbox_hebrew/features/social/models/social_models.dart';
import 'package:wordbox_hebrew/features/social/services/social_repository.dart';

/// מימוש מזויף ל-[SocialRepository] לבדיקות UI ולצילומי מסך.
class FakeSocialRepository implements SocialRepository {
  String myUid;
  List<FriendEntry> friends;
  List<FriendRequest> incoming;
  List<FriendRequest> outgoing;
  List<GameInvite> invites;
  final List<String> sentRequests = [];
  final List<GameInvite> sentInvites = [];
  final List<({GameInvite invite, bool accept})> responses = [];
  final List<({String uid, ReportReason reason})> reports = [];
  final Map<String, String> blocked = {};

  FakeSocialRepository({
    this.myUid = 'me',
    this.friends = const [],
    this.incoming = const [],
    this.outgoing = const [],
    this.invites = const [],
  });

  final _invitesController = StreamController<List<GameInvite>>.broadcast();

  void pushInvites(List<GameInvite> list) {
    invites = list;
    _invitesController.add(list);
  }

  @override
  bool get isAvailable => true;

  @override
  Future<String> ensureSignedIn() async => myUid;

  @override
  Future<String> myFriendCode() async => SocialRepository.friendCodeFor(myUid);

  @override
  Future<void> publishMyProfile(MyPublicInfo info) async {}

  @override
  Future<void> heartbeat(PresenceStatus status) async {}

  @override
  Future<void> goOffline() async {}

  @override
  Stream<List<FriendEntry>> watchFriends() => Stream.value(friends);

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() => Stream.value(incoming);

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() => Stream.value(outgoing);

  @override
  Future<PublicProfile?> findByFriendCode(String code) async {
    for (final f in friends) {
      if (f.profile.friendCode == SocialRepository.normalizeFriendCode(code)) return f.profile;
    }
    return null;
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> uids) async =>
      [for (final f in friends) if (uids.contains(f.uid)) f.profile];

  @override
  Future<bool> sendFriendRequest(String toUid, {String toName = ''}) async {
    sentRequests.add(toUid);
    return false;
  }

  @override
  Future<void> acceptFriendRequest(FriendRequest request) async {}

  @override
  Future<void> declineFriendRequest(FriendRequest request) async {}

  @override
  Future<void> cancelFriendRequest(String toUid) async {}

  @override
  Future<void> removeFriend(String friendUid) async {}

  @override
  Future<GameInvite> sendInvite({
    required String toUid,
    String toName = '',
    required String roomCode,
    required int gridSize,
    required int roundSeconds,
    required int entryFee,
  }) async {
    final invite = GameInvite(
      id: 'inv-${sentInvites.length}',
      fromUid: myUid,
      fromName: 'אני',
      toUid: toUid,
      toName: toName,
      roomCode: roomCode,
      gridSize: gridSize,
      roundSeconds: roundSeconds,
      entryFee: entryFee,
      createdAt: DateTime.now(),
    );
    sentInvites.add(invite);
    return invite;
  }

  @override
  Stream<List<GameInvite>> watchIncomingInvites() async* {
    yield invites;
    yield* _invitesController.stream;
  }

  @override
  Stream<List<GameInvite>> watchSentInvites(String roomCode) =>
      Stream.value([for (final i in sentInvites) if (i.roomCode == roomCode) i]);

  @override
  Future<void> respondToInvite(GameInvite invite, {required bool accept}) async {
    responses.add((invite: invite, accept: accept));
  }

  final List<Map<String, int>> recordedMatches = [];

  @override
  Future<void> recordMatch({required Map<String, int> scores, required String myUid}) async {
    recordedMatches.add(scores);
  }

  @override
  Future<void> reportUser({
    required String uid,
    required String name,
    required ReportReason reason,
    String context = '',
  }) async =>
      reports.add((uid: uid, reason: reason));

  @override
  Future<void> blockUser(String uid, {String name = ''}) async {
    blocked[uid] = name;
    friends = [for (final f in friends) if (f.uid != uid) f];
    incoming = [for (final r in incoming) if (r.fromUid != uid) r];
  }

  @override
  Future<void> unblockUser(String uid) async => blocked.remove(uid);

  @override
  Stream<List<BlockedUser>> watchBlockedUsers() =>
      Stream.value([for (final e in blocked.entries) BlockedUser(uid: e.key, name: e.value)]);
}
