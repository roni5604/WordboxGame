import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/core/ads/ads_runtime.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/game/game_screen.dart';
import 'package:wordbox_hebrew/features/game/level_result_screen.dart';
import 'package:wordbox_hebrew/features/home/home_screen.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

import 'fake_ads_gateway.dart';

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository(this.profile);

  PlayerProfile profile;

  @override
  Future<PlayerProfile> loadProfile() async => profile;

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    this.profile = profile;
  }
}

GoRouter _resultRouter(GameScreenResult gameResult) {
  return GoRouter(
    initialLocation: '/level/6/result',
    initialExtra: gameResult,
    routes: [
      GoRoute(
        path: '/level/:levelNumber/result',
        builder: (context, state) => LevelResultScreen(
          levelNumber: int.parse(state.pathParameters['levelNumber']!),
          result: state.extra as GameScreenResult,
        ),
      ),
      GoRoute(
        path: '/level/:levelNumber/intro',
        builder: (context, state) =>
            Text('intro ${state.pathParameters['levelNumber']}'),
      ),
      GoRoute(
        path: '/campaign',
        builder: (context, state) => const Text('campaign'),
      ),
    ],
  );
}

Widget _routerApp({
  required FakeAdsGateway ads,
  required _MemoryProgressRepository progress,
  required GoRouter router,
}) {
  return ProviderScope(
    overrides: [
      adsGatewayProvider.overrideWith((ref) => ads),
      progressRepositoryProvider.overrideWithValue(progress),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => Directionality(
        textDirection: TextDirection.rtl,
        child: child ?? const SizedBox.shrink(),
      ),
    ),
  );
}

/// מסך התוצאה מתזמן חגיגה אחרי 400ms ו-1400ms. בלי לנקז אותן הבדיקה
/// נכשלת על טיימר שעדיין פתוח.
Future<void> _drainResultTimers(WidgetTester tester) async {
  await tester.pump(const Duration(seconds: 3));
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  GameScreenResult result({int stars = 2, int coins = 24}) {
    return GameScreenResult(
      score: 40,
      stars: stars,
      foundWordsCount: 3,
      totalPossibleWords: 8,
      totalPossibleScore: 100,
      foundWordsDisplay: const ['בית'],
      coinsEarned: coins,
      levelKind: LevelKind.normal,
    );
  }

  Widget harness({
    required Widget child,
    required FakeAdsGateway ads,
    required _MemoryProgressRepository progress,
  }) {
    return ProviderScope(
      overrides: [
        adsGatewayProvider.overrideWith((ref) => ads),
        progressRepositoryProvider.overrideWithValue(progress),
      ],
      child: MaterialApp(
        locale: const Locale('he', 'IL'),
        builder: (context, body) => Directionality(
          textDirection: TextDirection.rtl,
          child: body ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    );
  }

  testWidgets('הכפלת מטבעות מוסיפה את מה שכבר הורווח, פעם אחת', (tester) async {
    final ads = FakeAdsGateway();
    final progress = _MemoryProgressRepository(const PlayerProfile(coins: 10));

    await tester.pumpWidget(
      harness(
        ads: ads,
        progress: progress,
        child: LevelResultScreen(levelNumber: 6, result: result(stars: 1)),
      ),
    );
    await tester.pump();

    expect(find.textContaining('הכפילו'), findsOneWidget);
    await tester.tap(find.textContaining('הכפילו'));
    await tester.pump();
    await tester.pump();

    expect(ads.showRewardedCount, 1);
    expect(progress.profile.coins, 34);
    expect(find.text('המטבעות הוכפלו!'), findsOneWidget);
    await _drainResultTimers(tester);
  });

  testWidgets('בלי תמיכה בפרסומות אין כפתור הכפלה', (tester) async {
    final ads = FakeAdsGateway(supported: false);
    final progress = _MemoryProgressRepository(const PlayerProfile());

    await tester.pumpWidget(
      harness(
        ads: ads,
        progress: progress,
        child: LevelResultScreen(levelNumber: 6, result: result(stars: 1)),
      ),
    );
    await tester.pump();
    expect(find.textContaining('הכפילו'), findsNothing);
    await _drainResultTimers(tester);
  });

  testWidgets('שחקו שוב לא מציג אינטרסטיאל', (tester) async {
    final ads = FakeAdsGateway(supported: false);
    final progress = _MemoryProgressRepository(const PlayerProfile());

    await tester.pumpWidget(
      _routerApp(ads: ads, progress: progress, router: _resultRouter(result())),
    );
    await tester.pump();
    expect(ads.recordedLevels, [6]);

    await tester.tap(find.text('שחקו שוב'));
    await tester.pump();
    await tester.pump();
    expect(ads.interstitialLevels, isEmpty);
    expect(find.text('intro 6'), findsOneWidget);
    await _drainResultTimers(tester);
  });

  testWidgets('השלב הבא מבקש אינטרסטיאל', (tester) async {
    final ads = FakeAdsGateway(supported: false);
    final progress = _MemoryProgressRepository(const PlayerProfile());

    await tester.pumpWidget(
      _routerApp(
        ads: ads,
        progress: progress,
        router: _resultRouter(result(stars: 1)),
      ),
    );
    await tester.pump();

    await tester.tap(find.text('השלב הבא'));
    await tester.pump();
    await tester.pump();
    expect(ads.interstitialLevels, [6]);
    expect(find.text('intro 7'), findsOneWidget);
    await _drainResultTimers(tester);
  });

  testWidgets('כרטיס פרסומת גבוה במסך הבית לא שובר את הגלילה', (tester) async {
    tester.view.physicalSize = const Size(1400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final ads = FakeAdsGateway(
      native: const SizedBox(
        key: Key('native-ad'),
        height: 420,
        child: Text('פרסומת'),
      ),
    );
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(
          path: '/campaign',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/multiplayer',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/how-to-play',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/rules', builder: (context, state) => const SizedBox()),
        GoRoute(
          path: '/settings',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/store', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/auth', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          adsGatewayProvider.overrideWith((ref) => ads),
          progressRepositoryProvider.overrideWithValue(
            _MemoryProgressRepository(
              PlayerProfile(lastHintClaimDate: _todayKey()),
            ),
          ),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('שחקו!'), findsOneWidget);
    expect(find.text('פרסומת'), findsNothing);
  });
}
