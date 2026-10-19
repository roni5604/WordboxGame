// בדיקת קצה-לקצה על סימולטור iPhone: מריצה את האפליקציה האמיתית (כולל
// Firebase אמיתי) ועוברת על המסלולים העיקריים. כל שלב נרשם כ-
// RESULT|מספר|PASS/FAIL|פירוט, ונלקח צילום מסך.
//
// הרצה (עם סימולטור פתוח):
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/app_flow_test.dart -d <simulator>
import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wordbox_hebrew/core/router/app_router.dart';
import 'package:wordbox_hebrew/features/game/widgets/fortune_wheel_dialog.dart';
import 'package:wordbox_hebrew/features/rewards/reward_reveal.dart';
import 'package:wordbox_hebrew/game_engine/word_finder.dart';
import 'package:wordbox_hebrew/main.dart' as app;
import 'package:wordbox_hebrew/providers/auth_provider.dart';
import 'package:wordbox_hebrew/providers/dictionary_provider.dart';
import 'package:wordbox_hebrew/providers/level_boards_provider.dart';

final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

void result(String id, bool ok, [String detail = '']) {
  // ignore: avoid_print
  print('RESULT|$id|${ok ? 'PASS' : 'FAIL'}|$detail');
}

Future<void> wait(WidgetTester t, [int ms = 500]) async {
  final end = DateTime.now().add(Duration(milliseconds: ms));
  while (DateTime.now().isBefore(end)) {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    await t.pump();
  }
}

