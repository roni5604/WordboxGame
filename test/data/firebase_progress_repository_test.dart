import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/firebase_progress_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() => firestore = FakeFirebaseFirestore());

  test('שמירה נכתבת לחשבון שהמופע קשור אליו', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'roni'));
    final repo = FirebaseProgressRepository(firestore: firestore, auth: auth, boundUid: 'roni');
    await repo.saveProfile(const PlayerProfile(displayName: 'רוני', coins: 476));
    final doc = await firestore.collection('players').doc('roni').get();
    expect(doc.data()!['displayName'], 'רוני');
    expect(doc.data()!['coins'], 476);
  });

  test('אחרי החלפת חשבון: שמירה מאוחרת של החשבון הקודם לא דורסת את החדש', () async {
    // המופע הישן קשור ל"רוני", אבל המחובר/ת עכשיו הוא/היא אורח/ת חדש/ה.
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'guest2', isAnonymous: true));
    final stale = FirebaseProgressRepository(firestore: firestore, auth: auth, boundUid: 'roni');
    await stale.saveProfile(const PlayerProfile(displayName: 'רוני', coins: 476));

    expect((await firestore.collection('players').doc('guest2').get()).exists, isFalse);
    expect((await firestore.collection('players').doc('roni').get()).exists, isFalse);
  });

  test('חשבון אורח חדש נטען נקי - בלי השם והמטבעות של החשבון הקודם', () async {
    await firestore.collection('players').doc('roni').set({'displayName': 'רוני', 'coins': 476});
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'guest2', isAnonymous: true));
    final repo = FirebaseProgressRepository(firestore: firestore, auth: auth, boundUid: 'guest2');
    final profile = await repo.loadProfile();
    expect(profile.displayName, isNot('רוני'));
    expect(profile.coins, 0);
    expect(profile.authIntroShown, isFalse, reason: 'אורח/ת חדש/ה רואה שוב את מסך הפתיחה');
  });

  test('התחברות לחשבון קיים טוענת את ההתקדמות שלו', () async {
    await firestore.collection('players').doc('roni').set({
      'displayName': 'רוני',
      'coins': 476,
      'highestUnlockedLevel': 8,
      'authIntroShown': true,
      'onboardingCompleted': true,
    });
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'roni'));
    final repo = FirebaseProgressRepository(firestore: firestore, auth: auth, boundUid: 'roni');
    final profile = await repo.loadProfile();
    expect(profile.displayName, 'רוני');
    expect(profile.coins, 476);
    expect(profile.highestUnlockedLevel, 8);
  });
}
