import 'dart:math';

import 'package:equatable/equatable.dart';

import 'rarity.dart';

export 'rarity.dart';

/// איזה סוג "הפתעה" זו - קובע את הכותרת והצורה במסך הפתיחה.
enum DropKind {
  /// תיבת מזל - כל 7 שלבים.
  luckyBox,

  /// כוכב מזל - הפתעה אקראית על שלב שהושלם ב-3 כוכבים בפעם הראשונה.
  starDrop,
}

/// פרס שהתקבל מ"תיבת מזל" / "כוכב מזל" - דרגת נדירות + מה שבתוכה.
/// הדרגה נקבעת מראש (ראו [RewardTables.rollLuckyBox]); מסך הפתיחה רק חושף
/// אותה בהדרגה (lib/features/rewards/reward_reveal.dart).
class LuckyBoxReward extends Equatable {
  final int coins;
  final int hints;
  final Rarity rarity;
  final DropKind kind;

  /// מטבעות כפולות ל-X השלבים הבאים (רק בתיבות אגדיות).
  final int doubleCoinsLevels;

  const LuckyBoxReward({
    required this.coins,
    this.hints = 0,
    this.rarity = Rarity.common,
    this.kind = DropKind.luckyBox,
    this.doubleCoinsLevels = 0,
  });

  @override
  List<Object?> get props => [coins, hints, rarity, kind, doubleCoinsLevels];
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

  /// דרגת הנדירות של המקטע - קובעת את צבעו על הגלגל ואת עוצמת החגיגה.
  final Rarity rarity;

