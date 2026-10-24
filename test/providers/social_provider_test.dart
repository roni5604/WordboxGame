import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/auth_user.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/social_provider.dart';

AuthUser _user(String uid, {String? photoUrl}) =>
    AuthUser(uid: uid, isAnonymous: false, provider: AuthProviderType.apple, photoUrl: photoUrl);

void main() {
  late StreamController<AuthUser?> auth;
  late ProviderContainer container;

  setUp(() {
    auth = StreamController<AuthUser?>.broadcast();
    container = ProviderContainer(overrides: [authStateProvider.overrideWith((ref) => auth.stream)]);
    // מחזיקים את ה-providers חיים כמו שהמסכים עושים.
    container.listen(authStateProvider, (_, _) {});
    container.listen(socialRepositoryProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await auth.close();
  });

  Future<void> signIn(AuthUser? user) async {
    auth.add(user);
    await Future<void>.delayed(Duration.zero);
  }

  test('החלפת חשבון יוצרת repository חברתי חדש (וזרמים חדשים לחשבון החדש)', () async {
    await signIn(_user('guest-1'));
    final first = container.read(socialRepositoryProvider);

    await signIn(_user('apple-1'));
    final second = container.read(socialRepositoryProvider);
    expect(identical(first, second), isFalse);

    // עדכון שלא מחליף חשבון (למשל תמונת פרופיל) לא פותח הכל מחדש.
    await signIn(_user('apple-1', photoUrl: 'https://example.com/a.png'));
    expect(identical(second, container.read(socialRepositoryProvider)), isTrue);
  });

  test('בלי חשבון (אחרי התנתקות) הרשימות ריקות ולא נפתחים זרמים', () async {
    await signIn(null);
    container.listen(friendsProvider, (_, _) {});
    container.listen(incomingInvitesProvider, (_, _) {});
    await Future<void>.delayed(Duration.zero);

    expect(container.read(friendsProvider).valueOrNull, isEmpty);
    expect(container.read(incomingFriendRequestsProvider.future), completion(isEmpty));
    expect(container.read(incomingInvitesProvider).valueOrNull, isEmpty);
  });
}
