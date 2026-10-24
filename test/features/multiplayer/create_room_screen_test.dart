import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/create_room_screen.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/services/multiplayer_repository.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

class _Profile implements ProgressRepository {
  _Profile(this.stored);
  PlayerProfile stored;

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async => stored = profile;
}

/// מאגר מזויף שזוכר את ההגדרות שנשלחו ליצירת החדר.
class _FakeRooms implements MultiplayerRepository {
  Map<String, Object?>? created;

  @override
  Future<GameRoom> createRoom({
    required String hostDisplayName,
    required int gridSize,
    required int roundSeconds,
    required int targetScore,
    required int maxPlayers,
    required Duration joinWindow,
    int totalRounds = 1,
    int entryFee = 5,
    String? avatarId,
    String? photoUrl,
  }) async {
    created = {
      'name': hostDisplayName,
      'grid': gridSize,
      'seconds': roundSeconds,
      'target': targetScore,
      'rounds': totalRounds,
      'fee': entryFee,
      'join': joinWindow,
    };
    return GameRoom(
      roomCode: '12345',
      status: RoomStatus.waiting,
      players: const [],
      hostUid: 'me',
      entryFee: entryFee,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRooms rooms;
  late _Profile profile;
  String? navigatedTo;

  Future<void> pump(WidgetTester tester, {required Size size, int coins = 1000, double textScale = 1}) async {
    rooms = _FakeRooms();
    profile = _Profile(PlayerProfile(coins: coins, displayName: 'רוני', avatarId: 'ch_king'));
    navigatedTo = null;
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(path: '/create', builder: (_, _) => const CreateRoomScreen()),
        GoRoute(
          path: '/:rest(.*)',
          builder: (_, state) {
            navigatedTo = state.uri.toString();
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(profile),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          multiplayerRepositoryProvider.overrideWithValue(rooms),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Directionality(textDirection: TextDirection.rtl, child: child!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(402, 874), Size(375, 667)]) {
    testWidgets('מסך אחד בלי גלילה, בלי שדה כינוי (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      await pump(tester, size: size);
      expect(tester.takeException(), isNull);
      expect(find.byType(Scrollable), findsNothing);
      expect(find.byType(TextField), findsNothing, reason: 'אין שינוי כינוי במסך הזה');
      for (final fee in [50, 100, 200, 500]) {
        expect(find.text('$fee'), findsOneWidget);
      }
      expect(find.text('רוני'), findsOneWidget, reason: 'השם מהפרופיל');
      expect(find.text('יצירת חדר'), findsOneWidget);
    });
  }

  testWidgets('טקסט מוגדל במסך קטן - בלי גלישה', (tester) async {
    await pump(tester, size: const Size(375, 667), textScale: 1.25);
    expect(tester.takeException(), isNull);
  });

  testWidgets('בחירות עוברות לחדר, והכסף יורד', (tester) async {
    await pump(tester, size: const Size(402, 874));
    await tester.tap(find.text('200'));
    await tester.tap(find.text('6×6'));
    await tester.tap(find.text('2 דק׳'));
    await tester.tap(find.text('3'));
    await tester.tap(find.text('300'));
    await tester.tap(find.text('20 דק׳'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('יצירת חדר'));
    await tester.pumpAndSettle();
    expect(rooms.created, {
      'name': 'רוני',
      'grid': 6,
      'seconds': 120,
      'target': 300,
      'rounds': 3,
      'fee': 200,
      'join': const Duration(minutes: 20),
    });
    expect(profile.stored.coins, 800);
    expect(navigatedTo, '/multiplayer/online/room/12345');
  });

  testWidgets('בלי מספיק מטבעות: הכפתור מוביל לחנות ולא יוצר חדר', (tester) async {
    await pump(tester, size: const Size(402, 874), coins: 120);
    await tester.tap(find.text('200'));
    await tester.pumpAndSettle();
    expect(find.text('חסרים 80 מטבעות'), findsOneWidget);
    expect(find.text('יצירת חדר'), findsNothing);
    await tester.tap(find.text('חסרים 80 מטבעות'));
    await tester.pumpAndSettle();
    expect(rooms.created, isNull);
    expect(navigatedTo, startsWith('/store'));
  });
}
