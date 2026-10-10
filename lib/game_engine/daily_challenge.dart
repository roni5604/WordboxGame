/// "האתגר היומי": לוח אחד לכל יום, זהה לכל השחקנים בעולם (נוצר מזרע
/// שנגזר מהתאריך), עם ניסיון רשמי אחד ביום. מאפשר להשוות ניקוד מול
/// חברים על אותו לוח בדיוק, ומייצר סיבה לחזור כל יום (רצף ימים).
class DailyChallenge {
  final String dateKey;
  final int seed;
  final int gridSize;
  final Duration timeLimit;

  const DailyChallenge._({required this.dateKey, required this.seed, required this.gridSize, required this.timeLimit});

  /// האתגר של היום המקומי של [now] (חצות לפי שעון המכשיר).
  factory DailyChallenge.forDate(DateTime now) {
    final key = dateKeyFor(now);
    final ymd = now.year * 10000 + now.month * 100 + now.day;
    // ערבוב פשוט כדי שימים עוקבים לא ייתנו זרעים "קרובים".
    final seed = (ymd * 2654435761) & 0x7fffffff;
    // סופי שבוע (שישי/שבת) - לוח גדול ומאתגר יותר.
    final weekend = now.weekday == DateTime.friday || now.weekday == DateTime.saturday;
    return DailyChallenge._(
      dateKey: key,
      seed: seed,
      gridSize: weekend ? 6 : 5,
      timeLimit: const Duration(seconds: 90),
    );
  }

  /// מספר האתגר (לשיתוף: "אתגר יומי #123"), נספר מיום ההשקה.
  int get number {
    final parts = dateKey.split('-').map(int.parse).toList();
    final date = DateTime.utc(parts[0], parts[1], parts[2]);
    return date.difference(DateTime.utc(2026, 10, 1)).inDays + 1;
  }

  static String dateKeyFor(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// הרצף החדש אחרי ששיחקו היום, בהינתן התאריך האחרון ששוחק והרצף הקודם.
  static int nextStreak({required String? lastDate, required int previousStreak, required DateTime today}) {
    final todayKey = dateKeyFor(today);
    if (lastDate == todayKey) return previousStreak;
    final yesterdayKey = dateKeyFor(DateTime(today.year, today.month, today.day - 1));
    return lastDate == yesterdayKey ? previousStreak + 1 : 1;
  }

  /// הרצף שמוצג כרגע: אם לא שיחקו אתמול או היום - הרצף "נשבר" (0).
  static int liveStreak({required String? lastDate, required int streak, required DateTime today}) {
    final todayKey = dateKeyFor(today);
    final yesterdayKey = dateKeyFor(DateTime(today.year, today.month, today.day - 1));
    return lastDate == todayKey || lastDate == yesterdayKey ? streak : 0;
  }

  /// מטבעות על האתגר: בסיס + חלק מהניקוד (עד תקרה) + בונוס רצף (עד 7 ימים).
  static int coinsFor({required int score, required int streak}) {
    final fromScore = (score / 2).floor().clamp(0, 60);
    final streakBonus = 5 * streak.clamp(1, 7);
    return 10 + fromScore + streakBonus;
  }
}

/// תוצאת רישום האתגר היומי - להצגה במסך התוצאות.
class DailyChallengeOutcome {
  final int score;
  final int words;
  final int streak;
  final int coins;
  final bool newBestStreak;

  const DailyChallengeOutcome({
    required this.score,
    required this.words,
    required this.streak,
    required this.coins,
    required this.newBestStreak,
  });
}
