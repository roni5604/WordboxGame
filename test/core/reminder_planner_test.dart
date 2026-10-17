import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/notifications/reminder_planner.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';

void main() {
  final now = DateTime(2026, 11, 10, 15, 0);

  PlannedReminder? byId(List<PlannedReminder> list, int id) {
    for (final r in list) {
      if (r.id == id) return r;
    }
    return null;
  }

  test('a registered player gets tomorrow evening bonus + 3-day and 7-day comebacks', () {
    const profile = PlayerProfile(
      highestUnlockedLevel: 12,
      hintStreakDay: 3,
      lastHintClaimDate: '2026-11-10',
      coins: 120,
      hints: 2,
    );
    final plan = ReminderPlanner.plan(profile, now, isGuest: false);

    final daily = byId(plan, ReminderPlanner.dailyId)!;
    expect(daily.at, DateTime(2026, 11, 11, ReminderPlanner.eveningHour));
    expect(daily.body, contains('יום 4'));
    expect(daily.route, '/home');

    expect(byId(plan, ReminderPlanner.comeback3Id)!.at, DateTime(2026, 11, 13, ReminderPlanner.comebackHour));
    expect(byId(plan, ReminderPlanner.comeback7Id)!.at, DateTime(2026, 11, 17, ReminderPlanner.comebackHour));
    expect(byId(plan, ReminderPlanner.comeback3Id)!.body, contains('שלב 12'));
    expect(byId(plan, ReminderPlanner.streakTodayId), isNull);
  });

  test('day 7 of the bonus gets its own title', () {
    const profile = PlayerProfile(hintStreakDay: 6, lastHintClaimDate: '2026-11-10');
    final daily = byId(ReminderPlanner.plan(profile, now, isGuest: false), ReminderPlanner.dailyId)!;
    expect(daily.title, contains('השביעי'));
  });

  test('a daily-challenge streak at risk today gets a same-day alert', () {
    const profile = PlayerProfile(dailyChallengeDate: '2026-11-09', dailyChallengeStreak: 4);
    final plan = ReminderPlanner.plan(profile, now, isGuest: false);
    final alert = byId(plan, ReminderPlanner.streakTodayId)!;
    expect(alert.at, DateTime(2026, 11, 10, ReminderPlanner.streakAlertHour));
    expect(alert.title, contains('4'));
    expect(alert.route, '/daily');
  });

  test('no same-day alert once it is too late, or after playing today', () {
    const atRisk = PlayerProfile(dailyChallengeDate: '2026-11-09', dailyChallengeStreak: 4);
    final late = ReminderPlanner.plan(atRisk, DateTime(2026, 11, 10, 19, 45), isGuest: false);
    expect(byId(late, ReminderPlanner.streakTodayId), isNull);

    const played = PlayerProfile(dailyChallengeDate: '2026-11-10', dailyChallengeStreak: 5);
    final plan = ReminderPlanner.plan(played, now, isGuest: false);
    expect(byId(plan, ReminderPlanner.streakTodayId), isNull);
    // רצף ארוך - התזכורת של מחר מדברת על הרצף, לא על הבונוס.
    expect(byId(plan, ReminderPlanner.dailyId)!.route, '/daily');
  });

  test('guests (no daily bonus) are reminded about the daily challenge instead', () {
    final plan = ReminderPlanner.plan(const PlayerProfile(), now, isGuest: true);
    expect(byId(plan, ReminderPlanner.dailyId)!.route, '/daily');
  });

  test('every planned reminder is in the future and uses a known id', () {
    final plan = ReminderPlanner.plan(const PlayerProfile(), now, isGuest: false);
    for (final r in plan) {
      expect(r.at.isAfter(now), isTrue);
      expect(ReminderPlanner.allIds, contains(r.id));
    }
  });
}
