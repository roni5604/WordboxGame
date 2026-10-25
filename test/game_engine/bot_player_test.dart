import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/game_engine/board_generator.dart';
import 'package:wordbox_hebrew/game_engine/bot_player.dart';
import 'package:wordbox_hebrew/game_engine/models/grid_position.dart';
import 'package:wordbox_hebrew/game_engine/word_finder.dart';

/// לוח "טיפוסי" של 4×4: 60 מילים, רובן קצרות (כמו בלוחות אמיתיים).
GeneratedBoard _typicalBoard() {
  const letters = 'אבגדהוזחטיכלמנסעפצקרשת';
  final rnd = Random(1);
  final words = <FoundWord>[];
  final lengths = [for (var i = 0; i < 18; i++) 2, for (var i = 0; i < 22; i++) 3, for (var i = 0; i < 13; i++) 4, for (var i = 0; i < 5; i++) 5, 6, 6];
  for (final len in lengths) {
    final w = List.generate(len, (_) => letters[rnd.nextInt(letters.length)]).join();
    words.add(FoundWord(w, [for (var i = 0; i < len; i++) GridPosition(0, i)]));
  }
  return GeneratedBoard(letters: const [['א']], possibleWords: words, size: 4);
}

/// מריץ תחרות של [seconds] שניות ומחזיר (מילים, ניקוד, שנייה של המילה הראשונה).
(int, int, double) _race(BotDifficulty d, int seed, {int seconds = 90, int Function(double t)? human}) {
  final bot = BotPlayer(name: 'בוט', difficulty: d, board: _typicalBoard(), random: Random(seed));
  const step = Duration(milliseconds: 100);
  double? first;
  for (var i = 0; i < seconds * 10; i++) {
    final t = i / 10;
    final found = bot.tick(step, humanScore: human?.call(t) ?? 0);
    if (found != null) first ??= t;
  }
  return (bot.foundWords.length, bot.score, first ?? seconds.toDouble());
}

void main() {
  test('הבוט מוצא מילים לאורך זמן וצובר ניקוד', () {
    final (words, score, _) = _race(BotDifficulty.hard, 3);
    expect(words, greaterThan(0));
    expect(score, greaterThan(0));
  });

  test('רמות מסודרות ואנושיות: קליל < בינוני < מומחה, ואף אחד לא "מכונה"', () {
    final avg = <BotDifficulty, double>{};
    for (final d in BotDifficulty.values) {
      var total = 0;
      for (var seed = 0; seed < 300; seed++) {
        // מול שחקן/ית "ממוצע/ת" שצובר/ת כ-14 נקודות ב-90 שניות.
        total += _race(d, seed, human: (t) => (t * 0.16).round()).$1;
      }
      avg[d] = total / 300;
    }
    // ignore: avoid_print
    print('ממוצע מילים ב-90 שניות: $avg');
    expect(avg[BotDifficulty.easy]!, lessThan(avg[BotDifficulty.normal]!));
    expect(avg[BotDifficulty.normal]!, lessThan(avg[BotDifficulty.hard]!));
    // בטווחים של שחקן/ית אנושי/ת ב-90 שניות על לוח 4×4.
    // בטווח אנושי, וכל רמה בבירור מעל הקודמת.
    expect(avg[BotDifficulty.easy]!, inInclusiveRange(2, 4.5));
    expect(avg[BotDifficulty.normal]!, inInclusiveRange(4, 7));
    expect(avg[BotDifficulty.hard]!, inInclusiveRange(7, 12));
    expect(avg[BotDifficulty.hard]! - avg[BotDifficulty.easy]!, greaterThan(3.5));
  });

  test('התחממות: אין מילה בשניות הראשונות', () {
    for (var seed = 0; seed < 100; seed++) {
      expect(_race(BotDifficulty.hard, seed).$3, greaterThanOrEqualTo(3));
      expect(_race(BotDifficulty.easy, seed).$3, greaterThanOrEqualTo(6));
    }
  });

  test('הבוט מאט כשהוא בורח מהשחקן/ית', () {
    var alone = 0;
    var vsStrong = 0;
    for (var seed = 0; seed < 200; seed++) {
      // שחקן/ית שלא מוצא/ת כלום מול שחקן/ית שצובר/ת 1.5 נקודות לשנייה.
      alone += _race(BotDifficulty.hard, seed).$2;
      vsStrong += _race(BotDifficulty.hard, seed, human: (t) => (t * 1.5).round()).$2;
    }
    expect(alone, lessThan(vsStrong));
  });

  test('הזמנים בין מילים משתנים (לא קצב קבוע)', () {
    final bot = BotPlayer(name: 'בוט', difficulty: BotDifficulty.normal, board: _typicalBoard(), random: Random(9));
    const step = Duration(milliseconds: 100);
    final times = <double>[];
    for (var i = 0; i < 1200; i++) {
      if (bot.tick(step) != null) times.add(i / 10);
    }
    final gaps = [for (var i = 1; i < times.length; i++) times[i] - times[i - 1]];
    expect(gaps.length, greaterThan(3));
    expect(gaps.reduce(max) - gaps.reduce(min), greaterThan(4));
  });

  test('מול מתחיל/ה שעוד לא מצא/ה כלום - הבוט מתון', () {
    var total = 0;
    for (var seed = 0; seed < 200; seed++) {
      total += _race(BotDifficulty.normal, seed, seconds: 40).$2;
    }
    // ממוצע ניקוד ב-40 שניות מול שחקן/ית עם 0 נקודות.
    expect(total / 200, lessThan(14));
  });
}
