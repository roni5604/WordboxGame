import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/game/widgets/letter_tile.dart';
import 'package:wordbox_hebrew/features/game/widgets/mascot_widget.dart';

void main() {
  testWidgets('LetterTile renders the given letter', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: LetterTile(letter: 'א', size: 64))),
      ),
    );

    // אריח idle מצייר את האות פעמיים בסגנון "מדבקה" (מתאר לבן + מילוי
    // אדום), בהשראת אייקון האפליקציה - לכן מצפים לשני widgets עם אותו טקסט.
    expect(find.text('א'), findsNWidgets(2));
  });

  testWidgets('MascotWidget renders without throwing (sad mood)', (tester) async {
    // הבעת "sad" אינה משתמשת באנימציית repeat אינסופית, ולכן בטוחה
    // לבדיקת widget רגילה ללא טיימרים תלויים בסיום הבדיקה.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: Center(child: MascotWidget(mood: MascotMood.sad))),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(MascotWidget), findsOneWidget);
  });
}
