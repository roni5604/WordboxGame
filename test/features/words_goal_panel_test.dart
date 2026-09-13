import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/game/widgets/words_goal_panel.dart';

/// בדיקת רינדור מדויקת ל-WordsGoalPanel (לא בדיקה ויזואלית/צילום-מסך) -
/// מוודאת שמספר הכוכבים המלאים המוצג בפועל תואם בדיוק לפרמטר [stars],
/// ושהטקסט "כמה מילים נשארו" נכון. חשוב במיוחד כי בדיקות ידניות בדפדפן
/// (עם טקסט RTL בעברית) נוטות "לקרוא" את המסך הפוך ולא מדויק.
void main() {
  Future<void> pump(WidgetTester tester, {required int found, required int required, required int stars}) {
    return tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: WordsGoalPanel(found: found, required: required, stars: stars),
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

  testWidgets('שלב 1 (יעד=3): מילה אחת נמצאה -> כוכב אחד מלא בדיוק, לא 2 או 4', (tester) async {
    await pump(tester, found: 1, required: 3, stars: 1);
    expect(countFilledStars(tester), 1);
    expect(find.text('עוד 2 מילים למטרה 🎯'), findsOneWidget);
  });

  testWidgets('שלב 1 (יעד=3): שתי מילים נמצאו -> שני כוכבים מלאים בדיוק, לא 4', (tester) async {
    await pump(tester, found: 2, required: 3, stars: 2);
    expect(countFilledStars(tester), 2);
    expect(find.text('עוד 1 מילה למטרה 🎯'), findsOneWidget);
  });

  testWidgets('שלב 1 (יעד=3): כל שלוש המילים נמצאו -> שלושה כוכבים מלאים ("הושגה")', (tester) async {
    await pump(tester, found: 3, required: 3, stars: 3);
    expect(countFilledStars(tester), 3);
    expect(find.text('🎉 המטרה הושגה! השלב מסתיים...'), findsOneWidget);
  });

  testWidgets('לעולם לא מוצגים יותר משלושה כוכבים מלאים, גם עם ערך stars גבוה יתר על המידה', (tester) async {
    await pump(tester, found: 10, required: 3, stars: 3);
    expect(countFilledStars(tester), 3);
  });
}
