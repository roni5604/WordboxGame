import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/join_room_screen.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

import 'fake_multiplayer_repository.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async => const PlayerProfile(displayName: 'עומר');

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

Future<void> _pumpJoinScreen(
  WidgetTester tester, {
  required FakeMultiplayerRepository fakeRepo,
}) async {
  final router = GoRouter(
    initialLocation: '/join',
    routes: [
      GoRoute(path: '/join', builder: (context, state) => const JoinRoomScreen()),
      GoRoute(
        path: '/multiplayer/online/room/:roomCode',
        builder: (context, state) => const SizedBox(),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
        multiplayerRepositoryProvider.overrideWithValue(fakeRepo),
      ],
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
}

void main() {
  // TextField עם פוקוס מריץ טיימר ריצוד סמן (cursor blink) פנימי -
  // "מפרקים" את עץ ה-widgets בסוף כל בדיקה כדי שה-dispose יבטל אותו,
  // אחרת flutter_test מתלונן על טיימר תלוי אחרי סיום הבדיקה.
  Future<void> disposeTree(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('JoinRoomScreen requires a 5-character code', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => disposeTree(tester));

    final fakeRepo = FakeMultiplayerRepository();
    await _pumpJoinScreen(tester, fakeRepo: fakeRepo);

    await tester.enterText(find.byType(TextField).last, 'AB');
    await tester.tap(find.text('הצטרפות לחדר 🚪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('קוד החדר מורכב מ-5 תווים.'), findsOneWidget);
    expect(fakeRepo.createRoomCalls, isEmpty);
  });

  testWidgets('JoinRoomScreen uppercases the code and joins successfully', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => disposeTree(tester));

    final fakeRepo = FakeMultiplayerRepository();
    await _pumpJoinScreen(tester, fakeRepo: fakeRepo);

    await tester.enterText(find.byType(TextField).last, 'abcde');
    await tester.tap(find.text('הצטרפות לחדר 🚪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(tester.takeException(), isNull);
  });

  testWidgets('JoinRoomScreen shows a friendly error when the room is missing', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    addTearDown(() => disposeTree(tester));

    final fakeRepo = FakeMultiplayerRepository()..joinRoomError = StateError('חדר עם הקוד ZZZZZ לא נמצא.');
    await _pumpJoinScreen(tester, fakeRepo: fakeRepo);

    await tester.enterText(find.byType(TextField).last, 'ZZZZZ');
    await tester.tap(find.text('הצטרפות לחדר 🚪'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(find.text('חדר עם הקוד ZZZZZ לא נמצא.'), findsOneWidget);
  });
}
