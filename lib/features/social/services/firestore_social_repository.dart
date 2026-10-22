import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../data/services/auth_session.dart';
import '../../../core/security/input_rules.dart';
import '../models/social_models.dart';
import 'social_repository.dart';

/// מימוש Firestore לשכבה החברתית.
///
/// מבנה המסמכים:
///   publicProfiles/{uid}                  - הכרטיס הציבורי + נוכחות
///   publicProfiles/{uid}/friends/{uid2}   - הרשומה שלי על חבר/ה (מאזן ראש בראש)
///   friendRequests/{from}_{to}            - בקשת חברות ממתינה
///   invites/{autoId}                      - הזמנה למשחק בחדר פרטי
///   blocks/{uid}/users/{blockedUid}       - משתמשים שחסמתי (רק אני קורא/ת)
///   reports/{autoId}                      - דיווחים על משתמשים (כתיבה בלבד)
///
/// חוקי האבטחה המתאימים נמצאים ב-firestore.rules.
class FirestoreSocialRepository implements SocialRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreSocialRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _profiles => _firestore.collection('publicProfiles');
  CollectionReference<Map<String, dynamic>> get _requests => _firestore.collection('friendRequests');
  CollectionReference<Map<String, dynamic>> get _invites => _firestore.collection('invites');
  CollectionReference<Map<String, dynamic>> get _reports => _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> _blocksOf(String uid) =>
      _firestore.collection('blocks').doc(uid).collection('users');

  CollectionReference<Map<String, dynamic>> _friendsOf(String uid) =>
      _profiles.doc(uid).collection('friends');

  MyPublicInfo? _lastPublished;

  @override
  bool get isAvailable => true;

  @override
  Future<String> ensureSignedIn() async {
    return AuthSession.ensureUid(_auth);
  }

  @override
  Future<String> myFriendCode() async => SocialRepository.friendCodeFor(await ensureSignedIn());

  // ---------------------------------------------------------------------------
  // כרטיס ציבורי ונוכחות
  // ---------------------------------------------------------------------------

  @override
  Future<void> publishMyProfile(MyPublicInfo info) async {
    if (_lastPublished == info) return;
    final uid = await ensureSignedIn();
    final name = InputRules.sanitizeDisplayName(info.displayName);
    await _profiles.doc(uid).set({
      'displayName': name,
      'displayNameLower': name.toLowerCase(),
      'avatarId': info.avatarId,
      'photoUrl': InputRules.isTrustedPhotoUrl(info.photoUrl) ? info.photoUrl : null,
      'friendCode': SocialRepository.friendCodeFor(uid),
      'totalStars': info.totalStars,
      'highestLevel': info.highestLevel,
      if (info.dailyDate != null) ...{
        'dailyDate': info.dailyDate,
        'dailyScore': info.dailyScore,
        'dailyStreak': info.dailyStreak,
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _lastPublished = info;
  }

  @override
  Future<void> heartbeat(PresenceStatus status) async {
    final uid = await ensureSignedIn();
    await _profiles.doc(uid).set({
      'status': status.name,
      'lastActive': FieldValue.serverTimestamp(),
      'friendCode': SocialRepository.friendCodeFor(uid),
    }, SetOptions(merge: true));
  }

  @override
  Future<void> goOffline() async {
    final current = _auth.currentUser;
    if (current == null) return;
    await _profiles.doc(current.uid).set({
      'status': PresenceStatus.offline.name,
      'lastActive': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static PublicProfile mapProfile(String uid, Map<String, dynamic> data) {
    return PublicProfile(
      uid: uid,
      displayName: (data['displayName'] as String?)?.trim().isNotEmpty == true
          ? data['displayName'] as String
          : 'שחקן/ית',
      avatarId: data['avatarId'] as String? ?? 'detective',
      photoUrl: data['photoUrl'] as String?,
      friendCode: data['friendCode'] as String? ?? SocialRepository.friendCodeFor(uid),
      totalStars: (data['totalStars'] as num?)?.toInt() ?? 0,
      highestLevel: (data['highestLevel'] as num?)?.toInt() ?? 1,
      mpGames: (data['mpGames'] as num?)?.toInt() ?? 0,
      mpWins: (data['mpWins'] as num?)?.toInt() ?? 0,
      dailyDate: data['dailyDate'] as String?,
      dailyScore: (data['dailyScore'] as num?)?.toInt() ?? 0,
      dailyStreak: (data['dailyStreak'] as num?)?.toInt() ?? 0,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      status: PresenceStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => PresenceStatus.offline,
      ),
    );
  }

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> uids) async {
    final unique = uids.toSet().where((u) => u.isNotEmpty).toList();
    final results = <PublicProfile>[];
    for (int i = 0; i < unique.length; i += 30) {
      final chunk = unique.sublist(i, i + 30 > unique.length ? unique.length : i + 30);
      final snap = await _profiles.where(FieldPath.documentId, whereIn: chunk).limit(chunk.length).get();
      for (final doc in snap.docs) {
        results.add(mapProfile(doc.id, doc.data()));
      }
    }
    return results;
  }

  @override
  Future<PublicProfile?> findByFriendCode(String code) async {
    final normalized = SocialRepository.normalizeFriendCode(code);
    if (normalized.length != 6) {
      throw const SocialException('קוד חבר מורכב מ-6 תווים (אותיות באנגלית ומספרים).');
    }
    // קוד החבר נגזר מה-uid, אבל השדה בכרטיס נכתב ע"י הבעלים - כך שמישהו
    // יכול להעתיק קוד של אחר. מאמתים מול ה-uid ומתעלמים ממתחזים.
    final snap = await _profiles.where('friendCode', isEqualTo: normalized).limit(10).get();
    for (final doc in snap.docs) {
      if (SocialRepository.friendCodeFor(doc.id) == normalized) {
        return mapProfile(doc.id, doc.data());
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // חברים
  // ---------------------------------------------------------------------------

  @override
  Stream<List<FriendEntry>> watchFriends() {
    late StreamController<List<FriendEntry>> controller;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? listSub;
    final profileSubs = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];
    var records = <String, FriendRecord>{};
    final profiles = <String, PublicProfile>{};
    var listReady = false;
    // uids שכבר קיבלנו עבורם תשובה (גם אם אין להם כרטיס) - כדי לא להציג
    // לרגע "חבר/ה" כללי לפני שהכרטיס האמיתי נטען.
    final resolved = <String>{};

    void emit() {
      if (!listReady || controller.isClosed) return;
      if (!records.keys.every(resolved.contains)) return;
      final entries = [
        for (final record in records.values)
          FriendEntry(
            profile: profiles[record.uid] ?? PublicProfile(uid: record.uid, displayName: 'חבר/ה'),
            record: record,
          ),
      ];
      controller.add(entries);
    }

    void resubscribeProfiles(List<String> uids) {
      for (final sub in profileSubs) {
        sub.cancel();
      }
      profileSubs.clear();
      for (int i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(i, i + 30 > uids.length ? uids.length : i + 30);
        profileSubs.add(
          _profiles.where(FieldPath.documentId, whereIn: chunk).limit(chunk.length).snapshots().listen((snap) {
            for (final doc in snap.docs) {
              profiles[doc.id] = mapProfile(doc.id, doc.data());
            }
            resolved.addAll(chunk);
            emit();
          }, onError: (_) {
            resolved.addAll(chunk);
            emit();
          }),
        );
      }
    }

    controller = StreamController<List<FriendEntry>>.broadcast(
      onListen: () async {
        try {
          final uid = await ensureSignedIn();
          listSub = _friendsOf(uid).snapshots().listen((snap) {
            final previous = records.keys.toSet();
            records = {
              for (final doc in snap.docs)
                doc.id: FriendRecord(
                  uid: doc.id,
                  since: (doc.data()['since'] as Timestamp?)?.toDate(),
                  wins: (doc.data()['wins'] as num?)?.toInt() ?? 0,
                  losses: (doc.data()['losses'] as num?)?.toInt() ?? 0,
                  games: (doc.data()['games'] as num?)?.toInt() ?? 0,
                ),
            };
            listReady = true;
            final next = records.keys.toSet();
            if (next.length != previous.length || !next.containsAll(previous)) {
              profiles.removeWhere((key, _) => !next.contains(key));
              resubscribeProfiles(next.toList());
            }
            emit();
          }, onError: controller.addError);
        } catch (e) {
          controller.addError(e);
        }
      },
      onCancel: () {
        listSub?.cancel();
        for (final sub in profileSubs) {
          sub.cancel();
        }
        profileSubs.clear();
      },
    );
    return controller.stream;
  }

  FriendRequest _mapRequest(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return FriendRequest(
      id: doc.id,
      fromUid: data['from'] as String? ?? '',
      toUid: data['to'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'שחקן/ית',
      fromAvatarId: data['fromAvatarId'] as String? ?? 'detective',
      fromPhotoUrl: data['fromPhotoUrl'] as String?,
      toName: data['toName'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Stream<List<FriendRequest>> _watchRequests(String field) async* {
    final uid = await ensureSignedIn();
    yield* _requests.where(field, isEqualTo: uid).snapshots().map((snap) {
      final list = snap.docs.map(_mapRequest).toList()
        ..sort((a, b) => (b.createdAt ?? DateTime.now()).compareTo(a.createdAt ?? DateTime.now()));
      return list;
    });
  }

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() => _watchRequests('to');

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() => _watchRequests('from');

  Future<Map<String, dynamic>> _myCardFields(String uid) async {
    final snap = await _profiles.doc(uid).get();
    final data = snap.data() ?? const {};
    final name = InputRules.sanitizeDisplayName(
      (data['displayName'] as String?) ?? _lastPublished?.displayName,
    );
    final photo = (data['photoUrl'] as String?) ?? _lastPublished?.photoUrl;
    return {
      'name': name.isEmpty ? 'שחקן/ית' : name,
      'avatarId': (data['avatarId'] as String?) ?? _lastPublished?.avatarId ?? 'detective',
      'photoUrl': InputRules.isTrustedPhotoUrl(photo) ? photo : null,
    };
  }

  @override
  Future<bool> sendFriendRequest(String toUid, {String toName = ''}) async {
    final me = await ensureSignedIn();
    if (toUid == me) throw const SocialException('זה הקוד שלך 😊 שלחו אותו לחברים.');

    final alreadyFriends = await _friendsOf(me).doc(toUid).get();
    if (alreadyFriends.exists) throw const SocialException('אתם כבר חברים!');

    // הצד השני כבר שלח לי בקשה? מאשרים מיד - בלי לחכות לשני הצדדים.
    final reverse = await _requests.doc(FriendRequest.idFor(toUid, me)).get();
    if (reverse.exists) {
      await acceptFriendRequest(_mapRequest(reverse));
      return true;
    }

    final card = await _myCardFields(me);
    await _requests.doc(FriendRequest.idFor(me, toUid)).set({
      'from': me,
      'to': toUid,
      'fromName': card['name'],
      'fromAvatarId': card['avatarId'],
      'fromPhotoUrl': card['photoUrl'],
      'toName': InputRules.sanitizeDisplayName(toName),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return false;
  }

  @override
  Future<void> acceptFriendRequest(FriendRequest request) async {
    final me = await ensureSignedIn();
    if (request.toUid != me) throw const SocialException('אפשר לאשר רק בקשות שנשלחו אליך.');
    final batch = _firestore.batch();
    final since = FieldValue.serverTimestamp();
    batch.set(_friendsOf(me).doc(request.fromUid), {
      'since': since,
      'wins': 0,
      'losses': 0,
      'games': 0,
    }, SetOptions(merge: true));
    batch.set(_friendsOf(request.fromUid).doc(me), {
      'since': since,
      'wins': 0,
      'losses': 0,
      'games': 0,
    }, SetOptions(merge: true));
    batch.delete(_requests.doc(request.id));
    await batch.commit();
  }

  @override
  Future<void> declineFriendRequest(FriendRequest request) async {
    await _requests.doc(request.id).delete();
  }

  @override
  Future<void> cancelFriendRequest(String toUid) async {
    final me = await ensureSignedIn();
    await _requests.doc(FriendRequest.idFor(me, toUid)).delete();
  }

  @override
  Future<void> removeFriend(String friendUid) async {
    final me = await ensureSignedIn();
    final batch = _firestore.batch();
    batch.delete(_friendsOf(me).doc(friendUid));
    batch.delete(_friendsOf(friendUid).doc(me));
    await batch.commit();
  }

  // ---------------------------------------------------------------------------
  // הזמנות למשחק
  // ---------------------------------------------------------------------------

  GameInvite _mapInvite(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return GameInvite(
      id: doc.id,
      fromUid: data['from'] as String? ?? '',
      fromName: data['fromName'] as String? ?? 'חבר/ה',
      fromAvatarId: data['fromAvatarId'] as String? ?? 'detective',
      fromPhotoUrl: data['fromPhotoUrl'] as String?,
      toUid: data['to'] as String? ?? '',
      toName: data['toName'] as String? ?? '',
      roomCode: data['roomCode'] as String? ?? '',
      gridSize: (data['gridSize'] as num?)?.toInt() ?? 5,
      roundSeconds: (data['roundSeconds'] as num?)?.toInt() ?? 90,
      entryFee: (data['entryFee'] as num?)?.toInt() ?? 5,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      status: InviteStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => InviteStatus.pending,
      ),
    );
  }

  @override
  Future<GameInvite> sendInvite({
    required String toUid,
    String toName = '',
    required String roomCode,
    required int gridSize,
    required int roundSeconds,
    required int entryFee,
  }) async {
    final me = await ensureSignedIn();
    final card = await _myCardFields(me);
    final ref = _invites.doc();
    await ref.set({
      'from': me,
      'to': toUid,
      'fromName': card['name'],
      'fromAvatarId': card['avatarId'],
      'fromPhotoUrl': card['photoUrl'],
      'toName': InputRules.sanitizeDisplayName(toName),
      'roomCode': roomCode,
      'gridSize': gridSize,
      'roundSeconds': roundSeconds,
      'entryFee': entryFee,
      'status': InviteStatus.pending.name,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return GameInvite(
      id: ref.id,
      fromUid: me,
      fromName: card['name'] as String,
      fromAvatarId: card['avatarId'] as String,
      fromPhotoUrl: card['photoUrl'] as String?,
      toUid: toUid,
      toName: toName,
      roomCode: roomCode,
      gridSize: gridSize,
      roundSeconds: roundSeconds,
      entryFee: entryFee,
      createdAt: DateTime.now(),
    );
  }

  @override
  Stream<List<GameInvite>> watchIncomingInvites() async* {
    final uid = await ensureSignedIn();
    yield* _invites
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: InviteStatus.pending.name)
        .snapshots()
        .map((snap) => snap.docs.map(_mapInvite).where((i) => i.isActive()).toList());
  }

  @override
  Stream<List<GameInvite>> watchSentInvites(String roomCode) async* {
    final uid = await ensureSignedIn();
    yield* _invites
        .where('from', isEqualTo: uid)
        .where('roomCode', isEqualTo: roomCode)
        .snapshots()
        .map((snap) => snap.docs.map(_mapInvite).toList());
  }

  @override
  Future<void> respondToInvite(GameInvite invite, {required bool accept}) async {
    await _invites.doc(invite.id).update({
      'status': (accept ? InviteStatus.accepted : InviteStatus.declined).name,
      'respondedAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------------------------------------------------------------------------
  // דיווח וחסימה
  // ---------------------------------------------------------------------------

  @override
  Future<void> reportUser({
    required String uid,
    required String name,
    required ReportReason reason,
    String context = '',
  }) async {
    final me = await ensureSignedIn();
    if (uid == me) return;
    await _reports.add({
      'reporter': me,
      'reported': uid,
      'reportedName': InputRules.sanitizeDisplayName(name).isEmpty ? 'unknown' : InputRules.sanitizeDisplayName(name),
      'reason': reason.code,
      'context': context.length > 200 ? context.substring(0, 200) : context,
      'status': 'open',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> blockUser(String uid, {String name = ''}) async {
    final me = await ensureSignedIn();
    if (uid == me) return;
    await _blocksOf(me).doc(uid).set({
      'name': InputRules.sanitizeDisplayName(name),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // ניקוי כל הקשרים הקיימים. כל מחיקה בנפרד, כדי שכשל אחד (למשל מסמך
    // שכבר לא קיים) לא יעצור את השאר.
    Future<void> quietly(Future<void> Function() op) async {
      try {
        await op();
      } catch (_) {}
    }

    await quietly(() => removeFriend(uid));
    await quietly(() => _requests.doc(FriendRequest.idFor(me, uid)).delete());
    await quietly(() => _requests.doc(FriendRequest.idFor(uid, me)).delete());
    await quietly(() async {
      final invites = await _invites.where('to', isEqualTo: me).where('from', isEqualTo: uid).get();
      for (final doc in invites.docs) {
        await doc.reference.delete();
      }
    });
  }

  @override
  Future<void> unblockUser(String uid) async {
    final me = await ensureSignedIn();
    await _blocksOf(me).doc(uid).delete();
  }

  @override
  Stream<List<BlockedUser>> watchBlockedUsers() async* {
    final me = await ensureSignedIn();
    yield* _blocksOf(me).snapshots().map((snap) => [
          for (final doc in snap.docs)
            BlockedUser(
              uid: doc.id,
              name: (doc.data()['name'] as String?)?.isNotEmpty == true ? doc.data()['name'] as String : 'שחקן/ית',
              since: (doc.data()['createdAt'] as Timestamp?)?.toDate(),
            ),
        ]);
  }

  // ---------------------------------------------------------------------------
  // סטטיסטיקת משחקים
  // ---------------------------------------------------------------------------

  @override
  Future<void> recordMatch({required Map<String, int> scores, required String myUid}) async {
    final myScore = scores[myUid];
    if (myScore == null || scores.length < 2) return;
    final best = scores.values.reduce((a, b) => a > b ? a : b);
    final leaders = scores.values.where((s) => s == best).length;
    final iWon = myScore == best && leaders == 1;

    await _profiles.doc(myUid).set({
      'mpGames': FieldValue.increment(1),
      if (iWon) 'mpWins': FieldValue.increment(1),
    }, SetOptions(merge: true));

    final friendsSnap = await _friendsOf(myUid).get();
    final friendIds = friendsSnap.docs.map((d) => d.id).toSet();
    final batch = _firestore.batch();
    var any = false;
    for (final entry in scores.entries) {
      if (entry.key == myUid || !friendIds.contains(entry.key)) continue;
      any = true;
      batch.set(_friendsOf(myUid).doc(entry.key), {
        'games': FieldValue.increment(1),
        if (myScore > entry.value) 'wins': FieldValue.increment(1),
        if (myScore < entry.value) 'losses': FieldValue.increment(1),
        'lastPlayed': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
    if (any) await batch.commit();
  }
}
