import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordbox_hebrew/core/audio/sound_service.dart';
import 'package:wordbox_hebrew/data/models/auth_user.dart';
import 'package:wordbox_hebrew/features/social/community_safety.dart';
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/sound_provider.dart';

Future<void> _open(WidgetTester tester, String uid) async {
  tester.view.physicalSize = const Size(1290, 2796);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      key: UniqueKey(),
      overrides: [
        authStateProvider.overrideWith((ref) => Stream.value(AuthUser(uid: uid, isAnonymous: true, provider: AuthProviderType.guest))),
        soundServiceProvider.overrideWithValue(SoundService.silent()),
      ],
      child: const MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: CommunityRulesGate(child: Scaffold(body: Text('חברים'))),
        ),
      ),
    ),
  );
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('כללי הקהילה מוצגים לכל חשבון חדש, גם באותו מכשיר', (tester) async {
    SharedPreferences.setMockInitialValues({});

    await _open(tester, 'a');
    expect(find.text('כללי הקהילה'), findsOneWidget);
    expect(find.text('חברים'), findsNothing, reason: 'המסך (ובחירת הכינוי שבו) נפתח רק אחרי ההסכמה');
    await tester.tap(find.text('מסכימ/ה'));
    for (int i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('חברים'), findsOneWidget);

    await _open(tester, 'a');
    expect(find.text('כללי הקהילה'), findsNothing, reason: 'אותו חשבון כבר הסכים');

    expect(find.text('חברים'), findsOneWidget);

    await _open(tester, 'b');
    expect(find.text('כללי הקהילה'), findsOneWidget, reason: 'חשבון חדש (למשל אחרי מחיקה) מתבקש שוב');
    expect(find.text('חברים'), findsNothing);
  });
}
