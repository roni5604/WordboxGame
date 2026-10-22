import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/social/friends_screen.dart';
import 'package:wordbox_hebrew/features/social/models/social_models.dart';
import 'package:wordbox_hebrew/features/social/services/social_repository.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/social_provider.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

import 'fake_social_repository.dart';

class _Progress implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async =>
      const PlayerProfile(displayName: 'רוני', onboardingCompleted: true, authIntroShown: true);

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

FakeSocialRepository _repo() => FakeSocialRepository(
      myUid: 'me',
      friends: [
        FriendEntry(
          profile: PublicProfile(uid: 'eve', displayName: 'איב', status: PresenceStatus.online, lastActive: DateTime.now()),
          record: const FriendRecord(uid: 'eve'),
        ),
      ],
      incoming: const [FriendRequest(id: 'x_me', fromUid: 'x', toUid: 'me', fromName: 'זר/ה')],
    );

Future<void> _pump(WidgetTester tester, FakeSocialRepository repo, {int tab = 0}) async {
  tester.view.physicalSize = const Size(2100, 2556);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  final router = GoRouter(routes: [GoRoute(path: '/', builder: (_, _) => FriendsScreen(initialTab: tab))]);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(_Progress()),
        socialRepositoryProvider.overrideWithValue(repo),
        soundServiceProvider.overrideWithValue(SoundService.silent()),
        authStateProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ),
  );
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (int i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('חבר/ה: ⋮ ← חסימה ← אישור חוסם/ת ומסיר/ה מהחברים', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);

    expect(find.text('איב'), findsWidgets);
    await tester.tap(find.byTooltip('דיווח / חסימה').first);
    await _settle(tester);
    expect(find.text('דיווח על משתמש/ת'), findsOneWidget);

    await tester.tap(find.text('חסימה'));
    await _settle(tester);
    expect(find.text('לחסום את איב?'), findsOneWidget);
    await tester.tap(find.text('חסימה').last);
    await _settle(tester);

    expect(repo.blocked.keys, ['eve']);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('חבר/ה: דיווח עם סיבה נשלח, ואפשר לוותר על חסימה', (tester) async {
    final repo = _repo();
    await _pump(tester, repo);

    await tester.tap(find.byTooltip('דיווח / חסימה').first);
    await _settle(tester);
    await tester.tap(find.text('דיווח על משתמש/ת'));
    await _settle(tester);
    await tester.tap(find.text(ReportReason.offensiveName.labelHe));
    await _settle(tester);

    expect(repo.reports.single.uid, 'eve');
    expect(repo.reports.single.reason, ReportReason.offensiveName);
    expect(find.text('תודה על הדיווח 🙏'), findsOneWidget);
    await tester.tap(find.text('לא עכשיו'));
    await _settle(tester);
    expect(repo.blocked, isEmpty);
  });

  testWidgets('בקשת חברות מזר/ה: אפשר לדווח/לחסום ישר מהבקשה', (tester) async {
    final repo = _repo();
    await _pump(tester, repo, tab: 1);

    expect(find.text('זר/ה'), findsOneWidget);
    await tester.tap(find.byTooltip('דיווח / חסימה').first);
    await _settle(tester);
    await tester.tap(find.text('חסימה'));
    await _settle(tester);
    await tester.tap(find.text('חסימה').last);
    await _settle(tester);
    expect(repo.blocked.keys, ['x']);
    await tester.pump(const Duration(seconds: 5));
  });
}
