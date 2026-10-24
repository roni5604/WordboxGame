import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/auth_user.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/game/widgets/grid_board.dart';
import 'package:wordbox_hebrew/features/game/widgets/secret_word_card.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/online_race_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/widgets/race_words_panel.dart';
import 'package:wordbox_hebrew/game_engine/dictionary/hebrew_trie.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

import 'fake_multiplayer_repository.dart';

class _Profile implements ProgressRepository {
  PlayerProfile stored = const PlayerProfile(coins: 500, hints: 3, onboardingCompleted: true, authIntroShown: true);

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
  // הכל בבדיקה אחת: המילון והלוחות נטענים פעם אחת (ראו reveal_word_screen_test).
  testWidgets('משחק מול חברים: רמז, גלה מילה, והצצה (בתשלום) למילים של החבר/ה', (tester) async {
    addTearDown(tester.view.reset);
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(375, 667); // המסך הקטן ביותר
    final errors = <String>[];
    final onError = FlutterError.onError;
    FlutterError.onError = (details) {
      final text = details.exceptionAsString();
      // גופן הבדיקות רחב - גלישה זעירה בכותרת/בשעון לא קשורה לעזרים.
      if (text.contains('overflowed') &&
          !details.toString().contains('SecretWordCard') &&
          !details.toString().contains('_HelperRow')) {
        return;
      }
      if (text.contains('MissingPluginException') && text.contains('audioplayers')) return;
      errors.add(text);
    };

    final repo = FakeMultiplayerRepository()..myUid = 'me';
    final profile = _Profile();
    late ProviderContainer container;
    try {
      Future<void> wait(int ms) async {
        for (var w = 0; w < ms; w += 50) {
          await tester.pump(const Duration(milliseconds: 50));
        }
      }

      final router = GoRouter(
        initialLocation: '/race',
        routes: [
          GoRoute(
            path: '/race',
            builder: (_, _) => const OnlineRaceScreen(roomCode: 'ABCDE'),
          ),
          GoRoute(path: '/:rest(.*)', builder: (_, _) => const SizedBox()),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            multiplayerRepositoryProvider.overrideWithValue(repo),
            progressRepositoryProvider.overrideWithValue(profile),
            soundServiceProvider.overrideWithValue(SoundService.silent()),
            authStateProvider.overrideWith(
              (ref) => Stream.value(const AuthUser(uid: 'me', isAnonymous: false, provider: AuthProviderType.google)),
            ),
          ],
          child: Builder(
            builder: (context) {
              container = ProviderScope.containerOf(context);
              return MaterialApp.router(
                routerConfig: router,
                builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
              );
            },
          ),
        ),
      );
      await wait(200);
      final room = GameRoom(
        roomCode: 'ABCDE',
        status: RoomStatus.inProgress,
        hostUid: 'me',
        gridSize: 5,
        boardSeed: 42,
        roundSeconds: 600,
        targetScore: 0,
        maxPlayers: 6,
        entryFee: 50,
        startedAt: DateTime.now(),
        joinDeadline: DateTime.now().add(const Duration(minutes: 10)),
        players: const [
          PlayerInRoom(uid: 'me', displayName: 'רוני', isHost: true),
          PlayerInRoom(uid: 'friend', displayName: 'דנה', score: 7, wordsFound: 2, words: ['שלום', 'בית']),
        ],
      );
      repo.pushRoomUpdate(room);
      for (var i = 0; i < 60 && find.byType(GridBoard).evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(GridBoard), findsOneWidget, reason: 'הלוח לא נטען');
      await wait(600);
      int coins() => container.read(playerProfileProvider).value!.coins;
      int hints() => container.read(playerProfileProvider).value!.hints;
      expect(coins(), 500);

      // 💡 רמז: יורד רמז אחד ומוצגת מילה לנסות.
      expect(find.text('רמז'), findsOneWidget);
      await tester.tap(find.text('רמז'));
      await wait(400);
      expect(hints(), 2);
      expect(find.textContaining('נסו את המילה'), findsOneWidget);

      // 🔎 גלה מילה: 45 מטבעות, כרטיס מעל הלוח בלי לכסות אותו.
      final boardBefore = tester.getRect(find.byType(GridBoard));
      await tester.tap(find.text('גלה מילה'));
      await wait(900);
      expect(coins(), 455);
      expect(find.byType(SecretWordCard), findsOneWidget);
      final card = tester.getRect(find.byType(SecretWordCard));
      final board = tester.getRect(find.byType(GridBoard));
      expect(card.bottom, lessThanOrEqualTo(board.top + 1), reason: 'הכרטיס מכסה את הלוח');
      expect(card.right, lessThanOrEqualTo(375.5));
      expect(board.width, greaterThan(boardBefore.width * 0.7));

      // מוצאים את המילה הסודית - נשלחת לשרת עם רשימת המילים, והכרטיס נעלם.
      final secret = tester.widget<SecretWordCard>(find.byType(SecretWordCard)).displayWord;
      final grid = tester.widget<GridBoard>(find.byType(GridBoard));
      final path = _pathFor(grid.letters, secret);
      expect(path, isNotNull, reason: '"$secret" לא על הלוח');
      final cell = board.width / grid.letters.length;
      Offset at((int, int) p) => Offset(board.left + (p.$2 + 0.5) * cell, board.top + (p.$1 + 0.5) * cell);
      final gesture = await tester.startGesture(at(path!.first));
      await wait(60);
      for (final p in path.skip(1)) {
        await gesture.moveTo(at(p));
        await wait(60);
      }
      await gesture.up();
      await wait(500);
      expect(tester.widget<SecretWordCard>(find.byType(SecretWordCard)).found, isTrue);
      expect(repo.lastWords, contains(secret));
      await wait(2400);
      expect(find.byType(SecretWordCard), findsNothing);

      // הצצה: המילים של דנה נעולות; נגיעה ראשונה = "לאשר?", שנייה קונה ב-50.
      expect(find.text('שלום'), findsNothing);
      final friendTab = find.descendant(of: find.byType(RaceWordsPanel), matching: find.text('דנה'));
      await tester.tap(friendTab);
      await wait(300);
      expect(find.text('לאשר? 50'), findsOneWidget);
      expect(coins(), 455);
      await tester.tap(friendTab);
      await wait(600);
      expect(coins(), 405);
      expect(find.text('שלום'), findsOneWidget);
      expect(find.text('בית'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await wait(100);
    } finally {
      FlutterError.onError = onError;
    }
    expect(errors, isEmpty);
  });
}