Future<bool> waitFor(WidgetTester t, Finder f, {int seconds = 30}) async {
  final end = DateTime.now().add(Duration(seconds: seconds));
  while (DateTime.now().isBefore(end)) {
    await t.pump();
    if (f.evaluate().isNotEmpty) return true;
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  return f.evaluate().isNotEmpty;
}

Future<bool> tapText(WidgetTester t, String text, {int seconds = 20}) async {
  final f = find.text(text);
  if (!await waitFor(t, f, seconds: seconds)) return false;
  await t.ensureVisible(f.first);
  await t.pump();
  await t.tap(f.first, warnIfMissed: false);
  await wait(t, 400);
  return true;
}

Future<void> shot(WidgetTester t, String name) async {
  try {
    await t.pump();
    await binding.takeScreenshot(name);
  } catch (e) {
    // ignore: avoid_print
    print('screenshot $name failed: $e');
  }
}

Future<void> go(WidgetTester t, String route) async {
  appRouter.go(route);
  await wait(t, 1500);
}

/// גרירה דרך מרכזי האריחים, בצעדים קטנים - כמו אצבע אמיתית.
Future<void> swipe(WidgetTester t, List<Offset> points) async {
  final g = await t.startGesture(points.first);
  await t.pump(const Duration(milliseconds: 30));
  for (var i = 1; i < points.length; i++) {
    final a = points[i - 1], b = points[i];
    for (var s = 1; s <= 8; s++) {
      await g.moveTo(Offset.lerp(a, b, s / 8)!);
      await t.pump(const Duration(milliseconds: 16));
    }
  }
  await g.up();
  await wait(t, 350);
}

/// סוגר גלגל מזל / קופסת הפתעה אם הופיעו (מסך התוצאות).
Future<int> dismissRewards(WidgetTester t) async {
  var handled = 0;
  final end = DateTime.now().add(const Duration(seconds: 60));
  while (DateTime.now().isBefore(end)) {
    await wait(t, 600);
    if (find.text('סובבו!').evaluate().isNotEmpty) {
      await t.tap(find.text('סובבו!').first, warnIfMissed: false);
      handled++;
      await wait(t, 7000);
      continue;
    }
    if (find.text('אספו!').evaluate().isNotEmpty) {
      await t.tap(find.text('אספו!').first, warnIfMissed: false);
      handled++;
      await wait(t, 1500);
      continue;
    }
    final wheel = find.byType(FortuneWheelDialog).evaluate().isNotEmpty;
    final reveal = find.byType(RewardReveal).evaluate().isNotEmpty;
    if (reveal || wheel) {
      final size = t.view.physicalSize / t.view.devicePixelRatio;
      await t.tapAt(Offset(size.width / 2, size.height / 2));
      await wait(t, 900);
      continue;
    }
    if (find.text('שתפו את ההישג').evaluate().isNotEmpty) break;
  }
  return handled;
}

void main() {
  testWidgets('מצא ת׳מילה - מסלולים עיקריים', (t) async {
    final errors = <String>[];
    final originalOnError = FlutterError.onError;

    await app.main();
    FlutterError.onError = (d) {
      final msg = d.exceptionAsString().split('\n').first;
      errors.add(msg);
      // ignore: avoid_print
      print('FLUTTER_ERROR|$msg');
    };

    try {
      // 3. פתיחה ראשונה: מסך התחברות עם Apple
      final authShown = await waitFor(t, find.text('המשך כאורח/ת בלי להתחבר'), seconds: 60);
      await shot(t, '03_first_launch_auth');
      final apple = find.textContaining('Apple').evaluate().isNotEmpty;
      result('3', authShown && apple, 'auth screen: $authShown, Apple button: $apple');

      // 4. כניסה כאורח
      await tapText(t, 'המשך כאורח/ת בלי להתחבר');
      await wait(t, 3000);
      final u = FirebaseAuth.instance.currentUser;
      result('4', u != null && u.isAnonymous, 'firebase uid=${u?.uid} anonymous=${u?.isAnonymous}');

      // 5. הדרכה -> דלג -> בית
      final onboarding = await waitFor(t, find.text('דלג'), seconds: 20);
      await shot(t, '05_onboarding');
      if (onboarding) await tapText(t, 'דלג');
      final home = await waitFor(t, find.text('שחקו!'), seconds: 20);
      await wait(t, 2000);
      await shot(t, '05_home');
      result('5', onboarding && home, 'onboarding: $onboarding, home: $home');

      // 6. שלב 1 עם הדרכה
      await tapText(t, 'שחקו!');
      await wait(t, 1500);
      if (find.byKey(const ValueKey('tile-0-0')).evaluate().isEmpty && find.text('שחקו!').evaluate().isNotEmpty) {
        await shot(t, '06_level_intro');
        await tapText(t, 'שחקו!');
      }
      final board = await waitFor(t, find.byKey(const ValueKey('tile-0-0')), seconds: 30);
      await wait(t, 1500);
      final tutorial = find.text('הבנתי, בואו נתחיל!').evaluate().isNotEmpty;
      await shot(t, '06_level1_tutorial');
      result('6', board && tutorial, 'board: $board, tutorial overlay: $tutorial');
      if (tutorial) await tapText(t, 'הבנתי, בואו נתחיל!');

      // 8. מציאת מילים אמיתיות והשלמת השלב
      var found = 0;
      var finished = false;
      try {
        final container = ProviderScope.containerOf(t.element(find.byKey(const ValueKey('tile-0-0'))));
        final dict = await container.read(dictionaryLoadProvider.future);
        final boards = await container.read(levelBoardsProvider.future);
        final words = WordFinder(dict.trie).findAllWords(boards[1]!.letters)
          ..sort((a, b) => b.path.length.compareTo(a.path.length));
        for (final w in words) {
          if (w.path.length < 2) continue;
          final pts = [
            for (final p in w.path) t.getCenter(find.byKey(ValueKey('tile-${p.row}-${p.col}'))),
          ];
          await swipe(t, pts);
          found++;
          if (found == 2) await shot(t, '08_playing');
          if (find.byKey(const ValueKey('tile-0-0')).evaluate().isEmpty) {
            finished = true;
            break;
          }
        }
        final resultScreen = await waitFor(t, find.text('יעד נקודות'), seconds: 20) ||
            find.byType(FortuneWheelDialog).evaluate().isNotEmpty ||
            find.byType(RewardReveal).evaluate().isNotEmpty;
        result('8', resultScreen, 'board words: ${words.length}, swiped: $found, early finish: $finished, reached result: $resultScreen');
      } catch (e) {
        result('8', false, 'exception: $e');
      }

      // 9. מסך סיום ופרסים
      await wait(t, 2000);
      await shot(t, '09_after_level');
      final rewards = await dismissRewards(t);
      final share = await waitFor(t, find.text('שתפו את ההישג'), seconds: 15);
      await shot(t, '09_level_result');
      result('9', share, 'reward dialogs handled: $rewards, result screen: $share');

      // 11-12. שיתוף
      if (share) {
        await tapText(t, 'שתפו את ההישג');
        final sheet = await waitFor(t, find.text('עוד...'), seconds: 15);
        await wait(t, 1500);
        await shot(t, '11_share_sheet');
        final fb = find.text('פייסבוק').evaluate().isNotEmpty;
        final wa = find.text('וואטסאפ').evaluate().isNotEmpty;
        result('11', sheet && fb && wa, 'sheet: $sheet, facebook: $fb, whatsapp: $wa');
        final errsBefore = errors.length;
        if (sheet) {
          await tapText(t, 'עוד...');
          await wait(t, 5000); // חלון השיתוף של iOS (נתפס בצילומי simctl)
        }
        result('12', sheet && errors.length == errsBefore, 'system share opened without Flutter errors: ${errors.length == errsBefore}');
      } else {
        result('11', false, 'result screen not reached');
        result('12', false, 'result screen not reached');
      }

      // 13. חנות -> כסף
      await go(t, '/store');
      final store = await tapText(t, 'כסף');
      await wait(t, 2500);
      await shot(t, '13_store_money');
      const titles = ['200 מטבעות', '600 מטבעות', '1500 מטבעות', '5 רמזים', '15 רמזים', '40 רמזים'];
      final shown = titles.where((s) => find.text(s).evaluate().isNotEmpty).length;
      var buyOk = true;
      try {
        await t.tap(find.text('200 מטבעות').first, warnIfMissed: false);
        await wait(t, 2500);
        await shot(t, '13_store_buy_tap');
      } catch (e) {
        buyOk = false;
      }
      result('13', store && shown == 6 && buyOk, 'money tab: $store, packs shown: $shown/6, tap buy ok: $buyOk');

      // 15. אתגר יומי
      await go(t, '/daily');
      final daily = await waitFor(t, find.text('התחילו את האתגר!'), seconds: 25);
      await shot(t, '15_daily');
      result('15', daily, 'daily start button: $daily');

      // 16. נגד המחשב
      await go(t, '/multiplayer/setup');
      final race = await waitFor(t, find.text('בואו נתחרה!'), seconds: 15);
      await shot(t, '16_vs_computer');
      result('16', race, 'race setup: $race');

      // 18. נגד חברים (מסך)
      await go(t, '/play/friends');
      await wait(t, 2000);
      final friends = find.textContaining('חבר').evaluate().isNotEmpty;
      await shot(t, '18_play_friends');
      result('18', friends, 'play-with-friends screen: $friends');

      // 24. מחיקת חשבון אורח
      final guestUid = FirebaseAuth.instance.currentUser?.uid;
      await go(t, '/settings');
      await shot(t, '24_settings');
      var guestDeleted = false;
      if (await tapText(t, 'מחיקת חשבון')) {
        await shot(t, '24_delete_confirm');
        await tapText(t, 'מחיקה לצמיתות');
        guestDeleted = await waitFor(t, find.text('החשבון נמחק'), seconds: 30);
        await shot(t, '24_deleted');
      }
      await wait(t, 3000);
      final afterGuest = FirebaseAuth.instance.currentUser;
      result('24', guestDeleted && afterGuest != null && afterGuest.uid != guestUid,
          'toast: $guestDeleted, old=$guestUid new=${afterGuest?.uid}');

      // 19. הרשמה עם מייל (חשבון בדיקה)
      String? emailUid;
      try {
        final container = ProviderScope.containerOf(t.element(find.byType(Scaffold).first));
        final email = 'wordbox.qa.${DateTime.now().millisecondsSinceEpoch}${Random().nextInt(999)}@example.com';
        final user = await container.read(authRepositoryProvider).registerWithEmail(
              email: email,
              password: 'QaTest!${Random().nextInt(99999)}xx',
              displayName: 'בודק',
            );
        emailUid = user.uid;
        await wait(t, 2500);
        final cur = FirebaseAuth.instance.currentUser;
        result('19', cur != null && !cur.isAnonymous && cur.email == email, 'registered $email uid=$emailUid');
      } catch (e) {
        result('19', false, 'exception: $e');
      }

      // 21. מחיקת חשבון רשום
      await go(t, '/settings');
      await wait(t, 1500);
      await shot(t, '21_settings_registered');
      var regDeleted = false;
      if (await tapText(t, 'מחיקת חשבון')) {
        await tapText(t, 'מחיקה לצמיתות');
        regDeleted = await waitFor(t, find.text('החשבון נמחק'), seconds: 30);
        await shot(t, '21_deleted');
      }
      await wait(t, 3000);
      final afterReg = FirebaseAuth.instance.currentUser;
      result('21', regDeleted && afterReg != null && afterReg.isAnonymous && afterReg.uid != emailUid,
          'toast: $regDeleted, now anonymous=${afterReg?.isAnonymous}');

      // ניקוי: ההתחברות באמת נמחקה מהשרת?
      // (signInWithEmail היה מצליח אם החשבון עוד קיים)
    } finally {
      await go(t, '/home');
      await shot(t, '99_end');
      // ignore: avoid_print
      print('FLUTTER_ERRORS_TOTAL|${errors.length}');
      FlutterError.onError = originalOnError;
    }
  }, timeout: const Timeout(Duration(minutes: 15)));
}
