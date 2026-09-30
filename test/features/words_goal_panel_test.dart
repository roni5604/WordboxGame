import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/game/widgets/words_goal_panel.dart';

void main() {
  Future<void> pump(WidgetTester tester, {required int score, required int required, required int stars}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WordsGoalPanel(score: score, required: required, stars: stars),
          ),
        ),
      ),
    );
  }

  int countFilledStars(WidgetTester tester) {
    final icons = tester.widgetList<Icon>(find.byIcon(Icons.star_rounded));
    expect(icons.length, 3, reason: 'הפאנל תמיד מציג בדיוק 3 סמלי כוכב (מלאים/ריקים)');
    return icons.where((icon) => icon.color != Colors.grey.shade300).length;
  }

  testWidgets('יעד=9: 6 נקודות שנשארו -> כוכב אחד', (tester) async {
    await pump(tester, score: 3, required: 9, stars: 1);
    expect(countFilledStars(tester), 1);
    expect(find.text('עוד 6 נקודות למטרה 🎯'), findsOneWidget);
  });

  testWidgets('נותרה נקודה אחת -> ניסוח ביחיד', (tester) async {
    await pump(tester, score: 8, required: 9, stars: 2);
    expect(countFilledStars(tester), 2);
    expect(find.text('עוד 1 נקודה למטרה 🎯'), findsOneWidget);
  });

  testWidgets('היעד הושג -> שלושה כוכבים', (tester) async {
    await pump(tester, score: 9, required: 9, stars: 3);
    expect(countFilledStars(tester), 3);
    expect(find.text('🎉 המטרה הושגה! השלב מסתיים...'), findsOneWidget);
  });

  testWidgets('לעולם לא מוצגים יותר משלושה כוכבים מלאים', (tester) async {
    await pump(tester, score: 20, required: 9, stars: 3);
    expect(countFilledStars(tester), 3);
  });
}
