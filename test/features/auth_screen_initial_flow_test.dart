import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/auth_user.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/auth_repository.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/auth/auth_screen.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

/// שומר את הפרופיל האחרון שנשמר, כדי שנוכל לוודא ש-authIntroShown נשמר.
class _FakeProgressRepository implements ProgressRepository {
  PlayerProfile? saved;

  @override
  Future<PlayerProfile> loadProfile() async => const PlayerProfile();

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    saved = profile;
  }
}

/// מימוש מזויף שלא נוגע ב-Hive האמיתי - רק מדגים "אורח/ת" מוצלח, כדי
/// לבדוק את זרימת ה-UI במסך ההתחברות הראשוני בבידוד.
class _FakeAuthRepository implements AuthRepository {
  final _controller = StreamController<AuthUser?>.broadcast();
  bool guestCalled = false;

  @override
  Stream<AuthUser?> authStateChanges() => _controller.stream;

  @override
  AuthUser? get currentUser => null;

  @override
  Future<AuthUser> signInAsGuest() async {
    guestCalled = true;
    const user = AuthUser(uid: 'guest_test', isAnonymous: true, provider: AuthProviderType.guest);
    _controller.add(user);
    return user;
  }

  @override
  Future<AuthUser> signInWithGoogle() => throw const AuthException('n/a');

  @override
  Future<AuthUser> signInWithApple() => throw const AuthException('n/a');

  @override
  Future<AuthUser> signInWithFacebook() => throw const AuthException('n/a');

  @override
  Future<AuthUser> signInWithEmail({required String email, required String password}) =>
      throw const AuthException('n/a');

  @override
  Future<AuthUser> registerWithEmail({
    required String email,
    required String password,
    required String displayName,
  }) =>
      throw const AuthException('n/a');

  @override
  Future<void> signOut() async {}
}

void main() {
  testWidgets(
    'AuthScreen(isInitial: true): no back button, and "המשך כאורח/ת" '
    'מסמן authIntroShown ומנווט להדרכה',
    (tester) async {
      final fakeProgress = _FakeProgressRepository();
      final fakeAuth = _FakeAuthRepository();

      // מדמים בדיוק את מה ש-SplashScreen עושה בפועל: מחכים שהפרופיל
      // יסתיים להיטען (ensureLoaded) לפני שממש עוברים למסך ההתחברות -
      // כדי לוודא שה-container המשותף כבר במצב "data" ולא "loading".
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(fakeProgress),
          authRepositoryProvider.overrideWithValue(fakeAuth),
        ],
      );
      addTearDown(container.dispose);
      await container.read(playerProfileProvider.notifier).ensureLoaded();

      final router = GoRouter(
        initialLocation: '/auth',
        routes: [
          GoRoute(
            path: '/auth',
            builder: (context, state) => const AuthScreen(isInitial: true),
          ),
          GoRoute(
            path: '/onboarding',
            builder: (context, state) => const Scaffold(body: Text('ONBOARDING_SCREEN')),
          ),
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(body: Text('HOME_SCREEN')),
          ),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            builder: (context, child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // במסך הראשוני אין דרך חזרה - חייבים לבחור אפשרות התחברות.
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
      expect(find.text('המשך כאורח/ת בלי להתחבר'), findsOneWidget);

      // המסך גלילי (ListView) - מגלגלים כדי לוודא שהכפתור בפועל גלוי
      // ולחיץ, בדיוק כמו שהיה קורה במכשיר עם מסך קטן.
      await tester.ensureVisible(find.text('המשך כאורח/ת בלי להתחבר'));
      await tester.pump();

      await tester.tap(find.text('המשך כאורח/ת בלי להתחבר'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(fakeAuth.guestCalled, isTrue);
      expect(fakeProgress.saved?.authIntroShown, isTrue);
      expect(find.text('ONBOARDING_SCREEN'), findsOneWidget);
    },
  );
}
