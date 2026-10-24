import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/multiplayer/widgets/race_words_panel.dart';

void main() {
  Widget panel({required bool unlocked, required VoidCallback onUnlock}) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: RaceWordsPanel(
              mine: const RaceWordList(name: 'אני', avatarId: 'detective', words: ['בית'], isMe: true),
              opponents: const [RaceWordList(name: 'עומר', avatarId: 'kid_b4', words: ['שמש', 'ילד'])],
              unlocked: unlocked,
              onUnlock: onUnlock,
            ),
          ),
        ),
      );

  testWidgets('נעול: לשונית היריב מבקשת הצצה ולא מראה מילים', (tester) async {
    var asked = 0;
    await tester.pumpWidget(panel(unlocked: false, onUnlock: () => asked++));
    expect(find.text('$kSpyCost'), findsOneWidget);
    await tester.tap(find.text('עומר'));
    await tester.pumpAndSettle();
    expect(asked, 1);
    expect(find.text('שמש'), findsNothing);
    expect(find.text('בית'), findsOneWidget);
  });

  testWidgets('אחרי הצצה: רואים את המילים של היריב', (tester) async {
    await tester.pumpWidget(panel(unlocked: false, onUnlock: () {}));
    await tester.pumpWidget(panel(unlocked: true, onUnlock: () {}));
    await tester.pumpAndSettle();
    expect(find.text('שמש'), findsOneWidget);
    expect(find.text('ילד'), findsOneWidget);
  });
}
