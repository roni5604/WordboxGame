import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/game/game_screen.dart';
import 'package:wordbox_hebrew/features/game/widgets/grid_board.dart';
import 'package:wordbox_hebrew/features/game/widgets/secret_word_card.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

class _Profile implements ProgressRepository {
  PlayerProfile stored = const PlayerProfile(
    coins: 2000,
    onboardingCompleted: true,
    authIntroShown: true,
    level1TutorialSeen: true,
    highestUnlockedLevel: 100,
    unlockedChapters: [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20],
  );

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async => stored = profile;
}

/// מסלול על הלוח שמרכיב את [word] (אותיות סופיות -> רגילות), בחיפוש DFS.
List<(int, int)>? _pathFor(List<List<String>> letters, String word) {
  final target = word.split('').map((c) => kSofitToBase[c] ?? c).toList();
  final n = letters.length;
  List<(int, int)>? dfs(int r, int c, int i, List<(int, int)> path) {
    if (letters[r][c] != target[i]) return null;
    final next = [...path, (r, c)];
    if (i == target.length - 1) return next;
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        final nr = r + dr, nc = c + dc;
        if ((dr == 0 && dc == 0) || nr < 0 || nc < 0 || nr >= n || nc >= n) continue;
        if (next.contains((nr, nc))) continue;
        final found = dfs(nr, nc, i + 1, next);
        if (found != null) return found;
      }
    }
    return null;
  }

  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      final p = dfs(r, c, 0, const []);
      if (p != null) return p;
    }
  }
  return null;
}

void main() {
  // שלב רגיל, מאסטר ופינאלה, בכל גודל לוח (3×3 עד 6×6), בשני גדלי מסך.
  // הכל בבדיקה אחת: משאבים (מילון/לוחות) נטענים פעם אחת ונשארים זמינים.
  const levels = [4, 6, 25, 26, 51, 75, 76, 100];
  const screens = {'iPhone 18 Pro': Size(402, 874), 'iPhone SE': Size(375, 667)};

  testWidgets('גלה מילה: בכל סוגי השלבים וגדלי הלוח, בלי שגיאות ובלי לכסות את הלוח', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    // גופן הבדיקות (ריבועים רחבים) גולש בכמה פיקסלים בכותרת/בשעון גם בלי
    // הכרטיס - לא נכשלים על זה, אבל כן על כל שגיאה אחרת או גלישה של הכרטיס.
    final errors = <String>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      if (text.contains('overflowed') && !details.toString().contains('SecretWordCard')) return;
      // אין נגן אודיו בסביבת הבדיקות (מוזיקה/צלילים) - לא קשור לבדיקה.
      if (text.contains('MissingPluginException') && text.contains('audioplayers')) return;
      errors.add(text);
    };
    final failures = <String>[];
    final checked = <String>[];
    try {
      Future<void> wait(int ms) async {
        for (var w = 0; w < ms; w += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      for (final screenEntry in screens.entries) {
        tester.view.physicalSize = screenEntry.value;
        for (final level in levels) {
          final config = CampaignLevels.byLevelNumber(level);
          final name = 'שלב $level (${config.gridSize}×${config.gridSize} ${config.kind.name}) · ${screenEntry.key}';
          void fail(String why) => failures.add('$name: $why');
          final router = GoRouter(
            initialLocation: '/g',
            routes: [
              GoRoute(
                path: '/g',
                builder: (_, _) => GameScreen(levelNumber: level),
              ),
              GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox()),
            ],
          );
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                progressRepositoryProvider.overrideWithValue(_Profile()),
                soundServiceProvider.overrideWithValue(SoundService.silent()),
              ],
              child: MaterialApp.router(
                routerConfig: router,
                builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
              ),
            ),
          );
          for (var i = 0; i < 60 && find.byType(GridBoard).evaluate().isEmpty; i++) {
            await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
            await tester.pump(const Duration(milliseconds: 50));
          }
          if (find.byType(GridBoard).evaluate().isEmpty) {
            fail('הלוח לא נטען');
            continue;
          }
          await wait(600);
          final boardBefore = tester.getRect(find.byType(GridBoard));

          await tester.tap(find.text('גלה מילה'));
          await wait(900);
          if (find.byType(SecretWordCard).evaluate().isEmpty) {
            fail('הכרטיס לא הופיע');
            continue;
          }
          final card = tester.getRect(find.byType(SecretWordCard));
          final board = tester.getRect(find.byType(GridBoard));
          final screen = Offset.zero & screenEntry.value;
          if (card.left < -0.5 || card.right > screen.right + 0.5 || card.top < 0) fail('הכרטיס יוצא מהמסך $card');
          if (card.bottom > board.top + 1) fail('הכרטיס מכסה את הלוח (card $card, board $board)');
          if (board.width < boardBefore.width * 0.75) fail('הלוח התכווץ מדי ${board.width} מ-${boardBefore.width}');

          final secret = tester.widget<SecretWordCard>(find.byType(SecretWordCard)).displayWord;
          final grid = tester.widget<GridBoard>(find.byType(GridBoard));
          final path = _pathFor(grid.letters, secret);
          if (path == null) {
            fail('המילה "$secret" לא נמצאת על הלוח');
            continue;
          }
          final cell = board.width / grid.letters.length;
          // הלוח לא מתהפך ב-RTL: עמודה 0 משמאל (כמו ב-game_tutorial_test).
          Offset at((int, int) p) => Offset(board.left + (p.$2 + 0.5) * cell, board.top + (p.$1 + 0.5) * cell);
          final gesture = await tester.startGesture(at(path.first));
          await wait(60);
          for (final p in path.skip(1)) {
            await gesture.moveTo(at(p));
            await wait(60);
          }
          await gesture.up();
          await wait(500);
          final found =
              find.byType(SecretWordCard).evaluate().isNotEmpty &&
              tester.widget<SecretWordCard>(find.byType(SecretWordCard)).found;
          if (!found || find.text('יופי! מצאת').evaluate().isEmpty) fail('"$secret" לא סומנה כנמצאה');
          await wait(2400);
          if (find.byType(SecretWordCard).evaluate().isNotEmpty) fail('הכרטיס לא נעלם אחרי שנמצאה');
          checked.add('$name → $secret');
          await tester.pumpWidget(const SizedBox());
          await wait(100);
        }
      }
    } finally {
      FlutterError.onError = onError;
    }
    // ignore: avoid_print
    print('נבדקו:\n${checked.join('\n')}');
    expect(failures, isEmpty);
    expect(errors, isEmpty);
    expect(checked, hasLength(levels.length * screens.length));
  });
}
