import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/game/widgets/secret_word_card.dart';

void main() {
  for (final word in ['ים', 'שולחן', 'מתעניינים', 'התכתבויותיהם']) {
    testWidgets('מילה של ${word.length} אותיות נכנסת לרוחב של iPhone SE', (tester) async {
      tester.view.physicalSize = const Size(375, 200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final found in [false, true]) {
        await tester.pumpWidget(
          Directionality(
            textDirection: TextDirection.rtl,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SecretWordCard(displayWord: word, found: found),
              ),
            ),
          ),
        );
        await tester.pump(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byType(SecretWordCard));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(375));
      }
    });
  }
}
