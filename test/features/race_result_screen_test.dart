import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:wordbox_hebrew/features/multiplayer/models/race_result.dart';
import 'package:wordbox_hebrew/features/multiplayer/race_result_screen.dart';

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

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.text('🏆 ניצחת בתחרות!'), findsOneWidget);
    expect(find.text('את/ה (את/ה)'), findsOneWidget);
    expect(find.text('עומר'), findsOneWidget);
    expect(find.text('נועה'), findsOneWidget);
  });
}