  const FortuneWheelPrize({
    required this.label,
    required this.weight,
    this.coins = 0,
    this.hints = 0,
    this.doubleCoinsLevels = 0,
    this.rarity = Rarity.common,
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
  List<Object?> get props => [label, weight, coins, hints, doubleCoinsLevels, rarity];
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

  /// משקלי הדרגות בתיבת מזל (מתוך 100): רוב התיבות רגילות/לא שכיחות, אבל
  /// כמעט אחת מכל ארבע נדירה ומעלה - כך שכל פתיחה מרגישה כמו סיכוי אמיתי.
  static const Map<Rarity, int> luckyBoxWeights = {
    Rarity.common: 44,
    Rarity.uncommon: 30,
    Rarity.rare: 16,
    Rarity.epic: 8,
    Rarity.legendary: 2,
  };

  /// כוכב מזל: קטן יותר ולעולם לא אגדי (זה שמור לתיבה).
  static const Map<Rarity, int> starDropWeights = {
    Rarity.common: 55,
    Rarity.uncommon: 28,
    Rarity.rare: 13,
    Rarity.epic: 4,
  };

  /// "רשת ביטחון" (pity): אחרי כמה תיבות ברצף בלי אפי/אגדי, התיבה הבאה
  /// מובטחת אפי ומעלה. כך גם מי שאין לו מזל מרגיש/ה התקדמות.
  static const int pityThreshold = 8;

  /// הסיכוי לכוכב מזל על שלב שהושלם ב-3 כוכבים בפעם הראשונה (היה 0.3).
  static const double starDropChance = 0.2;

  /// מגריל פרס לתיבת מזל / כוכב מזל: קודם דרגה, ואז תוכן לפי הדרגה.
  /// [worldIndex] (0-מבוסס) מגדיל את המטבעות בעולמות מתקדמים.
  /// [dropsSinceEpic] - כמה תיבות נפתחו מאז האפי/אגדי האחרון (ל-pity).
  static LuckyBoxReward rollLuckyBox({
    required int worldIndex,
    Random? random,
    DropKind kind = DropKind.luckyBox,
    int dropsSinceEpic = 0,
  }) {
    final rnd = random ?? Random();
    final weights = kind == DropKind.starDrop ? starDropWeights : luckyBoxWeights;
    var rarity = _weighted(weights, rnd);
    if (kind == DropKind.luckyBox && dropsSinceEpic >= pityThreshold && rarity.index < Rarity.epic.index) {
      rarity = rnd.nextDouble() < 0.2 ? Rarity.legendary : Rarity.epic;
    }
    return contentsFor(rarity, worldIndex: worldIndex, random: rnd, kind: kind);
  }

  /// התוכן של תיבה בדרגה נתונה. טווחי המטבעות גדלים בכל דרגה בערך פי 2,
  /// כך שההבדל בין "נדיר" ל"אגדי" מורגש באמת. הכמויות ירדו בכ-40% ואחוז
  /// הרמזים ירד בחצי מהגרסה הראשונה - התיבות נתנו יותר מדי (ראו
  /// lib/game_engine/rewards/level_rewards.dart).
  static LuckyBoxReward contentsFor(
    Rarity rarity, {
    required int worldIndex,
    Random? random,
    DropKind kind = DropKind.luckyBox,
  }) {
    final rnd = random ?? Random();
    final scale = (1 + worldIndex * 0.3) * (kind == DropKind.starDrop ? 0.6 : 1.0);
    int range(int min, int max) => ((min + rnd.nextInt(max - min + 1)) * scale).round();
    switch (rarity) {
      case Rarity.common:
        return LuckyBoxReward(coins: range(8, 14), rarity: rarity, kind: kind);
      case Rarity.uncommon:
        return LuckyBoxReward(
          coins: range(15, 25),
          hints: rnd.nextDouble() < 0.25 ? 1 : 0,
          rarity: rarity,
          kind: kind,
        );
      case Rarity.rare:
        return LuckyBoxReward(coins: range(30, 45), hints: 1, rarity: rarity, kind: kind);
      case Rarity.epic:
        return LuckyBoxReward(coins: range(60, 90), hints: 1, rarity: rarity, kind: kind);
      case Rarity.legendary:
        return LuckyBoxReward(
          coins: range(150, 200),
          hints: 2,
          doubleCoinsLevels: 2,
          rarity: rarity,
          kind: kind,
        );
    }
  }

  static Rarity _weighted(Map<Rarity, int> weights, Random rnd) {
    final total = weights.values.fold<int>(0, (a, b) => a + b);
    var roll = rnd.nextInt(total);
    for (final e in weights.entries) {
      if (roll < e.value) return e.key;
      roll -= e.value;
    }
    return weights.keys.first;
  }

  /// מקטעי גלגל המזל - מוצג בפועל ב-fortune_wheel_dialog.dart. הכיתוב על
  /// כל מקטע גנרי (בלי כמות מדויקת, כי הכמות בפועל תלויה בעולם - ראו
  /// [rollWheelPrize]); הכמות המדויקת מוצגת רק אחרי הסיבוב, דרך
  /// [FortuneWheelPrize.resultText]. משקלים לא-אחידים בכוונה: פרסים
  /// קטנים נפוצים, פרסים גדולים נדירים ("ג'קפוט").
  static const List<FortuneWheelPrize> wheelPrizes = [
    // הסדר מתחלף בין דרגות, כך ששני מקטעים סמוכים אף פעם לא באותו צבע.
    FortuneWheelPrize(label: 'מטבעות', weight: 28, coins: 40),
    FortuneWheelPrize(label: 'רמזי בונוס', weight: 12, hints: 2, rarity: Rarity.rare),
    FortuneWheelPrize(label: 'רמז', weight: 20, hints: 1, rarity: Rarity.uncommon),
    FortuneWheelPrize(label: 'מטבעות כפולות!', weight: 7, doubleCoinsLevels: 3, rarity: Rarity.epic),
    FortuneWheelPrize(label: 'מטבעות פרימיום', weight: 20, coins: 80, rarity: Rarity.uncommon),
    FortuneWheelPrize(label: 'ג\'קפוט!', weight: 3, coins: 250, hints: 2, rarity: Rarity.legendary),
    FortuneWheelPrize(label: 'מטבעות ענק', weight: 10, coins: 130, rarity: Rarity.rare),
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
        final scale = 1 + worldIndex * 0.3;
        final scaled = FortuneWheelPrize(
          label: base.label,
          weight: base.weight,
          coins: (base.coins * scale).round(),
          hints: base.hints,
          doubleCoinsLevels: base.doubleCoinsLevels,
          rarity: base.rarity,
        );
        return (i, scaled);
      }
    }
    return (0, wheelPrizes.first);
  }
}
