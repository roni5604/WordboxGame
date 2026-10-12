import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/features/rewards/reward_reveal.dart';
import 'package:wordbox_hebrew/game_engine/rewards/reward_tables.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';

class _Memory implements ProgressRepository {
  PlayerProfile stored;
  _Memory(this.stored);
  @override
  Future<PlayerProfile> loadProfile() async => stored;
  @override
  Future<void> saveProfile(PlayerProfile profile) async => stored = profile;
}

void main() {
  test('lucky box rarities follow the weights (roughly) and every tier appears', () {
    final rnd = Random(1);
    final counts = {for (final r in Rarity.values) r: 0};
    const n = 20000;
    for (var i = 0; i < n; i++) {
      final r = RewardTables.rollLuckyBox(worldIndex: 0, random: rnd).rarity;
      counts[r] = counts[r]! + 1;
    }
    for (final e in RewardTables.luckyBoxWeights.entries) {
      expect(counts[e.key]! / n, closeTo(e.value / 100, 0.02), reason: e.key.name);
    }
  });

  test('higher rarity always pays more than the tier below', () {
    final rnd = Random(2);
    for (var i = 0; i < 200; i++) {
      final coins = [for (final r in Rarity.values) RewardTables.contentsFor(r, worldIndex: 0, random: rnd).coins];
      for (var k = 1; k < coins.length; k++) {
        expect(coins[k], greaterThan(coins[k - 1]));
      }
    }
    final legendary = RewardTables.contentsFor(Rarity.legendary, worldIndex: 0);
    expect(legendary.hints, greaterThan(0));
    expect(legendary.doubleCoinsLevels, greaterThan(0));
  });

  test('pity guarantees epic or better after a dry streak', () {
    final rnd = Random(3);
    for (var i = 0; i < 300; i++) {
      final r = RewardTables.rollLuckyBox(worldIndex: 0, random: rnd, dropsSinceEpic: RewardTables.pityThreshold);
      expect(r.rarity.index, greaterThanOrEqualTo(Rarity.epic.index));
    }
  });

  test('star drops are smaller and never legendary', () {
    final rnd = Random(4);
    for (var i = 0; i < 2000; i++) {
      final r = RewardTables.rollLuckyBox(worldIndex: 0, random: rnd, kind: DropKind.starDrop);
      expect(r.rarity, isNot(Rarity.legendary));
      expect(r.kind, DropKind.starDrop);
    }
  });

  test('wheel neighbours never share a rarity colour', () {
    final prizes = RewardTables.wheelPrizes;
    for (var i = 0; i < prizes.length; i++) {
      expect(prizes[i].rarity, isNot(prizes[(i + 1) % prizes.length].rarity));
    }
  });

  test('charge path starts at the start tier, ends at the final tier, never skips >2', () {
    final rnd = Random(5);
    for (final finalR in Rarity.values) {
      for (var i = 0; i < 200; i++) {
        final path = RewardReveal.chargePath(finalR, Rarity.common, rnd);
        expect(path.first, Rarity.common);
        expect(path.last, finalR);
        expect(path.length - 1, inInclusiveRange(2, 4));
        for (var k = 1; k < path.length; k++) {
          final step = path[k].index - path[k - 1].index;
          expect(step, inInclusiveRange(0, 2));
        }
      }
    }
  });

  test('openLuckyDrop grants the reward and tracks the pity counter', () async {
    final repo = _Memory(const PlayerProfile(coins: 0, dropsSinceEpic: RewardTables.pityThreshold));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    final reward = await notifier.openLuckyDrop(worldIndex: 0, random: Random(9));
    expect(reward.rarity.index, greaterThanOrEqualTo(Rarity.epic.index));
    final p = notifier.state.value!;
    expect(p.coins, reward.coins);
    expect(p.hints, reward.hints);
    expect(p.dropsSinceEpic, 0, reason: 'an epic+ drop resets the pity counter');

    await notifier.grantLuckyBoxReward(const LuckyBoxReward(coins: 10));
    expect(notifier.state.value!.dropsSinceEpic, 1);
    // כוכב מזל לא משנה את רשת הביטחון.
    await notifier.grantLuckyBoxReward(const LuckyBoxReward(coins: 5, kind: DropKind.starDrop));
    expect(notifier.state.value!.dropsSinceEpic, 1);
  });
}
