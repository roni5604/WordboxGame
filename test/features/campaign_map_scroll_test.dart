import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/home/campaign_map_screen.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

class _Progress implements ProgressRepository {
  final PlayerProfile profile;
  _Progress(this.profile);

  @override
  Future<PlayerProfile> loadProfile() async => profile;

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

void main() {
  Future<void> pumpMap(WidgetTester tester, int highestUnlocked) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/campaign',
      routes: [
        GoRoute(path: '/campaign', builder: (_, __) => const CampaignMapScreen()),
        GoRoute(path: '/:rest(.*)', builder: (_, __) => const SizedBox()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            _Progress(PlayerProfile(highestUnlockedLevel: highestUnlocked, onboardingCompleted: true)),
          ),
          soundServiceProvider.overrideWithValue(SoundService.silent()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('entering the map scrolls to the current level', (tester) async {
    await pumpMap(tester, 30);
    final node = find.text('30');
    expect(node, findsOneWidget);
    final y = tester.getCenter(node).dy;
    expect(y, inInclusiveRange(150, 844 - 120), reason: 'level 30 should be on screen after the auto-scroll');
    // הכפתור "לשלב שלי" לא מוצג כשהשלב כבר בתצוגה.
    expect(find.text('לשלב שלי'), findsNothing);
  });

  testWidgets('scrolling away shows "my level" and tapping it returns', (tester) async {
    await pumpMap(tester, 30);
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 3000));
    // מחכים שהגלילה (fling) תיעצר ושהכפתור יסיים להופיע.
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('לשלב שלי'), findsOneWidget);
    await tester.tap(find.text('לשלב שלי'));
    for (int i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final y = tester.getCenter(find.text('30')).dy;
    expect(y, inInclusiveRange(150, 844 - 120));
    await tester.pump(const Duration(seconds: 1));
  });
}
