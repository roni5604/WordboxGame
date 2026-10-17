import '../../data/models/player_profile.dart';
import '../../game_engine/daily_challenge.dart';
import '../../game_engine/rewards/level_rewards.dart';

/// תזכורת מתוזמנת אחת (התראה מקומית במכשיר).
class PlannedReminder {
  final int id;
  final DateTime at;
  final String title;
  final String body;

  /// לאן לנווט כשלוחצים על ההתראה.
  final String route;

  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
    required this.route,
  });

  @override
  String toString() => 'PlannedReminder($id @ $at: $title)';
}

/// מחליט אילו תזכורות לתזמן, לפי מצב השחקן/ית ברגע זה. לוגיקה טהורה -
/// השירות (notification_service.dart) מבטל ומתזמן מחדש בכל פעם שהאפליקציה
/// יוצאת לרקע, כך שהתוכן תמיד מעודכן.
///
/// עקרונות (כדי שההתראות יעזרו ולא יציקו):
/// - לכל היותר תזכורת אחת ביום, בערב ([eveningHour]) - חוץ ממקרה אחד:
///   רצף של האתגר היומי שעומד להישבר היום ([streakAlertHour]).
/// - כל תזכורת אומרת משהו קונקרטי (מה מחכה, כמה ימים ברצף), לא "חזרו!".
/// - אם לא חוזרים: תזכורת אחרי 3 ימים ואחרי 7 ימים, ואז שקט.
class ReminderPlanner {
  ReminderPlanner._();

  static const int dailyId = 1001;
  static const int streakTodayId = 1002;
  static const int comeback3Id = 1003;
  static const int comeback7Id = 1007;

  static const List<int> allIds = [dailyId, streakTodayId, comeback3Id, comeback7Id];

  static const int eveningHour = 19;
  static const int streakAlertHour = 20;
  static const int comebackHour = 18;

  static List<PlannedReminder> plan(PlayerProfile profile, DateTime now, {required bool isGuest}) {
    final reminders = <PlannedReminder>[];
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = DateTime(today.year, today.month, today.day + 1);
    final todayKey = DailyChallenge.dateKeyFor(today);
    final playedDailyToday = profile.playedDailyOn(todayKey);
    final liveStreak = DailyChallenge.liveStreak(
      lastDate: profile.dailyChallengeDate,
      streak: profile.dailyChallengeStreak,
      today: today,
    );

    // 1. רצף האתגר היומי בסכנה היום: שוחק אתמול, עוד לא היום, ועוד יש זמן.
    final streakAlertAt = DateTime(today.year, today.month, today.day, streakAlertHour);
    if (!playedDailyToday && liveStreak >= 2 && now.isBefore(streakAlertAt.subtract(const Duration(minutes: 30)))) {
      reminders.add(
        PlannedReminder(
          id: streakTodayId,
          at: streakAlertAt,
          title: '🔥 רצף של $liveStreak ימים בסכנה',
          body: 'האתגר היומי של היום עוד מחכה. דקה וחצי וזה שמור!',
          route: '/daily',
        ),
      );
    }

    // 2. מחר בערב: הבונוס היומי (או רצף האתגר, אם הוא ארוך).
    final tomorrowStreak = playedDailyToday ? liveStreak : 0;
    final evening = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, eveningHour);
    if (tomorrowStreak >= 3) {
      reminders.add(
        PlannedReminder(
          id: dailyId,
          at: evening,
          title: '🔥 $tomorrowStreak ימים ברצף באתגר היומי',
          body: 'לוח חדש לכולם - שחקו היום כדי שהרצף ימשיך.',
          route: '/daily',
        ),
      );
    } else if (!isGuest) {
      final claimedToday = profile.lastHintClaimDate == DailyBonusTable.dateKey(today);
      final nextDay = claimedToday
          ? (profile.hintStreakDay >= DailyBonusTable.days.length ? 1 : profile.hintStreakDay + 1)
          : 1;
      final reward = DailyBonusTable.rewardFor(nextDay);
      reminders.add(
        PlannedReminder(
          id: dailyId,
          at: evening,
          title: nextDay == 7 ? '🎁 היום השביעי - הבונוס הגדול!' : '🎁 הבונוס היומי מחכה',
          body: 'יום $nextDay ברצף: ${_describe(reward)}. יום שמפספסים מחזיר את הרצף להתחלה.',
          route: '/home',
        ),
      );
    } else {
      reminders.add(
        PlannedReminder(
          id: dailyId,
          at: evening,
          title: '🧩 אתגר יומי חדש',
          body: 'לוח אחד לכל השחקנים. כמה מילים תמצאו היום?',
          route: '/daily',
        ),
      );
    }

    // 3. חזרה אחרי הפסקה.
    final level = profile.highestUnlockedLevel;
    reminders.add(
      PlannedReminder(
        id: comeback3Id,
        at: DateTime(today.year, today.month, today.day + 3, comebackHour),
        title: 'זואי מחפשת מילים 🐾',
        body: 'שלב $level מחכה לכם. בואו נראה אם תגיעו לשלושה כוכבים.',
        route: '/campaign',
      ),
    );
    reminders.add(
      PlannedReminder(
        id: comeback7Id,
        at: DateTime(today.year, today.month, today.day + 7, comebackHour),
        title: 'מתגעגעים אליכם במצא ת׳מילה',
        body: profile.coins > 0
            ? 'יש לכם ${profile.coins} מטבעות ו-${profile.hints} רמזים שמחכים בשלב $level.'
            : 'שלב $level מחכה, ויש אתגר יומי חדש.',
        route: '/campaign',
      ),
    );

    return reminders.where((r) => r.at.isAfter(now)).toList();
  }

  static String _describe(({int coins, int hints}) reward) {
    final parts = [
      if (reward.coins > 0) '${reward.coins} מטבעות',
      if (reward.hints == 1) 'רמז',
      if (reward.hints > 1) '${reward.hints} רמזים',
    ];
    return parts.join(' ו-');
  }
}
