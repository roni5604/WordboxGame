import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/services/auth_session.dart';

void main() {
  test('keeps the signed-in user', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'existing', isAnonymous: true));
    expect(await AuthSession.ensureUid(auth), 'existing');
  });

  test('parallel callers share one guest sign-in', () async {
    final auth = MockFirebaseAuth(mockUser: MockUser(uid: 'guest-1', isAnonymous: true));
    final results = await Future.wait([
      AuthSession.ensureUid(auth),
      AuthSession.ensureUid(auth),
      AuthSession.ensureUid(auth),
    ]).timeout(const Duration(seconds: 10));
    expect(results.toSet(), {'guest-1'});
    expect(await AuthSession.ensureUid(auth), 'guest-1');
  });
}
