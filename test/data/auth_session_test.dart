import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/services/auth_session.dart';

void main() {
  test('keeps the signed-in user', () async {
    final auth = MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'existing', isAnonymous: true));
    expect(await AuthSession.ensureUid(auth), 'existing');
  });

  test('parallel callers share one guest sign-in', () async {
    final auth = MockFirebaseAuth();
    final results = await Future.wait([
      AuthSession.ensureUid(auth),
      AuthSession.ensureUid(auth),
      AuthSession.ensureUid(auth),
    ]);
    expect(results.toSet(), hasLength(1));
    expect(auth.currentUser?.uid, results.first);
    // a later call reuses the same guest
    expect(await AuthSession.ensureUid(auth), results.first);
  });
}
