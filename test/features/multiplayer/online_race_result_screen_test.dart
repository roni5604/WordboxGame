import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/race_result.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/online_race_result_screen.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

import 'fake_multiplayer_repository.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async =>
      const PlayerProfile(displayName: 'דנה', coins: 40);

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

/// כמו ב-create_room_screen_test.dart - מזרים פרופיל *כבר טעון* כדי
/// שה-soundServiceProvider (שנקרא ב-initState של המסך, ראו RaceResultScreen
/// המקורי) לא ינסה לגעת ב-Firebase האמיתי בבדיקה.
class _ImmediateProfileNotifier extends PlayerProfileNotifier {
  _ImmediateProfileNotifier(super.repository, PlayerProfile profile) {
    state = AsyncValue.data(profile);
  }
}

GameRoom _finishedRoom({
  required List<PlayerInRoom> players,
  Map<String, int> wins = const {},
  int totalRounds = 1,
  int currentRound = 1,
  int pot = 10,
  int entryFee = 5,
}) {
  return GameRoom(
    roomCode: '12345',
    status: RoomStatus.finished,
    hostUid: 'host-uid',
    gridSize: 5,
    boardSeed: 42,
    roundSeconds: 90,
    targetScore: 0,
    maxPlayers: 8,
    totalRounds: totalRounds,
    currentRound: currentRound,
    entryFee: entryFee,
    pot: pot,
    potAwarded: currentRound >= totalRounds,
    players: players,
    wins: wins,
  );
}

const _defaultResult = RaceResult(
  rankedParticipants: [
    RaceParticipantResult(name: 'מנהל', score: 40, wordsFound: 6, isHuman: true),
    RaceParticipantResult(name: 'עומר', score: 30, wordsFound: 5, isHuman: false),
  ],
);

void main() {
  Future<GoRouter> pumpResultScreen(
    WidgetTester tester, {
    required FakeMultiplayerRepository fakeRepo,
    required String myUid,
    RaceResult result = _defaultResult,
  }) async {
    fakeRepo.myUid = myUid;
    final router = GoRouter(
      initialLocation: '/multiplayer/online/room/12345/result',
      routes: [
        GoRoute(
          path: '/multiplayer/online/room/:roomCode/result',
          builder: (context, state) =>
              OnlineRaceResultScreen(roomCode: state.pathParameters['roomCode']!, result: result),
        ),
        GoRoute(
          path: '/multiplayer/online/room/:roomCode',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(
          path: '/multiplayer/online/race/:roomCode',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
          playerProfileProvider.overrideWith(
            (ref) => _ImmediateProfileNotifier(
              _FakeProgressRepository(),
              const PlayerProfile(displayName: 'דנה', coins: 40),
            ),
          ),
          multiplayerRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pump();
    // מאפשר לאנימציות הכניסה (flutter_animate, כולל confetti/delay) להסתיים.
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  testWidgets('סיום משחקון יחיד מציג יציאה בלי משחק חוזר', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    fakeRepo.pushRoomUpdate(_finishedRoom(players: [
      const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
      const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('משחק חוזר 🔁'), findsNothing);
    expect(find.text('יציאה לתפריט הראשי'), findsOneWidget);
    expect(find.textContaining('מטבעות'), findsWidgets);
  });

  testWidgets('סבב ביניים מציג "הסבב הבא" למנהל/ת', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    fakeRepo.pushRoomUpdate(_finishedRoom(
      totalRounds: 3,
      currentRound: 1,
      players: [
        const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
        const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('הסבב הבא 🚀'), findsOneWidget);
    expect(find.text('טבלת האלופים'), findsNothing);

    await tester.tap(find.text('הסבב הבא 🚀'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fakeRepo.startNextRoundCalls, contains('12345'));
  });

  testWidgets('אורח/ת בסבב ביניים ממתין/ה לסבב הבא', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'guest-uid');

    fakeRepo.pushRoomUpdate(_finishedRoom(
      totalRounds: 3,
      currentRound: 1,
      players: [
        const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
        const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ממתינים לסבב הבא...'), findsOneWidget);
    expect(find.text('הסבב הבא 🚀'), findsNothing);
  });

  testWidgets('מציג יחס ניצחונות X : Y כשקיים מונה wins בחדר', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    fakeRepo.pushRoomUpdate(_finishedRoom(
      players: [
        const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
        const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
      ],
      wins: {'host-uid': 1, 'guest-uid': 2},
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('1 : 2'), findsOneWidget);
  });

  testWidgets('סיום סדרה מציג טבלת אלופים בלי הסבב הבא', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    fakeRepo.pushRoomUpdate(_finishedRoom(
      totalRounds: 3,
      currentRound: 3,
      wins: {'host-uid': 2, 'guest-uid': 1},
      players: [
        const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
        const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
      ],
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('טבלת האלופים'), findsOneWidget);
    expect(find.text('הסבב הבא 🚀'), findsNothing);
    expect(find.textContaining('ניצחונות'), findsWidgets);
  });

  testWidgets('כשה"משחק חוזר" מופעל (סטטוס waiting), מנווטים אוטומטית ללובי', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    final router = await pumpResultScreen(tester, fakeRepo: fakeRepo, myUid: 'guest-uid');

    final finishedRoom = _finishedRoom(players: [
      const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true, score: 40, wordsFound: 6),
      const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר', score: 30, wordsFound: 5),
    ]);
    fakeRepo.pushRoomUpdate(finishedRoom);
    await tester.pump();

    fakeRepo.pushRoomUpdate(GameRoom(
      roomCode: '12345',
      status: RoomStatus.waiting,
      hostUid: 'host-uid',
      gridSize: 5,
      boardSeed: 99,
      roundSeconds: 90,
      targetScore: 0,
      maxPlayers: 8,
      players: finishedRoom.players,
    ));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/multiplayer/online/room/12345',
    );
  });
}
