import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/level_progress.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/game_engine/chapters.dart';
import 'package:wordbox_hebrew/game_engine/models/level_config.dart';
import 'package:wordbox_hebrew/game_engine/rewards/level_rewards.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';

class _Memory implements ProgressRepository {
  PlayerProfile stored;
  _Memory(this.stored);

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async => stored = profile;
}

Map<int, LevelProgress> _stars(int upTo, int stars) => {
      for (var l = 1; l <= upTo; l++) l: LevelProgress(levelNumber: l, stars: stars, bestScore: 10, completed: true),
    };

void main() {
  group('CampaignChapters', () {
    test('5 levels per chapter, 20 chapters, gates on 6, 11, ... 96', () {
      expect(CampaignChapters.totalChapters, 20);
      expect(CampaignChapters.chapterOf(1), 1);
      expect(CampaignChapters.chapterOf(5), 1);
      expect(CampaignChapters.chapterOf(6), 2);
      expect(CampaignChapters.chapterOf(100), 20);
      final gates = [for (var l = 1; l <= 100; l++) if (CampaignChapters.isGateLevel(l)) l];
      expect(gates.first, 6);
      expect(gates.last, 96);
      expect(gates.length, 19);
    });

    test('the required average rises from 1.8 to 2.4 stars per level', () {
      expect(CampaignChapters.requiredStars(1), 0);
      expect(CampaignChapters.requiredStars(2), 9); // 5 שלבים × ~1.8
      var previousAverage = 0.0;
      for (var c = 2; c <= CampaignChapters.totalChapters; c++) {
        final before = CampaignChapters.firstLevelOf(c) - 1;
        final avg = CampaignChapters.requiredStars(c) / before;
        expect(avg, inInclusiveRange(1.75, 2.45), reason: 'chapter $c');
        expect(avg, greaterThanOrEqualTo(previousAverage - 0.1), reason: 'chapter $c');
        expect(CampaignChapters.requiredStars(c), lessThanOrEqualTo(before * 3));
        previousAverage = avg;
      }
    });

    test('unlock cost grows with missing stars and world, within limits', () {
      expect(CampaignChapters.unlockCost(chapter: 2, missingStars: 0), 0);
      expect(CampaignChapters.unlockCost(chapter: 2, missingStars: 1), 60); // מינימום
      expect(
        CampaignChapters.unlockCost(chapter: 4, missingStars: 6),
        greaterThan(CampaignChapters.unlockCost(chapter: 4, missingStars: 3)),
      );
      expect(
        CampaignChapters.unlockCost(chapter: 18, missingStars: 6),
        greaterThan(CampaignChapters.unlockCost(chapter: 4, missingStars: 6)),
      );
      expect(CampaignChapters.unlockCost(chapter: 2, missingStars: 500), 300); // תקרה בעולם 1
      for (var c = 2; c <= 20; c++) {
        expect(CampaignChapters.unlockCost(chapter: c, missingStars: 7) % 5, 0);
      }
    });
  });

  group('PlayerProfile chapter gates', () {
    test('enough stars open the next chapter, too few keep it closed', () {
      final good = PlayerProfile(highestUnlockedLevel: 6, levelProgress: _stars(5, 2));
      expect(good.totalStars, 10);
      expect(good.canPlayLevel(6), isTrue);

      final weak = PlayerProfile(highestUnlockedLevel: 6, levelProgress: _stars(5, 1));
      expect(weak.canPlayLevel(6), isFalse);
      expect(weak.isBlockedByChapterGate(6), isTrue);
      expect(weak.missingStarsFor(2), 4);
    });

    test('a chapter already played stays open (players from before the gates)', () {
      final profile = PlayerProfile(
        highestUnlockedLevel: 8,
        levelProgress: {
          ..._stars(5, 1),
          6: const LevelProgress(levelNumber: 6, stars: 1, bestScore: 5, completed: true),
        },
      );
      expect(profile.canPlayLevel(7), isTrue);
    });

    test('levels not reached yet are never playable', () {
      final profile = PlayerProfile(highestUnlockedLevel: 3, levelProgress: _stars(2, 3));
      expect(profile.canPlayLevel(4), isFalse);
      expect(profile.isBlockedByChapterGate(4), isFalse);
    });
  });

  test('unlockChapter charges the current price once, and refuses without coins', () async {
    final repo = _Memory(PlayerProfile(highestUnlockedLevel: 6, coins: 500, levelProgress: _stars(5, 1)));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    final price = CampaignChapters.unlockCost(chapter: 2, missingStars: 4);
    expect(await notifier.unlockChapter(2), price);
    expect(notifier.state.value!.coins, 500 - price);
    expect(notifier.state.value!.canPlayLevel(6), isTrue);
    expect(await notifier.unlockChapter(2), 0, reason: 'already open - free');
    expect(notifier.state.value!.coins, 500 - price);

    final poor = PlayerProfileNotifier(_Memory(PlayerProfile(highestUnlockedLevel: 6, coins: 5, levelProgress: _stars(5, 1))));
    await poor.ensureLoaded();
    expect(await poor.unlockChapter(2), isNull);
    expect(poor.state.value!.coins, 5);
  });

  group('LevelRewards', () {
    test('first clear pays by stars and words; masters 1.5x; finale adds a bonus', () {
      expect(LevelRewards.firstClearCoins(kind: LevelKind.normal, stars: 0, wordsFound: 5), 0);
      expect(LevelRewards.firstClearCoins(kind: LevelKind.normal, stars: 3, wordsFound: 4), 2 + 12 + 4);
      expect(LevelRewards.firstClearCoins(kind: LevelKind.normal, stars: 3, wordsFound: 40), 2 + 12 + 6);
      expect(LevelRewards.firstClearCoins(kind: LevelKind.master, stars: 3, wordsFound: 6), 30);
      expect(
        LevelRewards.firstClearCoins(kind: LevelKind.worldFinale, stars: 3, wordsFound: 6),
        20 + LevelRewards.finaleBonusCoins,
      );
    });

    test('replays only pay for new stars', () {
      expect(LevelRewards.coinsFor(kind: LevelKind.normal, stars: 3, wordsFound: 9, firstClear: false, previousBestStars: 3), 0);
      expect(LevelRewards.coinsFor(kind: LevelKind.normal, stars: 3, wordsFound: 9, firstClear: false, previousBestStars: 1), 8);
      expect(LevelRewards.coinsFor(kind: LevelKind.normal, stars: 1, wordsFound: 9, firstClear: false, previousBestStars: 2), 0);
    });
  });

  group('DailyBonusTable', () {
    test('a week gives 5 hints and 110 coins (it used to give 28 hints)', () {
      final hints = DailyBonusTable.days.fold<int>(0, (a, d) => a + d.hints);
      final coins = DailyBonusTable.days.fold<int>(0, (a, d) => a + d.coins);
      expect(hints, 5);
      expect(coins, 110);
    });

    test('the streak continues only from yesterday, and wraps after day 7', () {
      final today = DateTime(2026, 11, 1);
      expect(DailyBonusTable.nextDay(lastClaimDate: null, previousDay: 0, today: today), 1);
      expect(DailyBonusTable.nextDay(lastClaimDate: '2026-10-31', previousDay: 3, today: today), 4);
      expect(DailyBonusTable.nextDay(lastClaimDate: '2026-10-30', previousDay: 3, today: today), 1);
      expect(DailyBonusTable.nextDay(lastClaimDate: '2026-10-31', previousDay: 7, today: today), 1);
    });

    test('claimDailyHintIfAvailable grants the day reward once per day', () async {
      final notifier = PlayerProfileNotifier(
        _Memory(const PlayerProfile(hintStreakDay: 1, lastHintClaimDate: '2026-10-31', hints: 0, coins: 0)),
      );
      await notifier.ensureLoaded();
      final reward = await notifier.claimDailyHintIfAvailable(now: DateTime(2026, 11, 1, 9));
      expect(reward!.day, 2);
      expect(reward.hintsAwarded, 1);
      expect(reward.coinsAwarded, 0);
      expect(notifier.state.value!.hints, 1);
      expect(await notifier.claimDailyHintIfAvailable(now: DateTime(2026, 11, 1, 20)), isNull);
    });
  });
}
