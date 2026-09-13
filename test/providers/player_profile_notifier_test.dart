import 'package:flutter_test/flutter_test.dart';
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

  test('addCoins מזכה מטבעות', () async {
    final repo = _MemoryProgressRepository(const PlayerProfile(coins: 10));
    final notifier = PlayerProfileNotifier(repo);
    await notifier.ensureLoaded();

    await notifier.addCoins(25);
    expect(notifier.state.value?.coins, 35);
  });
}
