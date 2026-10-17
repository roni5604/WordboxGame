import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/services/account_data_eraser.dart';
import 'package:wordbox_hebrew/data/services/push_device_store.dart';

void main() {
  test('registers a device under players/{uid}/devices/{token}', () async {
    final firestore = FakeFirebaseFirestore();
    final store = PushDeviceStore(firestore);

    await store.register(uid: 'alice', token: 'tok:1', platform: 'android');
    final doc = await firestore.doc('players/alice/devices/tok:1').get();
    expect(doc.exists, isTrue);
    expect(doc.data()!['token'], 'tok:1');
    expect(doc.data()!['platform'], 'android');
    expect(doc.data()!.keys, containsAll(['token', 'platform', 'updatedAt']));

    // אותו טוקן שוב - אותו מסמך, לא כפילות.
    await store.register(uid: 'alice', token: 'tok:1', platform: 'android');
    expect((await store.devices('alice').get()).docs, hasLength(1));

    await store.remove(uid: 'alice', token: 'tok:1');
    expect((await store.devices('alice').get()).docs, isEmpty);
  });

  test('account deletion also removes the registered devices', () async {
    final firestore = FakeFirebaseFirestore();
    final store = PushDeviceStore(firestore);
    await firestore.doc('players/alice').set({'coins': 5});
    await store.register(uid: 'alice', token: 'tok:1', platform: 'ios');
    await store.register(uid: 'alice', token: 'tok:2', platform: 'web');
    await store.register(uid: 'bob', token: 'tok:3', platform: 'android');

    await AccountDataEraser(firestore).eraseUser('alice');

    expect((await store.devices('alice').get()).docs, isEmpty);
    expect((await store.devices('bob').get()).docs, hasLength(1));
    expect((await firestore.doc('players/alice').get()).exists, isFalse);
  });
}
