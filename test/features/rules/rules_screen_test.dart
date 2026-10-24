import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:wordbox_hebrew/features/rules/rules_screen.dart';

void main() {
  Future<void> pumpRules(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size * 3;
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final router = GoRouter(
      initialLocation: '/rules',
      routes: [
        GoRoute(path: '/rules', builder: (_, _) => const RulesScreen()),
        GoRoute(path: '/home', builder: (_, _) => const SizedBox()),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(402, 874), Size(375, 667)]) {
    testWidgets('כל 10 החוקים בלי גלישה (${size.width.toInt()}×${size.height.toInt()})', (tester) async {
      await pumpRules(tester, size);
      for (var i = 1; i <= 10; i++) {
        expect(find.text('$i מתוך 10'), findsOneWidget);
        expect(tester.takeException(), isNull, reason: 'חוק $i');
        if (i < 10) {
          await tester.tap(find.text('הבא'));
          await tester.pumpAndSettle();
        }
      }
      expect(find.text('הבנתי, בואו נשחק!'), findsOneWidget);
    });
  }

  testWidgets('לוח הגרירה: "ילד" מתקבל', (tester) async {
    await pumpRules(tester, const Size(402, 874));
    Offset tile(String letter) => tester.getCenter(find.text(letter).first);
    final gesture = await tester.startGesture(tile('י'));
    await tester.pump();
    await gesture.moveTo(tile('ל'));
    await tester.pump();
    await gesture.moveTo(tile('ד'));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(find.textContaining('ילד ✓'), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
