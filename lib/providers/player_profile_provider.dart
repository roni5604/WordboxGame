import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/level_progress.dart';
import '../data/models/player_profile.dart';
import '../data/repositories/progress_repository.dart';
import 'repository_providers.dart';

/// תוצאה של תביעת בונוס הרמזים היומי - יום נוכחי במחזור (1-7) ומספר
/// הרמזים שהוענקו, כדי שהממשק יוכל להציג פופ-אפ חגיגי "יום X! +Y רמזים".
class DailyHintReward {
  final int day;
  final int hintsAwarded;

  const DailyHintReward({required this.day, required this.hintsAwarded});
}

String _todayKey() {
  final now = DateTime.now();
  return '${now.year.toString().padLeft(4, '0')}-'
      '${now.month.toString().padLeft(2, '0')}-'
      '${now.day.toString().padLeft(2, '0')}';
}

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
  Future<void> setAvatarId(String avatarId) =>
      _mutate((c) => c.copyWith(avatarId: avatarId));

  Future<void> resetProgress() async {
    await _mutate((_) => const PlayerProfile());
  }

  /// בודק אם השחקן כבר תבע את בונוס הרמזים היומי היום, ואם לא - מזכה
  /// אותו ומקדם את מונה הרצף (1..7, מתאפס חזרה ל-1 אחרי יום 7).
  /// מחזיר את פרטי הזיכוי כדי שהממשק יציג פופ-אפ, או null אם כבר נתבע היום.
  Future<DailyHintReward?> claimDailyHintIfAvailable() async {
    final current = state.valueOrNull;
    if (current == null) return null;

    final today = _todayKey();
    if (current.lastHintClaimDate == today) return null;

    final nextDay = current.hintStreakDay >= 7 ? 1 : current.hintStreakDay + 1;
    await _mutate((c) => c.copyWith(
          hints: c.hints + nextDay,
          hintStreakDay: nextDay,
          lastHintClaimDate: today,
        ));

    return DailyHintReward(day: nextDay, hintsAwarded: nextDay);
  }

  /// צורך רמז אחד (למשל בעת שימוש ברמז במהלך שלב). מחזיר false אם אין
  /// לשחקן מספיק רמזים.
  Future<bool> useHint() async {
    final current = state.valueOrNull;
    if (current == null || current.hints <= 0) return false;
    await _mutate((c) => c.copyWith(hints: c.hints - 1));
    return true;
  }

  /// קונה [amount] רמזים תמורת [cost] מטבעות (בחנות). מחזיר false אם אין
  /// מספיק מטבעות.
  Future<bool> buyHints({required int amount, required int cost}) async {
    final current = state.valueOrNull;
    if (current == null || current.coins < cost) return false;
    await _mutate((c) => c.copyWith(coins: c.coins - cost, hints: c.hints + amount));
    return true;
  }
}

final playerProfileProvider =
    StateNotifierProvider<PlayerProfileNotifier, AsyncValue<PlayerProfile>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return PlayerProfileNotifier(repo);
});
