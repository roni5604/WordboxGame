import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/platform/top_bar_tint.dart';

void main() {
  testWidgets('the top strip dims while a dialog is open and restores after', (tester) async {
    const screen = Color(0xFF38BDF8);
    final observer = TopTintObserver();
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [observer],
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => showDialog<void>(context: context, builder: (_) => const Text('dialog')),
            child: const Text('open'),
          ),
        ),
      ),
    );
    TopTint.setScreenColor(screen);
    expect(TopTint.effectiveColor, screen);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dimmed = TopTint.effectiveColor!;
    expect(dimmed, Color.alphaBlend(Colors.black54, screen));
    expect(dimmed.computeLuminance(), lessThan(screen.computeLuminance()));

    Navigator.of(tester.element(find.text('dialog'))).pop();
    await tester.pumpAndSettle();
    expect(TopTint.effectiveColor, screen);
  });
}
