import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/home/home_screen.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async => const PlayerProfile();

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

void main() {
  testWidgets('HomeScreen never overflows, even on short/wide viewports', (tester) async {
    // מדמה חלון דפדפן קצר ורחב (כמו שראינו בבדיקה חיה) - התוכן חייב
    // להיות גלילי במקרה הזה ולא לגרום ל-RenderFlex overflow.
    tester.view.physicalSize = const Size(1400, 500);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
        GoRoute(path: '/campaign', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/multiplayer', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/how-to-play', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/rules', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/settings', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/profile', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(
            textDirection: TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
    );

    // לא משתמשים ב-pumpAndSettle כי יש אנימציית מסקוט שחוזרת על עצמה
    // לנצח (repeat) - מספיק pump קבוע כדי שהבנייה הראשונית תסתיים.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    // אם היה RenderFlex overflow, הבדיקה הזו הייתה נכשלת עם exception.
    expect(tester.takeException(), isNull);
    expect(find.text('שחקו!'), findsOneWidget);
    expect(find.text('רב-משתתפים (2-4)'), findsOneWidget);
    expect(find.text('איך משחקים'), findsOneWidget);
    expect(find.text('חוקי המשחק'), findsOneWidget);
  });
}
