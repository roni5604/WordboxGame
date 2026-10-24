import 'dart:async';

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/auth_user.dart';
import 'package:wordbox_hebrew/features/social/models/social_models.dart';
import 'package:wordbox_hebrew/features/social/services/firestore_social_repository.dart';
import 'package:wordbox_hebrew/features/social/services/social_repository.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/social_provider.dart';

/// התרחיש מהבאג: בטלפון משחקים כאורח/ת, מתחברים עם Apple (חשבון חדש),
/// והבודק מוסיף את קוד החבר שמופיע עכשיו. החבר חייב להופיע ברשימה בטלפון,
/// וקוד החבר חייב להיות של החשבון החדש - בלי לסגור ולפתוח את האפליקציה.
void main() {
  late FakeFirebaseFirestore firestore;
  late StreamController<AuthUser?> auth;
  late ProviderContainer phone;

  FirestoreSocialRepository repoAs(String uid) => FirestoreSocialRepository(
    firestore: firestore,
    auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: uid)),
  );

  Future<void> switchTo(String? uid) async {
    auth.add(
      uid == null ? null : AuthUser(uid: uid, isAnonymous: uid.startsWith('guest'), provider: AuthProviderType.apple),
    );
    await pumpEventQueue();
  }

  setUp(() async {
    firestore = FakeFirebaseFirestore();
    auth = StreamController<AuthUser?>.broadcast();
    phone = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        // ה-provider האמיתי, רק עם Firestore ו-Auth מדומים לכל חשבון.
        socialRepositoryFactoryProvider.overrideWithValue((uid) => repoAs(uid ?? 'nobody')),
      ],
    );
    // כמו באפליקציה: מסך החברים וה-SocialHost מאזינים כל הזמן.
    phone.listen(authStateProvider, (_, _) {});
    phone.listen(friendsProvider, (_, _) {});
    phone.listen(incomingFriendRequestsProvider, (_, _) {});
    phone.listen(incomingInvitesProvider, (_, _) {});
    phone.listen(socialUidProvider, (_, _) {});

    for (final (uid, name) in [('tester', 'בודק'), ('guest-1', 'רוני'), ('apple-1', 'רוני')]) {
      await repoAs(
        uid,
      ).publishMyProfile(MyPublicInfo(displayName: name, avatarId: 'detective', totalStars: 0, highestLevel: 1));
    }
  });

  tearDown(() async {
    phone.dispose();
    await auth.close();
  });

  Future<List<FriendEntry>> phoneFriends() async {
    await pumpEventQueue();
    return phone.read(friendsProvider).valueOrNull ?? const [];
  }

  test('אחרי כניסה עם Apple: קוד החבר והרשימה של החשבון החדש, והבודק מופיע', () async {
    await switchTo('guest-1');
    expect(await phone.read(socialUidProvider.future), 'guest-1');

    await switchTo('apple-1');
    // קוד החבר שמוצג במסך החברים הוא של החשבון החדש.
    final uid = await phone.read(socialUidProvider.future);
    expect(uid, 'apple-1');
    expect(SocialRepository.friendCodeFor(uid!), SocialRepository.friendCodeFor('apple-1'));

    // הבודק מוצא את הטלפון לפי הקוד ושולח בקשה.
    final tester = repoAs('tester');
    final found = await tester.findByFriendCode(SocialRepository.friendCodeFor(uid));
    expect(found?.uid, 'apple-1');
    await tester.sendFriendRequest(found!.uid, toName: found.displayName);

    // הבקשה מגיעה לטלפון, מאשרים - והבודק ברשימת החברים בטלפון.
    await pumpEventQueue();
    final requests = phone.read(incomingFriendRequestsProvider).valueOrNull ?? const [];
    expect(requests.map((r) => r.fromUid), ['tester']);
    await phone.read(socialRepositoryProvider).acceptFriendRequest(requests.single);

    final friends = await phoneFriends();
    expect(friends.map((f) => f.uid), ['tester']);
    expect(friends.single.profile.displayName, 'בודק');

    // ושני הצדדים רואים זה את זה.
    final testerFriends = await tester.watchFriends().firstWhere((l) => l.isNotEmpty);
    expect(testerFriends.map((f) => f.uid), ['apple-1']);
  });

  test('חבר שנוסף לחשבון החדש מופיע מיד, וחברי החשבון הקודם לא נשארים', () async {
    await switchTo('guest-1');
    await repoAs('guest-1').sendFriendRequest('tester');
    final toTester = await repoAs('tester').watchIncomingRequests().first;
    await repoAs('tester').acceptFriendRequest(toTester.single);
    expect((await phoneFriends()).map((f) => f.uid), ['tester']);

    // מחיקת חשבון / יציאה וכניסה לחשבון אחר.
    await switchTo('apple-1');
    expect(await phoneFriends(), isEmpty);

    await repoAs('tester').sendFriendRequest('apple-1');
    await pumpEventQueue();
    final incoming = phone.read(incomingFriendRequestsProvider).valueOrNull ?? const [];
    await phone.read(socialRepositoryProvider).acceptFriendRequest(incoming.single);
    expect((await phoneFriends()).map((f) => f.uid), ['tester']);
  });

  test('הזמנה למשחק לחשבון החדש מגיעה לטלפון אחרי החלפת חשבון', () async {
    await switchTo('guest-1');
    await switchTo('apple-1');
    await repoAs('tester').sendInvite(toUid: 'apple-1', roomCode: 'ABCD', gridSize: 5, roundSeconds: 90, entryFee: 5);
    await pumpEventQueue();
    final invites = phone.read(incomingInvitesProvider).valueOrNull ?? const [];
    expect(invites.map((i) => i.fromUid), ['tester']);
  });

  test('אחרי התנתקות אין רשימות, וכניסה חוזרת מחזירה את החברים', () async {
    await switchTo('apple-1');
    await repoAs('tester').sendFriendRequest('apple-1');
    final req = await repoAs('apple-1').watchIncomingRequests().first;
    await repoAs('apple-1').acceptFriendRequest(req.single);
    expect((await phoneFriends()).map((f) => f.uid), ['tester']);

    await switchTo(null);
    expect(await phoneFriends(), isEmpty);

    await switchTo('apple-1');
    expect((await phoneFriends()).map((f) => f.uid), ['tester']);
  });
}
