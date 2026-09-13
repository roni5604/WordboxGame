import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/room_lobby_screen.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';

import 'fake_multiplayer_repository.dart';

GameRoom _waitingRoom({required List<PlayerInRoom> players}) {
  return GameRoom(
    roomCode: 'ABCDE',
    status: RoomStatus.waiting,
    hostUid: 'host-uid',
    gridSize: 5,
    boardSeed: 42,
    roundSeconds: 90,
    targetScore: 0,
    maxPlayers: 6,
    joinDeadline: DateTime.now().add(const Duration(minutes: 10)),
    players: players,
  );
}

void main() {
  Future<GoRouter> pumpLobby(
    WidgetTester tester, {
    required FakeMultiplayerRepository fakeRepo,
    required String myUid,
  }) async {
    fakeRepo.myUid = myUid;
    final router = GoRouter(
      initialLocation: '/multiplayer/online/room/ABCDE',
      routes: [
        GoRoute(
          path: '/multiplayer/online/room/:roomCode',
          builder: (context, state) =>
              RoomLobbyScreen(roomCode: state.pathParameters['roomCode']!),
        ),
        GoRoute(
          path: '/multiplayer/online/race/:roomCode',
          builder: (context, state) => const SizedBox(),
        ),
        GoRoute(path: '/multiplayer', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [multiplayerRepositoryProvider.overrideWithValue(fakeRepo)],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pump();
    // מאפשר לאנימציות הכניסה (flutter_animate, כולל delay) להסתיים -
    // אחרת טיימר ה-delay הפנימי שלהן עדיין "תלוי" בסוף הבדיקה.
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  testWidgets('המנהל/ת רואה כפתור "התחל משחק" ומתחיל את המשחק', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // RoomLobbyScreen מריץ Timer.periodic (לספירת חלון ההצטרפות) - חייבים
    // לפרק את עץ ה-widgets בסוף הבדיקה כדי שה-dispose יבטל אותו, אחרת
    // flutter_test מתלונן על טיימר תלוי.
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpLobby(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    fakeRepo.pushRoomUpdate(_waitingRoom(players: [
      const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true),
      const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ABCDE'), findsOneWidget);
    expect(find.text('התחל משחק! 🚀'), findsOneWidget);

    await tester.tap(find.text('התחל משחק! 🚀'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fakeRepo.startGameCalls, contains('ABCDE'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('לא-מנהל/ת רואה הודעת המתנה, לא כפתור התחלה', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    await pumpLobby(tester, fakeRepo: fakeRepo, myUid: 'guest-uid');

    fakeRepo.pushRoomUpdate(_waitingRoom(players: [
      const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true),
      const PlayerInRoom(uid: 'guest-uid', displayName: 'עומר'),
    ]));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('ממתינים שמנהל/ת החדר ילחץ/תלחץ על "התחל משחק"...'), findsOneWidget);
    expect(find.text('התחל משחק! 🚀'), findsNothing);
  });

  testWidgets('כשסטטוס החדר עובר ל-inProgress, מנווטים אוטומטית למסך המשחק', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => tester.pumpWidget(const SizedBox()));

    final fakeRepo = FakeMultiplayerRepository();
    final router = await pumpLobby(tester, fakeRepo: fakeRepo, myUid: 'host-uid');

    final waitingRoom = _waitingRoom(players: [
      const PlayerInRoom(uid: 'host-uid', displayName: 'מנהל', isHost: true),
    ]);
    fakeRepo.pushRoomUpdate(waitingRoom);
    await tester.pump();

    fakeRepo.pushRoomUpdate(GameRoom(
      roomCode: 'ABCDE',
      status: RoomStatus.inProgress,
      hostUid: 'host-uid',
      gridSize: 5,
      boardSeed: 42,
      roundSeconds: 90,
      targetScore: 0,
      maxPlayers: 6,
      startedAt: DateTime.now(),
      players: waitingRoom.players,
    ));
    await tester.pump();
    await tester.pump();
    // מאפשר לטיימרי ה-delay של flutter_animate (שהתחילו לפני הניווט) לרוץ
    // עד הסוף, כדי שלא יישארו "תלויים" כשעץ ה-widgets מתפרק בסוף הבדיקה.
    await tester.pump(const Duration(milliseconds: 500));

    expect(
      router.routerDelegate.currentConfiguration.uri.toString(),
      '/multiplayer/online/race/ABCDE',
    );
  });
}
