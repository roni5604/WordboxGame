import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/create_room_screen.dart';
import 'package:wordbox_hebrew/providers/multiplayer_repository_provider.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

import 'fake_multiplayer_repository.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async => const PlayerProfile(displayName: 'דנה');

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

/// מזרים ל-CreateRoomScreen פרופיל *כבר טעון* מהרגע הראשון - במשחק בפועל זה
/// המצב האמיתי (splash_screen מריץ ensureLoaded() לפני שמנווטים לכל מסך
/// אחר), אבל בבדיקת widget ממוקדת אנחנו מדלגים על מסך הפתיחה ובונים ישר
/// את CreateRoomScreen, אז חייבים למלא את ה-state הזה מראש.
class _ImmediateProfileNotifier extends PlayerProfileNotifier {
  _ImmediateProfileNotifier(super.repository, PlayerProfile profile) {
    state = AsyncValue.data(profile);
  }
}

void main() {
  testWidgets('CreateRoomScreen renders all settings and creates a room on submit', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeRepo = FakeMultiplayerRepository();
    String? navigatedRoomCode;

    final router = GoRouter(
      initialLocation: '/multiplayer/online/create',
      routes: [
        GoRoute(
          path: '/multiplayer/online/create',
          builder: (context, state) => const CreateRoomScreen(),
        ),
        GoRoute(
          path: '/multiplayer/online/room/:roomCode',
          builder: (context, state) {
            navigatedRoomCode = state.pathParameters['roomCode'];
            return const SizedBox();
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
          playerProfileProvider.overrideWith(
            (ref) => _ImmediateProfileNotifier(
              _FakeProgressRepository(),
              const PlayerProfile(displayName: 'דנה'),
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
    // מאפשר לאנימציות הכניסה (flutter_animate, כולל delay) להסתיים -
    // אחרת טיימר ה-delay הפנימי שלהן עדיין "תלוי" בסוף הבדיקה.
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('גודל לוח'), findsOneWidget);
    expect(find.text('כמה זמן לכל תור (סבב)?'), findsOneWidget);
    expect(find.text('עד כמה נקודות המשחק? (ניקוד יעד לניצחון מוקדם)'), findsOneWidget);

    // בחירת גודל לוח 6×6, ואז יצירת החדר (גוללים כדי לחשוף את הכפתור,
    // כי ה-ListView לא בונה תוכן מעבר לגובה המסך הנראה).
    await tester.tap(find.text('6×6'));
    await tester.pump();

    // מזהים את ה-Scrollable האנכי (של ה-ListView הראשי) ולא את זה האופקי
    // הפנימי של שדה הטקסט, כדי ש-scrollUntilVisible יגלול את הרשימה הנכונה
    // גם לפני שהכפתור (מתחת לקצה הנראה) נבנה בפועל.
    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final createButton = find.text('יצירת חדר 🔑');
    await tester.scrollUntilVisible(createButton, 300, scrollable: verticalScrollable);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(fakeRepo.createRoomCalls, hasLength(1));
    expect(fakeRepo.createRoomCalls.single.gridSize, 6);
    expect(fakeRepo.createRoomCalls.single.hostDisplayName, 'דנה');
    expect(navigatedRoomCode, fakeRepo.lastCreatedRoom?.roomCode);
    expect(tester.takeException(), isNull);
  });

  testWidgets('CreateRoomScreen shows an error when the name is empty', (tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final fakeRepo = FakeMultiplayerRepository();

    final router = GoRouter(
      initialLocation: '/create',
      routes: [
        GoRoute(path: '/create', builder: (context, state) => const CreateRoomScreen()),
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
    await tester.pump(const Duration(milliseconds: 500));

    await tester.enterText(find.byType(TextField).first, '');
    final verticalScrollable = find.byWidgetPredicate(
      (widget) => widget is Scrollable && widget.axisDirection == AxisDirection.down,
    );
    final createButton = find.text('יצירת חדר 🔑');
    await tester.scrollUntilVisible(createButton, 300, scrollable: verticalScrollable);
    await tester.tap(createButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('אנא הזינו שם/כינוי.'), findsOneWidget);
    expect(fakeRepo.createRoomCalls, isEmpty);
  });
}
