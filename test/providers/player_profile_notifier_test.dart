import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/core/cosmetics/cosmetic_catalog.dart';
import 'package:wordbox_hebrew/data/models/player_profile.dart';
import 'package:wordbox_hebrew/data/repositories/progress_repository.dart';
import 'package:wordbox_hebrew/providers/player_profile_provider.dart';

class _MemoryProgressRepository implements ProgressRepository {
  PlayerProfile stored;

  _MemoryProgressRepository(this.stored);

  @override
  Future<PlayerProfile> loadProfile() async => stored;

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    stored = profile;
  }
}

void main() {
  test('spendCoins גורע מטבעות ומסרב כשאין מספיק', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 20));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    expect(await notifier.spendCoins(5), isTrue);
    expect(notifier.state.value?.coins, 15);

    expect(await notifier.spendCoins(20), isFalse);
    expect(notifier.state.value?.coins, 15);
  });

  test('completeLevel בלי כוכב לא פותח את השלב הבא ועדיין שומר שיא', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 0, highestUnlockedLevel: 1));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    final coins = await notifier.completeLevel(
      levelNumber: 1,
      stars: 0,
      score: 4,
      coinsEarned: 30,
    );

    final profile = notifier.state.value!;
    expect(coins, 0);
    expect(profile.highestUnlockedLevel, 1);
    expect(profile.progressFor(1).completed, isFalse);
    expect(profile.progressFor(1).bestScore, 4);
    expect(profile.coins, 0);

    final earned = await notifier.completeLevel(
      levelNumber: 1,
      stars: 1,
      score: 5,
      coinsEarned: 10,
    );
    expect(earned, 10);
    expect(notifier.state.value!.highestUnlockedLevel, 2);
    expect(notifier.state.value!.progressFor(1).completed, isTrue);
    expect(notifier.state.value!.progressFor(1).stars, 1);
    expect(notifier.state.value!.coins, 10);
  });

  test('completeLevel עם כוכב פותח את השלב הבא ולא מוריד כוכבים בשיחזור חלש', () async {
    final repo = _MemoryProgressRepository(
      const PlayerProfile(coins: 10, highestUnlockedLevel: 3, doubleCoinsLevelsRemaining: 2),
    );
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    await notifier.completeLevel(levelNumber: 2, stars: 3, score: 20, coinsEarned: 10);
    expect(notifier.state.value!.highestUnlockedLevel, 3);
    expect(notifier.state.value!.progressFor(2).stars, 3);
    expect(notifier.state.value!.coins, 30);
    expect(notifier.state.value!.doubleCoinsLevelsRemaining, 1);

    await notifier.completeLevel(levelNumber: 2, stars: 0, score: 2, coinsEarned: 10);
    expect(notifier.state.value!.highestUnlockedLevel, 3);
    expect(notifier.state.value!.progressFor(2).stars, 3);
    expect(notifier.state.value!.progressFor(2).completed, isTrue);
    expect(notifier.state.value!.progressFor(2).bestScore, 20);
    expect(notifier.state.value!.doubleCoinsLevelsRemaining, 1);
  });

  test('skipLevel פותח את השלב הבא בכוכב אחד ובלי להוסיף מטבעות', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 80, highestUnlockedLevel: 1));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    expect(await notifier.skipLevel(levelNumber: 1, cost: 52), isTrue);
    final profile = notifier.state.value!;
    expect(profile.coins, 28);
    expect(profile.highestUnlockedLevel, 2);
    expect(profile.progressFor(1).stars, 1);
    expect(profile.progressFor(1).completed, isTrue);

    expect(await notifier.skipLevel(levelNumber: 2, cost: 100), isFalse);
    expect(notifier.state.value!.highestUnlockedLevel, 2);
  });

  test('buyOrEquipCosmetic מחייב פעם אחת ואז רק מצייד', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 100));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    expect(
      await notifier.buyOrEquipCosmetic(slot: CosmeticSlot.board, id: 'ocean', cost: 80),
      isTrue,
    );
    expect(notifier.state.value!.coins, 20);
    expect(notifier.state.value!.boardSkinId, 'ocean');
    expect(notifier.state.value!.ownedBoardSkins, contains('ocean'));

    expect(
      await notifier.buyOrEquipCosmetic(slot: CosmeticSlot.board, id: 'classic', cost: 0),
      isTrue,
    );
    expect(notifier.state.value!.coins, 20);
    expect(notifier.state.value!.boardSkinId, 'classic');

    expect(
      await notifier.buyOrEquipCosmetic(slot: CosmeticSlot.board, id: 'ocean', cost: 80),
      isTrue,
    );
    expect(notifier.state.value!.coins, 20);
    expect(notifier.state.value!.boardSkinId, 'ocean');
  });

  test('addCoins מזכה מטבעות', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 10));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    await notifier.addCoins(25);
    expect(notifier.state.value?.coins, 35);
  });
}
