import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/ads/ads_runtime.dart';
import 'package:wordbox_hebrew/core/purchases/iap_controller.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/game/game_screen.dart';
import 'package:wordbox_hebrew/features/game/level_result_screen.dart';
import 'package:wordbox_hebrew/features/store/store_screen.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

import 'ads/fake_ads_gateway.dart';

class _MemoryProgressRepository implements ProgressRepository {
  PlayerProfile stored;
  _MemoryProgressRepository(this.stored);

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    stored = profile;
  }
}

class _WebIap extends IapController {
  _WebIap(Ref ref) : super(ref, autoInit: false) {
    state = const IapState(ready: true, isWeb: true);
  }
}

void main() {
  testWidgets('באתר לשונית הכסף מציגה שהרכישה זמינה רק באפליקציה', (tester) async {
    final router = GoRouter(
      initialLocation: '/store',
      routes: [
        GoRoute(path: '/store', builder: (_, __) => const StoreScreen()),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            _MemoryProgressRepository(const PlayerProfile(coins: 200, hints: 3)),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          adsGatewayProvider.overrideWith((ref) => FakeAdsGateway(supported: false)),
          iapProvider.overrideWith((ref) => _WebIap(ref)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('כסף'));
    await tester.pumpAndSettle();

    expect(
      find.text('רכישה בכסף אמיתי זמינה באפליקציה ל-iPhone ולאנדרואיד.'),
      findsOneWidget,
    );
    expect(find.text('באפליקציה'), findsWidgets);
    expect(find.text('200 מטבעות'), findsOneWidget);
    expect(find.text('5 רמזים'), findsOneWidget);

    await tester.tap(find.text('עיצובים'));
    await tester.pumpAndSettle();
    expect(find.text('אוקיינוס'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('לבן על כחול'), 300);
    expect(find.text('לבן על כחול'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('מקווקו'), 300);
    expect(find.text('מקווקו'), findsOneWidget);
  });

  testWidgets('מסך סיום בלי כוכב: בית, שוב, והשלב הבא כבוי', (tester) async {
    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(
          path: '/result',
          builder: (_, __) => LevelResultScreen(
            levelNumber: 1,
            result: const GameScreenResult(
              score: 2,
              stars: 0,
              foundWordsCount: 1,
              totalPossibleWords: 8,
              totalPossibleScore: 20,
              foundWordsDisplay: ['אב'],
              coinsEarned: 0,
            ),
          ),
        ),
        GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('home'))),
        GoRoute(path: '/store', builder: (_, __) => const Scaffold(body: Text('store'))),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            _MemoryProgressRepository(const PlayerProfile(coins: 10)),
          ),
          adsGatewayProvider.overrideWith((ref) => FakeAdsGateway(supported: false)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.replay_rounded), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(find.text('צריך לפחות כוכב אחד כדי לעבור שלב'), findsOneWidget);
    expect(find.text('2 מתוך 9'), findsOneWidget);

    expect(find.text('השלב הבא'), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is ButtonStyleButton && widget.onPressed == null,
      ),
      findsOneWidget,
    );
    expect(CampaignLevels.byLevelNumber(1).scoreRequired, 9);
  });
}
