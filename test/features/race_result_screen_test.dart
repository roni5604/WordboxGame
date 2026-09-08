import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/race_result.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_result_screen.dart';
import 'package:wordbox_hebrew/providers/repository_providers.dart';

class _FakeProgressRepository implements ProgressRepository {
  @override
  Future<PlayerProfile> loadProfile() async => const PlayerProfile();

  @override
  Future<void> saveProfile(PlayerProfile profile) async {}
}

void main() {
  testWidgets('RaceResultScreen renders ranking without overflow, human wins', (tester) async {
    tester.view.physicalSize = const Size(400, 700);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const result = RaceResult(rankedParticipants: [
      RaceParticipantResult(name: 'את/ה', score: 42, wordsFound: 6, isHuman: true),
      RaceParticipantResult(name: 'עומר', score: 30, wordsFound: 4, isHuman: false),
      RaceParticipantResult(name: 'נועה', score: 18, wordsFound: 3, isHuman: false),
    ]);

    final router = GoRouter(
      initialLocation: '/result',
      routes: [
        GoRoute(path: '/result', builder: (context, state) => const RaceResultScreen(result: result)),
        GoRoute(path: '/home', builder: (context, state) => const SizedBox()),
        GoRoute(path: '/multiplayer/setup', builder: (context, state) => const SizedBox()),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          progressRepositoryProvider.overrideWithValue(_FakeProgressRepository()),
        ],
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('🏆 ניצחת בתחרות!'), findsOneWidget);
    expect(find.text('את/ה (את/ה)'), findsOneWidget);
    expect(find.text('עומר'), findsOneWidget);
    expect(find.text('נועה'), findsOneWidget);
  });
}
