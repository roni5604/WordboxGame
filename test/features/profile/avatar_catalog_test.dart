import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/profile/avatars/avatar_catalog.dart';
import 'package:wordbox_hebrew/features/profile/widgets/avatar_picker.dart';
import 'package:wordbox_hebrew/features/profile/widgets/avatar_widget.dart';

void main() {
  test('מזהים ייחודיים, קצרים (חוקי Firestore: עד 40 תווים), ועם שם', () {
    final ids = [for (final a in kPaintedAvatars) a.id, for (final o in kAvatarOptions) o.id];
    expect(ids.toSet().length, ids.length);
    for (final a in kPaintedAvatars) {
      expect(a.id.length, lessThanOrEqualTo(40));
      expect(a.label, isNotEmpty);
      expect(isKnownAvatarId(a.id), isTrue);
    }
  });

  test('הרבה דמויות בכל קטגוריה', () {
    expect(kPaintedAvatars.length, greaterThanOrEqualTo(70));
    for (final c in AvatarCategory.values.where((c) => c != AvatarCategory.classic)) {
      expect(kPaintedAvatars.where((a) => a.category == c).length, greaterThanOrEqualTo(10), reason: c.labelHe);
    }
  });

  test('לכל בוט דמות קיימת, ובוטים שונים מקבלים דמויות שונות', () {
    const bots = ['עומר', 'נועה', 'דנה', 'יובל', 'טל', 'מאיה', 'איתי', 'שירה'];
    final faces = bots.map(botAvatarId).toList();
    expect(faces.toSet().length, bots.length);
    for (final f in faces) {
      expect(paintedAvatarFor(f), isNotNull);
    }
    expect(paintedAvatarFor(botAvatarId('שם לא מוכר')), isNotNull);
  });

  testWidgets('כל הדמויות מצוירות בלי שגיאות', (tester) async {
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.rtl,
        child: Wrap(
          children: [
            for (final a in kPaintedAvatars) AvatarWidget(avatarId: a.id, size: 40),
          ],
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('הבורר: מעבר קטגוריה ובחירת דמות', (tester) async {
    String selected = 'detective';
    await tester.pumpWidget(
      MaterialApp(
        // טקסט מוגדל (נגישות) - כדי לתפוס גלישות שלא רואים בגופן הבדיקה הרגיל.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.4)),
          child: child!,
        ),
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => AvatarPicker(
                selectedId: selected,
                onSelected: (id) => setState(() => selected = id),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    for (final c in ['ילדים', 'דמויות', 'חיות']) {
      await tester.tap(find.text(c));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: c);
    }
    await tester.tap(find.text('כלבים'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('בוקסר'));
    await tester.pumpAndSettle();
    expect(selected, 'dog_boxer');
    expect(tester.takeException(), isNull);
  });
}
