import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/race_config.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_setup_screen.dart';
import 'package:wordbox_hebrew/game_engine/bot_player.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

class _MemoryProgressRepository implements ProgressRepository {
  PlayerProfile stored;
  _MemoryProgressRepository(this.stored);

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async => stored = profile;
}

void main() {
  RaceConfig? started;

  Future<void> pumpSetup(WidgetTester tester, Size size) async {
    started = null;
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/setup',
      routes: [
        GoRoute(path: '/setup', builder: (_, _) => const RaceSetupScreen()),
        GoRoute(
          path: '/multiplayer/race',
          builder: (_, state) {
            started = state.extra as RaceConfig;
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            _MemoryProgressRepository(const PlayerProfile(displayName: 'רוני')),
          ),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(402, 874), Size(375, 667)]) {
    testWidgets('מסך אחד בלי גלילה ובלי גלישה (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      await pumpSetup(tester, size);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'בלי שדה "השם שלך בתחרות"');
      expect(find.text('בואו נתחרה!'), findsOneWidget);
      expect(find.text('VS'), findsOneWidget);
      // כל צירוף של יריבים ורמה - בלי גלישה.
      for (final n in ['1', '2', '3']) {
        for (final level in BotDifficulty.values) {
          await tester.tap(find.text(n).first);
          await tester.tap(find.text(level.labelHe));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$n יריבים, ${level.labelHe}');
        }
      }
    });
  }

  testWidgets('הבחירות עוברות לתחרות, והשם מגיע מהפרופיל', (tester) async {
    await pumpSetup(tester, const Size(402, 874));
    await tester.tap(find.text('3'));
    await tester.tap(find.text(BotDifficulty.hard.labelHe));
    await tester.tap(find.text('5×5'));
    await tester.tap(find.text('120 שנ׳'));
    await tester.pumpAndSettle();
    expect(find.text('3 יריבים'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('בואו נתחרה!'));
    await tester.pumpAndSettle();
    expect(started, isNotNull);
    expect(started!.bots, hasLength(3));
    expect(started!.bots.every((b) => b.difficulty == BotDifficulty.hard), isTrue);
    expect(started!.gridSize, 5);
    expect(started!.timeLimit, const Duration(seconds: 120));
    expect(started!.humanName, 'רוני');
  });
}
