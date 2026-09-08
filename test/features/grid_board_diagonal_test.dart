import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wordbox_hebrew/features/game/widgets/grid_board.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';

void main() {
  testWidgets('diagonal drag selects only the diagonal tiles, never a wrong neighbor',
      (tester) async {
    List<GridPosition>? submittedPath;

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Center(
            child: SizedBox(
              width: 210,
              height: 210,
              child: GridBoard(
                letters: const [
                  ['א', 'ב', 'ג'],
                  ['ד', 'ה', 'ו'],
                  ['ז', 'ח', 'ט'],
                ],
                onPathSubmitted: (path) => submittedPath = path,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    const boardSize = 210.0;
    const cellSize = boardSize / 3;
    // GridBoard ממורכז על המסך (Center) - יש להמיר קואורדינטות מקומיות
    // (יחסיות ללוח) לקואורדינטות גלובליות (יחסיות למסך) לפני שליחת
    // אירועי מגע, אחרת startGesture/moveTo "יפספסו" את הלוח כליל.
    final boardTopLeft = tester.getTopLeft(find.byType(GridBoard));
    Offset centerOf(int row, int col) =>
        boardTopLeft + Offset(col * cellSize + cellSize / 2, row * cellSize + cellSize / 2);

    final start = centerOf(0, 0);
    final end = centerOf(2, 2);

    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));

    // מדגמים הרבה נקודות ביניים על הקו האלכסוני הישר - כדי לדמות גרירה
    // אלכסונית אמיתית ולוודא שאף נקודת ביניים לא "נתפסת" בטעות בתא שכן
    // אורתוגונלי (הבאג המקורי).
    const steps = 60;
    for (int i = 1; i <= steps; i++) {
      final t = i / steps;
      final point = Offset.lerp(start, end, t)!;
      await gesture.moveTo(point);
      await tester.pump(const Duration(milliseconds: 8));
    }

    await gesture.up();
    await tester.pump();

    expect(submittedPath, isNotNull);
    expect(
      submittedPath,
      equals(const [GridPosition(0, 0), GridPosition(1, 1), GridPosition(2, 2)]),
    );
  });
}
