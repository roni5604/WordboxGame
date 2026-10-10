import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:wordbox_hebrew/features/game/widgets/grid_board.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';

/// לוח 7×7 בגודל טלפון (תא ~48px): ההחלקה חייבת להתחיל באות שנלחצה
/// בפועל, גם אם האצבע זזה מיד באלכסון - ולא בנקודה שבה Flutter "זיהה"
/// גרירה (אחרי ~36px), שנמצאת כבר על הפינה בין התאים.
void main() {
  const size = 7;
  const boardSize = 336.0;
  const cell = boardSize / size;

  Future<(List<GridPosition>?, Offset Function(int, int))> pumpBoard(
    WidgetTester tester,
    void Function(List<GridPosition>) onSubmit, {
    bool competingAncestor = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: GestureDetector(
            // מדמה מסך מכיל עם מחוות משלו (טאפ + גלילה), שמכריח את Flutter
            // לחכות לסף-גרירה לפני שהוא מכריע מי "זוכה" במגע.
            onTap: competingAncestor ? () {} : null,
            onVerticalDragUpdate: competingAncestor ? (_) {} : null,
            child: Center(
              child: SizedBox(
                width: boardSize,
                height: boardSize,
                child: GridBoard(
                  letters: List.generate(
                    size,
                    (r) => List.generate(size, (c) => 'אבגדהוזחטיכלמנסעפצקרשת'[(r * size + c) % 22]),
                  ),
                  onPathSubmitted: onSubmit,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    final topLeft = tester.getTopLeft(find.byType(GridBoard));
    return (null, (int r, int c) => topLeft + Offset(c * cell + cell / 2, r * cell + cell / 2));
  }

  for (final (name, from, to) in [
    ('down-left diagonal', const GridPosition(1, 1), const GridPosition(3, 3)),
    ('up-right diagonal', const GridPosition(4, 4), const GridPosition(2, 2)),
    ('anti-diagonal', const GridPosition(2, 4), const GridPosition(4, 2)),
  ]) {
    for (final competing in [false, true]) {
      testWidgets('7x7 $name starts on the touched letter${competing ? ' (competing ancestor gesture)' : ''}', (
        tester,
      ) async {
        List<GridPosition>? submitted;
        final (_, centerOf) = await pumpBoard(tester, (p) => submitted = p, competingAncestor: competing);
        final start = centerOf(from.row, from.col);
        final end = centerOf(to.row, to.col);
        final gesture = await tester.startGesture(start);
        await tester.pump(const Duration(milliseconds: 16));
        for (int i = 1; i <= 30; i++) {
          await gesture.moveTo(Offset.lerp(start, end, i / 30)!);
          await tester.pump(const Duration(milliseconds: 8));
        }
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 300));
        final dr = (to.row - from.row).sign;
        final dc = (to.col - from.col).sign;
        expect(submitted, [from, GridPosition(from.row + dr, from.col + dc), to]);
      });
    }
  }

  testWidgets('a single tap shows the letter as selected immediately', (tester) async {
    final (_, centerOf) = await pumpBoard(tester, (_) {});
    final gesture = await tester.startGesture(centerOf(3, 3));
    await tester.pump(const Duration(milliseconds: 50));
    final state = tester.state<GridBoardState>(find.byType(GridBoard));
    expect(state.debugCurrentPath, [const GridPosition(3, 3)]);
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 300));
  });

  testWidgets('a second finger touching mid-swipe is ignored', (tester) async {
    List<GridPosition>? submitted;
    final (_, centerOf) = await pumpBoard(tester, (p) => submitted = p);
    final start = centerOf(1, 1);
    final end = centerOf(3, 3);
    final finger = await tester.startGesture(start, pointer: 1);
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 1; i <= 15; i++) {
      await finger.moveTo(Offset.lerp(start, end, i / 30)!);
      await tester.pump(const Duration(milliseconds: 8));
    }
    // כף יד / אגודל נוגעים בפינה הרחוקה של הלוח ונעים.
    final palm = await tester.startGesture(centerOf(6, 0), pointer: 2);
    await palm.moveTo(centerOf(5, 0));
    await tester.pump(const Duration(milliseconds: 16));
    for (int i = 16; i <= 30; i++) {
      await finger.moveTo(Offset.lerp(start, end, i / 30)!);
      await tester.pump(const Duration(milliseconds: 8));
    }
    await palm.up();
    await tester.pump(const Duration(milliseconds: 16));
    expect(submitted, isNull, reason: 'lifting the palm must not submit the word');
    await finger.up();
    await tester.pump(const Duration(milliseconds: 300));
    expect(submitted, const [GridPosition(1, 1), GridPosition(2, 2), GridPosition(3, 3)]);
  });
}
