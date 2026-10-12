import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/features/rewards/reward_reveal.dart';
import 'package:wordbox_hebrew/game_engine/rewards/rarity.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

void main() {
  Future<void> openHost(WidgetTester tester, RewardContents contents) async {
    tester.view.physicalSize = const Size(1179, 2556);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [soundServiceProvider.overrideWithValue(SoundService.silent())],
      child: MaterialApp(
        home: Builder(
          builder: (context) => Center(
            child: TextButton(onPressed: () => RewardReveal.show(context, contents), child: const Text('open')),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump(const Duration(milliseconds: 700));
  }

  Future<void> tapStage(WidgetTester tester) async {
    await tester.tapAt(const Offset(196, 420));
    await tester.pump(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 150));
  }

  testWidgets('tapping charges, upgrades, opens and collects', (tester) async {
    await openHost(tester, const RewardContents(rarity: Rarity.epic, coins: 120, hints: 2, title: 'תיבת מזל'));
    expect(find.text('הקישו כדי לפתוח!'), findsOneWidget);
    expect(find.text('אספו!'), findsNothing);

    // לכל היותר 4 לחיצות טעינה + פתיחה.
    for (var i = 0; i < 5 && find.text('אספו!').evaluate().isEmpty; i++) {
      await tapStage(tester);
    }
    expect(find.text('אספו!'), findsOneWidget);
    expect(find.text('אפי!'), findsWidgets);

    // הכפתור נדלק רק אחרי שהחגיגה נחתה.
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.text('+120'), findsOneWidget);
    await tester.tap(find.text('אספו!'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(find.byType(RewardReveal), findsNothing);
    // מחכים שכל הזיקוקים/טיימרים יסתיימו.
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('very fast taps are swallowed so each tap lands', (tester) async {
    await openHost(tester, const RewardContents(rarity: Rarity.legendary, coins: 300, title: 'תיבת מזל'));
    for (var i = 0; i < 6; i++) {
      await tester.tapAt(const Offset(196, 420));
      await tester.pump(const Duration(milliseconds: 40));
    }
    // 6 לחיצות ב-240ms = לכל היותר 2 נקלטו, אז עדיין לא נפתח.
    expect(find.text('אספו!'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
  });

}
