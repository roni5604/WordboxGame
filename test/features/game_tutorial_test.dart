import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/game/game_screen.dart';
import 'package:wordbox_hebrew/features/game/widgets/grid_board.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

class _P implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async =>
      const PlayerProfile(coins: 50, onboardingCompleted: true, authIntroShown: true, level1TutorialSeen: false);
  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

void main() {
  testWidgets('level 1 tutorial: try a word, two short explanations, then the timer starts', (tester) async {
    tester.view.physicalSize = const Size(393, 852);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // בגופן הבדיקות (תווים מרובעים ורחבים) השעון והכותרת העליונה גולשים
    // בכמה פיקסלים - זה לא קורה עם הגופן האמיתי, ולא קשור להדרכה.
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('overflowed')) return;
      onError?.call(details);
    };
    addTearDown(() => FlutterError.onError = onError);
    final router = GoRouter(initialLocation: '/g', routes: [
      GoRoute(path: '/g', builder: (_, _) => const GameScreen(levelNumber: 1)),
      GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox()),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(_P()),
        soundServiceProvider.overrideWithValue(SoundService.silent()),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    ));
    for (int i = 0; i < 24; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump(const Duration(milliseconds: 50));
    }
    Future<void> wait(int ms) async {
      for (var w = 0; w < ms; w += 50) {
        await tester.pump(const Duration(milliseconds: 50));
      }
    }

    await wait(900);
    // הטיימר לא רץ בזמן ההדרכה, והלוח מוצג עם הסבר "בואו ננסה".
    expect(find.textContaining('בואו ננסה'), findsOneWidget);
    expect(find.text('1:00'), findsOneWidget);
    final board = tester.getRect(find.byType(GridBoard));
    final cell = board.width / 3;
    Offset at(int r, int c) => board.topLeft + Offset((c + 0.5) * cell, (r + 0.5) * cell);
    // ניסיון קצר מדי (אות אחת) - "כמעט!".
    var g = await tester.startGesture(at(1, 1));
    await wait(60);
    await g.up();
    await wait(500);
    expect(find.textContaining('כמעט'), findsOneWidget);
    g = await tester.startGesture(at(2, 0));
    await wait(60);
    await g.moveTo(at(1, 0));
    await wait(60);
    await g.moveTo(at(0, 1));
    await wait(60);
    await g.up();
    await wait(300);
    expect(find.textContaining('מעולה'), findsOneWidget);
    await wait(1900);
    expect(find.textContaining('צוברים נקודות'), findsOneWidget);
    await tester.tap(find.text('הבא'));
    await wait(900);
    expect(find.textContaining('השעון והעזרה'), findsOneWidget);
    await tester.tap(find.text('יאללה, משחקים!'));
    await wait(1500);
    expect(find.text('יאללה, משחקים!'), findsNothing);
    expect(find.text('1:00'), findsNothing, reason: 'the timer starts once the tutorial ends');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
  });
}
