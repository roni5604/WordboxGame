import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/social/models/social_models.dart';
import 'package:wordbox_hebrew/features/social/services/firestore_social_repository.dart';
import 'package:wordbox_hebrew/features/social/services/social_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  FirestoreSocialRepository repoFor(String uid) => FirestoreSocialRepository(
        firestore: firestore,
        auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
      );

  Future<FirestoreSocialRepository> player(String uid, String name, {int stars = 0}) async {
    final repo = repoFor(uid);
    await repo.publishMyProfile(MyPublicInfo(
      displayName: name,
      avatarId: 'detective',
      totalStars: stars,
      highestLevel: 1,
    ));
    return repo;
  }

  setUp(() => firestore = FakeFirebaseFirestore());

  test('קוד חבר: 6 תווים, יציב, בלי תווים מבלבלים', () {
    final code = SocialRepository.friendCodeFor('abc');
    expect(code, hasLength(6));
    expect(code, SocialRepository.friendCodeFor('abc'));
    expect(code, isNot(SocialRepository.friendCodeFor('abd')));
    expect(code.contains(RegExp('[01OI]')), isFalse);
    expect(SocialRepository.normalizeFriendCode(' ab-c2 d3 '), 'ABC2D3');
  });

  test('מציאת שחקן לפי קוד חבר', () async {
    await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    final found = await omer.findByFriendCode(SocialRepository.friendCodeFor('dana').toLowerCase());
    expect(found?.uid, 'dana');
    expect(found?.displayName, 'דנה');
    expect(await omer.findByFriendCode('ZZZZZZ'), isNull);
    expect(() => omer.findByFriendCode('AB'), throwsA(isA<SocialException>()));
  });

  test('בקשת חברות → אישור → שני הצדדים רואים זה את זה', () async {
    final dana = await player('dana', 'דנה', stars: 12);
    final omer = await player('omer', 'עומר', stars: 30);

    final becameFriends = await dana.sendFriendRequest('omer', toName: 'עומר');
    expect(becameFriends, isFalse);

    final incoming = await omer.watchIncomingRequests().first;
    expect(incoming, hasLength(1));
    expect(incoming.single.fromName, 'דנה');
    expect((await dana.watchOutgoingRequests().first), hasLength(1));

    await omer.acceptFriendRequest(incoming.single);

    expect(await omer.watchIncomingRequests().first, isEmpty);
    final danaFriends = await dana.watchFriends().firstWhere((l) => l.isNotEmpty);
    expect(danaFriends.single.uid, 'omer');
    expect(danaFriends.single.profile.totalStars, 30);
    final omerFriends = await omer.watchFriends().firstWhere((l) => l.isNotEmpty);
    expect(omerFriends.single.profile.displayName, 'דנה');
  });

  test('אם שני הצדדים שולחים בקשה - הופכים לחברים מיד', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    await dana.sendFriendRequest('omer');
    final instant = await omer.sendFriendRequest('dana');
    expect(instant, isTrue);
    expect((await omer.watchFriends().firstWhere((l) => l.isNotEmpty)).single.uid, 'dana');
  });

  test('אי אפשר להוסיף את עצמך או חבר קיים', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    expect(() => dana.sendFriendRequest('dana'), throwsA(isA<SocialException>()));
    await dana.sendFriendRequest('omer');
    await omer.acceptFriendRequest((await omer.watchIncomingRequests().first).single);
    expect(() => dana.sendFriendRequest('omer'), throwsA(isA<SocialException>()));
  });

  test('הסרת חבר מוחקת את הקשר משני הצדדים', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    await dana.sendFriendRequest('omer');
    await omer.acceptFriendRequest((await omer.watchIncomingRequests().first).single);
    await dana.removeFriend('omer');
    expect(await dana.watchFriends().first, isEmpty);
    expect(await omer.watchFriends().first, isEmpty);
  });

  test('נוכחות: פעימה מסמנת מחובר/ת, יציאה מסמנת לא מחובר/ת', () async {
    final dana = await player('dana', 'דנה');
    await dana.heartbeat(PresenceStatus.online);
    var profile = (await dana.fetchProfiles(['dana'])).single;
    expect(profile.isOnline(), isTrue);
    expect(profile.presenceLabel(), 'מחובר/ת עכשיו');
    await dana.heartbeat(PresenceStatus.playing);
    profile = (await dana.fetchProfiles(['dana'])).single;
    expect(profile.effectiveStatus(), PresenceStatus.playing);
    await dana.goOffline();
    profile = (await dana.fetchProfiles(['dana'])).single;
    expect(profile.isOnline(), isFalse);
  });

  test('פעימה ישנה מדי נחשבת "לא מחובר/ת" גם אם הסטטוס online', () {
    final stale = PublicProfile(
      uid: 'x',
      displayName: 'x',
      status: PresenceStatus.online,
      lastActive: DateTime.now().subtract(const Duration(minutes: 10)),
    );
    expect(stale.isOnline(), isFalse);
    expect(stale.presenceLabel(), 'נראה/תה לפני 10 דקות');
  });

  test('הזמנה למשחק: נשלחת, מופיעה אצל החבר, ונענית', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    await dana.sendInvite(toUid: 'omer', roomCode: '12345', gridSize: 5, roundSeconds: 90, entryFee: 5);

    final invites = await omer.watchIncomingInvites().firstWhere((l) => l.isNotEmpty);
    expect(invites.single.fromName, 'דנה');
    expect(invites.single.roomCode, '12345');

    await omer.respondToInvite(invites.single, accept: true);
    expect(await omer.watchIncomingInvites().first, isEmpty);
    final sent = await dana.watchSentInvites('12345').first;
    expect(sent.single.status, InviteStatus.accepted);
  });

  test('הזמנה שפג תוקפה לא מוצגת', () {
    final old = GameInvite(
      id: 'i',
      fromUid: 'a',
      fromName: 'a',
      toUid: 'b',
      roomCode: '1',
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );
    expect(old.isActive(), isFalse);
    expect(old.remaining(), Duration.zero);
  });

  test('תיעוד משחק: מאזן ראש בראש מול חברים ומונה ניצחונות כללי', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    await dana.sendFriendRequest('omer');
    await omer.acceptFriendRequest((await omer.watchIncomingRequests().first).single);

    await dana.recordMatch(scores: {'dana': 40, 'omer': 25, 'stranger': 10}, myUid: 'dana');
    await dana.recordMatch(scores: {'dana': 10, 'omer': 25}, myUid: 'dana');

    final me = (await dana.fetchProfiles(['dana'])).single;
    expect(me.mpGames, 2);
    expect(me.mpWins, 1);
    final record = (await dana.watchFriends().firstWhere((l) => l.isNotEmpty)).single.record;
    expect(record.games, 2);
    expect(record.wins, 1);
    expect(record.losses, 1);
  });

  test('חסימה: מסירה מהחברים, מוחקת בקשות, ונכנסת לרשימת החסומים', () async {
    final dana = await player('dana', 'דנה');
    final omer = await player('omer', 'עומר');
    await dana.sendFriendRequest('omer', toName: 'עומר');
    final incoming = await omer.watchIncomingRequests().first;
    await omer.acceptFriendRequest(incoming.single);
    expect(await dana.watchFriends().first, hasLength(1));

    // בקשה ממתינה נוספת מאיב, ואז חסימה של עומר ושל איב
    final eve = await player('eve', 'איב');
    await eve.sendFriendRequest('dana');
    await dana.blockUser('omer', name: 'עומר');
    await dana.blockUser('eve', name: 'איב');

    expect(await dana.watchFriends().first, isEmpty);
    expect(await omer.watchFriends().first, isEmpty);
    expect(await dana.watchIncomingRequests().first, isEmpty);
    final blocked = await dana.watchBlockedUsers().first;
    expect(blocked.map((b) => b.uid).toSet(), {'omer', 'eve'});
    expect(blocked.firstWhere((b) => b.uid == 'omer').name, 'עומר');

    await dana.unblockUser('eve');
    expect((await dana.watchBlockedUsers().first).map((b) => b.uid), ['omer']);
  });

  test('דיווח נשמר עם המדווח/ת, הסיבה וכינוי מנוקה', () async {
    final dana = await player('dana', 'דנה');
    await dana.reportUser(uid: 'eve', name: 'זונה', reason: ReportReason.offensiveName, context: 'friends_list');
    final reports = await firestore.collection('reports').get();
    expect(reports.docs, hasLength(1));
    final r = reports.docs.single.data();
    expect(r['reporter'], 'dana');
    expect(r['reported'], 'eve');
    expect(r['reason'], 'offensive_name');
    expect(r['status'], 'open');
    expect(r['reportedName'], 'unknown');
  });

  test('אי אפשר לדווח או לחסום את עצמי', () async {
    final dana = await player('dana', 'דנה');
    await dana.reportUser(uid: 'dana', name: 'דנה', reason: ReportReason.other);
    await dana.blockUser('dana');
    expect((await firestore.collection('reports').get()).docs, isEmpty);
    expect(await dana.watchBlockedUsers().first, isEmpty);
  });
}
