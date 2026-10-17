import 'dart:math';

import '../models/level_config.dart';

/// כמה מטבעות ורמזים שלב נותן. לוגיקה טהורה (בלי Flutter) כדי שאפשר יהיה
/// לבדוק את הכלכלה בלי מסך.
///
/// הכלכלה הקודמת נתנה כ-2,400 מטבעות ו-28 רמזים עד שלב 30 (סימולציה של
/// שחקן/ית טוב/ה), ושחזור שלב נתן את כל הפרס מחדש - אפשר היה "לחרוש" את
/// שלב 1. עכשיו:
/// - פרס מלא רק בפעם הראשונה שהשלב עובר (לפחות כוכב אחד).
/// - בשחזור: מטבעות רק על כוכבים חדשים ששופרו ([replayCoinsPerNewStar]).
/// - הבסיס קטן יותר: 2 + 4 לכל כוכב + מטבע לכל מילה (עד 6 מילים).
/// התוצאה בסימולציה: כ-1,200 מטבעות ו-9 רמזים עד שלב 30.
class LevelRewards {
  LevelRewards._();

  static const int finaleBonusCoins = 40;
  static const int finaleBonusHints = 1;
  static const int replayCoinsPerNewStar = 4;
  static const int maxWordsCounted = 6;

  /// מטבעות על מעבר ראשון של שלב (כולל בונוס הפינאלה).
  static int firstClearCoins({required LevelKind kind, required int stars, required int wordsFound}) {
    if (stars <= 0) return 0;
    final int base = 2 + stars * 4 + min(wordsFound, maxWordsCounted);
    return switch (kind) {
      LevelKind.master => (base * 1.5).round(),
      LevelKind.worldFinale => base + finaleBonusCoins,
      LevelKind.normal => base,
    };
  }

  /// מטבעות בשחזור של שלב שכבר עבר - רק על כוכבים שנוספו.
  static int replayCoins({required int stars, required int previousBestStars}) =>
      max(0, stars - previousBestStars) * replayCoinsPerNewStar;

  /// המטבעות של סיום שלב, לפי אם זו הפעם הראשונה שהוא עובר.
  static int coinsFor({
    required LevelKind kind,
    required int stars,
    required int wordsFound,
    required bool firstClear,
    required int previousBestStars,
  }) {
    return firstClear
        ? firstClearCoins(kind: kind, stars: stars, wordsFound: wordsFound)
        : replayCoins(stars: stars, previousBestStars: previousBestStars);
  }
}

/// הבונוס היומי: לוח של 7 ימים עם מטבעות ורמזים לסירוגין. קודם כל יום
/// נתן רמזים כמספר היום (1+2+...+7 = 28 רמזים בשבוע) - זה היה המקור
/// העיקרי לעודף הרמזים. עכשיו: 5 רמזים ו-110 מטבעות בשבוע, והיום השביעי
/// הוא עדיין הפרס הגדול. יום שמפספסים מחזיר את הרצף ליום 1.
class DailyBonusTable {
  DailyBonusTable._();

  static const List<({int coins, int hints})> days = [
    (coins: 10, hints: 0),
    (coins: 0, hints: 1),
    (coins: 20, hints: 0),
    (coins: 0, hints: 1),
    (coins: 30, hints: 0),
    (coins: 0, hints: 1),
    (coins: 50, hints: 2),
  ];

  static ({int coins, int hints}) rewardFor(int day) => days[(day - 1).clamp(0, days.length - 1)];

  /// היום הבא ברצף: ממשיכים רק אם התביעה האחרונה הייתה אתמול; אחרי יום 7
  /// (או אחרי יום שפוספס) מתחילים מיום 1.
  static int nextDay({required String? lastClaimDate, required int previousDay, required DateTime today}) {
    if (lastClaimDate == null || previousDay <= 0) return 1;
    final yesterday = DateTime(today.year, today.month, today.day - 1);
    if (lastClaimDate != dateKey(yesterday)) return 1;
    return previousDay >= days.length ? 1 : previousDay + 1;
  }

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
