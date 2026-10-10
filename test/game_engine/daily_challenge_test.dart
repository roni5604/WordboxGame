import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/game_engine/daily_challenge.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';

class _Memory implements ProgressRepository {
  PlayerProfile profile;
  _Memory(this.profile);

  @override
  Future<PlayerProfile> loadProfile() async => profile;

  @override
  Future<void> saveProfile(PlayerProfile p) async => profile = p;
}

void main() {
  group('DailyChallenge', () {
    test('same day -> same board for everyone, different days differ', () {
      final a = DailyChallenge.forDate(DateTime(2026, 10, 12, 8));
      final b = DailyChallenge.forDate(DateTime(2026, 10, 12, 23, 59));
      final c = DailyChallenge.forDate(DateTime(2026, 10, 13, 0, 1));
      expect(a.seed, b.seed);
      expect(a.dateKey, '2026-10-12');
      expect(c.seed, isNot(a.seed));
    });

    test('weekend boards are bigger', () {
      expect(DailyChallenge.forDate(DateTime(2026, 10, 9)).gridSize, 6); // שישי
      expect(DailyChallenge.forDate(DateTime(2026, 10, 10)).gridSize, 6); // שבת
      expect(DailyChallenge.forDate(DateTime(2026, 10, 11)).gridSize, 5); // ראשון
    });

    test('streak continues only from yesterday, across month boundaries', () {
      expect(DailyChallenge.nextStreak(lastDate: '2026-10-31', previousStreak: 4, today: DateTime(2026, 11, 1)), 5);
      expect(DailyChallenge.nextStreak(lastDate: '2026-10-29', previousStreak: 4, today: DateTime(2026, 11, 1)), 1);
      expect(DailyChallenge.nextStreak(lastDate: null, previousStreak: 0, today: DateTime(2026, 11, 1)), 1);
      expect(DailyChallenge.liveStreak(lastDate: '2026-10-30', streak: 6, today: DateTime(2026, 11, 1)), 0);
      expect(DailyChallenge.liveStreak(lastDate: '2026-10-31', streak: 6, today: DateTime(2026, 11, 1)), 6);
    });

    test('coins grow with score and streak, capped', () {
      expect(DailyChallenge.coinsFor(score: 0, streak: 1), 15);
      expect(DailyChallenge.coinsFor(score: 40, streak: 3), 10 + 20 + 15);
      expect(DailyChallenge.coinsFor(score: 999, streak: 30), 10 + 60 + 35);
    });
  });

  test('recordDailyChallenge counts once per day and builds the streak', () async {
    final repo = _Memory(const PlayerProfile(coins: 5, dailyChallengeDate: '2026-10-11', dailyChallengeStreak: 2, dailyChallengeBestStreak: 2));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();
    final today = DateTime(2026, 10, 12, 10);
    final challenge = DailyChallenge.forDate(today);

    final outcome = await notifier.recordDailyChallenge(challenge: challenge, score: 40, words: 9, now: today);
    expect(outcome, isNotNull);
    expect(outcome!.streak, 3);
    expect(outcome.newBestStreak, isTrue);
    expect(repo.profile.coins, 5 + outcome.coins);
    expect(repo.profile.dailyChallengeScore, 40);
    expect(repo.profile.playedDailyOn('2026-10-12'), isTrue);

    final again = await notifier.recordDailyChallenge(challenge: challenge, score: 99, words: 20, now: today);
    expect(again, isNull, reason: 'only the first attempt of the day counts');
    expect(repo.profile.dailyChallengeScore, 40);
  });
}
