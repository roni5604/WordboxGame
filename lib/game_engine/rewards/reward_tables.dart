import 'dart:math';

import 'package:equatable/equatable.dart';

/// פרס שהתקבל מ"תיבת מזל" - תגמול קטן-בינוני אקראי, שנפתח אוטומטית
/// בכל שלב שמספרו מתחלק ב-[kLuckyBoxLevelInterval] (ראו
/// lib/features/game/game_screen.dart).
class LuckyBoxReward extends Equatable {
  final int coins;
  final int hints;

  const LuckyBoxReward({required this.coins, this.hints = 0});

  @override
  List<Object?> get props => [coins, hints];
}

/// פרס בודד על גלגל המזל - כולל משקל (לבחירה אקראית משוקללת) ותווית
/// תצוגה, כדי שאפשר יהיה גם לצייר את מקטעי הגלגל וגם לגלגל תוצאה.
class FortuneWheelPrize extends Equatable {
  final String label;
  final int weight;
  final int coins;
  final int hints;

  /// מספר השלבים הבאים שבהם מטבעות שיורוויחו יוכפלו (ראו
  /// PlayerProfile.doubleCoinsLevelsRemaining) - 0 אם הפרס לא כולל זאת.
  final int doubleCoinsLevels;

  const FortuneWheelPrize({
    required this.label,
    required this.weight,
    this.coins = 0,
    this.hints = 0,
    this.doubleCoinsLevels = 0,
  });

  /// תיאור התוצאה בפועל אחרי הגרלה (כולל הכמות המדויקת) - בשונה מ-[label]
  /// שהוא הכיתוב הגנרי המוצג *על* מקטע הגלגל עצמו (לפני שידוע לאיזה
  /// עולם/כמות בדיוק זה יתורגם).
  String get resultText {
    final parts = <String>[];
    if (coins > 0) parts.add('+$coins מטבעות');
    if (hints > 0) parts.add('+$hints רמזים');
    if (doubleCoinsLevels > 0) parts.add('מטבעות כפולות ל-$doubleCoinsLevels שלבים');
    return parts.isEmpty ? label : parts.join(' ו-');
  }

  @override
  List<Object?> get props => [label, weight, coins, hints, doubleCoinsLevels];
}

/// טבלאות התגמולים האקראיים של המשחק - תיבת מזל (כל 7 שלבים) וגלגל מזל
/// (בסיום כל עולם). התגמולים גדלים קלות ככל שמתקדמים בעולמות, כדי
/// שההגרלות ימשיכו להרגיש משמעותיות גם בשלבים מתקדמים.
class RewardTables {
  RewardTables._();

  /// כל 7 שלבים גלובליים (7, 14, 21...) נפתחת תיבת מזל - ראו
  /// lib/features/game/game_screen.dart.
  static const int luckyBoxLevelInterval = 7;

  static bool isLuckyBoxLevel(int levelNumber) =>
      levelNumber > 0 && levelNumber % luckyBoxLevelInterval == 0;

  /// מגריל פרס לתיבת מזל: מטבעות קטנים-בינוניים, ולעיתים גם רמז אחד.
  /// [worldIndex] (0-מבוסס) מגדיל מעט את טווח המטבעות בעולמות מתקדמים.
  static LuckyBoxReward rollLuckyBox({required int worldIndex, Random? random}) {
    final rnd = random ?? Random();
    final scale = 1 + worldIndex * 0.3;
    final baseMin = 15;
    final baseMax = 40;
    final coins = (baseMin + rnd.nextInt(baseMax - baseMin + 1)) * scale;
    // ~35% מהתיבות מזכות גם ברמז חינם.
    final hints = rnd.nextDouble() < 0.35 ? 1 : 0;
    return LuckyBoxReward(coins: coins.round(), hints: hints);
  }

  /// מקטעי גלגל המזל - מוצג בפועל ב-fortune_wheel_dialog.dart. הכיתוב על
  /// כל מקטע גנרי (בלי כמות מדויקת, כי הכמות בפועל תלויה בעולם - ראו
  /// [rollWheelPrize]); הכמות המדויקת מוצגת רק אחרי הסיבוב, דרך
  /// [FortuneWheelPrize.resultText]. משקלים לא-אחידים בכוונה: פרסים
  /// קטנים נפוצים, פרסים גדולים נדירים ("ג'קפוט").
  static const List<FortuneWheelPrize> wheelPrizes = [
    FortuneWheelPrize(label: 'מטבעות', weight: 28, coins: 60),
    FortuneWheelPrize(label: 'רמזים', weight: 20, hints: 3),
    FortuneWheelPrize(label: 'מטבעות פרימיום', weight: 20, coins: 120),
    FortuneWheelPrize(label: 'רמזי בונוס', weight: 12, hints: 5),
    FortuneWheelPrize(label: 'מטבעות ענק', weight: 10, coins: 200),
    FortuneWheelPrize(
      label: 'מטבעות כפולות!',
      weight: 7,
      doubleCoinsLevels: 3,
    ),
    FortuneWheelPrize(label: 'ג\'קפוט! 🎉', weight: 3, coins: 400),
  ];

  /// מגריל מקטע מתוך [wheelPrizes] לפי המשקלים שלהם, ומחזיר גם את
  /// המקטע וגם את האינדקס שלו (כדי שהגלגל יוכל לסובב בדיוק אליו).
  /// [worldIndex] (0-מבוסס) מגדיל את כמות המטבעות בפרסים - ככל שמתקדמים
  /// בעולמות, גם גלגל המזל "משדרג" את הפרסים שלו.
  static (int index, FortuneWheelPrize prize) rollWheelPrize({
    required int worldIndex,
    Random? random,
  }) {
    final rnd = random ?? Random();
    final totalWeight = wheelPrizes.fold<int>(0, (sum, p) => sum + p.weight);
    final roll = rnd.nextInt(totalWeight);

    int cumulative = 0;
    for (int i = 0; i < wheelPrizes.length; i++) {
      cumulative += wheelPrizes[i].weight;
      if (roll < cumulative) {
        final base = wheelPrizes[i];
        if (base.coins == 0) return (i, base);
        final scale = 1 + worldIndex * 0.4;
        final scaled = FortuneWheelPrize(
          label: base.label,
          weight: base.weight,
          coins: (base.coins * scale).round(),
          hints: base.hints,
          doubleCoinsLevels: base.doubleCoinsLevels,
        );
        return (i, scaled);
      }
    }
    return (0, wheelPrizes.first);
  }
}
