import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/level_progress.dart';
import '../data/models/player_profile.dart';
import '../data/repositories/progress_repository.dart';
import 'repository_providers.dart';

class PlayerProfileNotifier extends StateNotifier<AsyncValue<PlayerProfile>> {
  final ProgressRepository _repository;
  late final Future<void> _initialLoad;

  PlayerProfileNotifier(this._repository) : super(const AsyncValue.loading()) {
    _initialLoad = _load();
  }

  Future<void> _load() async {
    try {
      final profile = await _repository.loadProfile();
      state = AsyncValue.data(profile);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// ממתין לטעינה הראשונית של הפרופיל ומחזיר אותו (או ברירת מחדל אם נכשל).
  /// שימושי במסך הפתיחה כדי לדעת לאן לנתב את המשתמש/ת.
  Future<PlayerProfile> ensureLoaded() async {
    await _initialLoad;
    return state.valueOrNull ?? const PlayerProfile();
  }

  Future<void> _mutate(PlayerProfile Function(PlayerProfile current) mutator) async {
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = mutator(current);
    state = AsyncValue.data(updated);
    await _repository.saveProfile(updated);
  }

  /// מעדכן התקדמות לאחר סיום שלב: כוכבים, ניקוד שיא, ופתיחת השלב הבא.
  Future<void> completeLevel({
    required int levelNumber,
    required int stars,
    required int score,
    required int coinsEarned,
  }) async {
    await _mutate((current) {
      final existing = current.progressFor(levelNumber);
      final updatedProgress = existing.copyWith(
        stars: stars > existing.stars ? stars : existing.stars,
        bestScore: score > existing.bestScore ? score : existing.bestScore,
        completed: true,
      );
      final newLevelMap = Map<int, LevelProgress>.from(current.levelProgress)
        ..[levelNumber] = updatedProgress;

      final newHighestUnlocked = levelNumber + 1 > current.highestUnlockedLevel
          ? levelNumber + 1
          : current.highestUnlockedLevel;

      return current.copyWith(
        levelProgress: newLevelMap,
        highestUnlockedLevel: newHighestUnlocked,
        coins: current.coins + coinsEarned,
      );
    });
  }

  Future<void> setSoundOn(bool value) => _mutate((c) => c.copyWith(soundOn: value));
  Future<void> setHapticsOn(bool value) => _mutate((c) => c.copyWith(hapticsOn: value));
  Future<void> setOnboardingCompleted() =>
      _mutate((c) => c.copyWith(onboardingCompleted: true));
  Future<void> setDisplayName(String name) => _mutate((c) => c.copyWith(displayName: name));

  Future<void> resetProgress() async {
    await _mutate((_) => const PlayerProfile());
  }
}

final playerProfileProvider =
    StateNotifierProvider<PlayerProfileNotifier, AsyncValue<PlayerProfile>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return PlayerProfileNotifier(repo);
});
