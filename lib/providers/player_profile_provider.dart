import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/cosmetics/cosmetic_catalog.dart';
import '../data/models/auth_user.dart';
import '../data/models/level_progress.dart';
import '../data/models/player_profile.dart';
import '../data/repositories/progress_repository.dart';
import '../game_engine/rewards/reward_tables.dart';
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
    await _initialLoad;
    final current = state.valueOrNull;
    if (current == null) return;
    final updated = mutator(current);
    state = AsyncValue.data(updated);
    await _repository.saveProfile(updated);
  }

  /// true אם השלב הנתון עדיין לא סומן כ"הושלם" בפרופיל הנוכחי - שימושי
  /// כדי להעניק תגמולים חד-פעמיים (תיבת מזל/גלגל מזל) רק בפעם הראשונה
  /// שמשלימים שלב נתון, לא בכל שיחזור שלו. ראו lib/features/game/game_screen.dart.
  bool isFirstCompletion(int levelNumber) {
    final current = state.valueOrNull;
    if (current == null) return true;
    return !current.progressFor(levelNumber).completed;
  }

  /// מעדכן התקדמות לאחר סיום שלב: כוכבים, ניקוד שיא, ופתיחת השלב הבא.
  /// השלב הבא נפתח רק עם כוכב אחד לפחות. שיא ניקוד נשמר גם בכישלון,
  /// בלי לנעול שלבים שכבר נפתחו ובלי להוריד כוכבים קיימים.
  /// בונוס "מטבעות כפולות" יורד רק כשהשלב באמת הושלם.
  /// מחזיר את כמות המטבעות שנזקפו בפועל (אחרי הכפלה, אם הייתה).
  Future<int> completeLevel({
    required int levelNumber,
    required int stars,
    required int score,
    required int coinsEarned,
  }) async {
    int actualCoinsEarned = 0;
    await _mutate((current) {
      final existing = current.progressFor(levelNumber);
      final passed = stars >= 1;
      final updatedProgress = existing.copyWith(
        stars: stars > existing.stars ? stars : existing.stars,
        bestScore: score > existing.bestScore ? score : existing.bestScore,
        completed: existing.completed || passed,
      );
      final newLevelMap = Map<int, LevelProgress>.from(current.levelProgress)
        ..[levelNumber] = updatedProgress;

      final newHighestUnlocked = passed && levelNumber + 1 > current.highestUnlockedLevel
          ? levelNumber + 1
          : current.highestUnlockedLevel;

      final hasDoubleCoinsBuff = passed && current.doubleCoinsLevelsRemaining > 0;
      actualCoinsEarned = passed
          ? (hasDoubleCoinsBuff ? coinsEarned * 2 : coinsEarned)
          : 0;
      final newBuffRemaining =
          hasDoubleCoinsBuff ? current.doubleCoinsLevelsRemaining - 1 : current.doubleCoinsLevelsRemaining;

      return current.copyWith(
        levelProgress: newLevelMap,
        highestUnlockedLevel: newHighestUnlocked,
        coins: current.coins + actualCoinsEarned,
        doubleCoinsLevelsRemaining: newBuffRemaining,
      );
    });
    return actualCoinsEarned;
  }

  /// מדלג על שלב תמורת מטבעות: כוכב אחד, השלמה, ופתיחת השלב הבא.
  /// בלי פרס מטבעות נוסף. מחזיר false אם אין מספיק מטבעות.
  Future<bool> skipLevel({required int levelNumber, required int cost}) async {
    final current = state.valueOrNull;
    if (current == null || cost < 0 || current.coins < cost) return false;
    await _mutate((c) {
      final existing = c.progressFor(levelNumber);
      final updated = existing.copyWith(
        stars: existing.stars < 1 ? 1 : existing.stars,
        completed: true,
      );
      final newLevelMap = Map<int, LevelProgress>.from(c.levelProgress)
        ..[levelNumber] = updated;
      final next = levelNumber + 1;
      return c.copyWith(
        levelProgress: newLevelMap,
        highestUnlockedLevel:
            next > c.highestUnlockedLevel ? next : c.highestUnlockedLevel,
        coins: c.coins - cost,
      );
    });
    return true;
  }

  /// מזכה פרס מ"תיבת מזל" (ראו lib/game_engine/rewards/reward_tables.dart) -
  /// מטבעות, ולעיתים גם רמז/ים.
  Future<void> grantLuckyBoxReward(LuckyBoxReward reward) => _mutate(
        (c) => c.copyWith(coins: c.coins + reward.coins, hints: c.hints + reward.hints),
      );

  /// מזכה פרס מגלגל המזל - מטבעות ו/או רמזים ו/או בונוס "מטבעות כפולות"
  /// לכמה שלבים הבאים (מצטבר עם בונוס קיים, אם יש).
  Future<void> grantWheelPrize(FortuneWheelPrize prize) => _mutate(
        (c) => c.copyWith(
          coins: c.coins + prize.coins,
          hints: c.hints + prize.hints,
          doubleCoinsLevelsRemaining:
              c.doubleCoinsLevelsRemaining + prize.doubleCoinsLevels,
        ),
      );

  Future<void> setSoundOn(bool value) => _mutate((c) => c.copyWith(soundOn: value));
  Future<void> setHapticsOn(bool value) => _mutate((c) => c.copyWith(hapticsOn: value));
  Future<void> setOnboardingCompleted() =>
      _mutate((c) => c.copyWith(onboardingCompleted: true));
  Future<void> setDisplayName(String name) => _mutate((c) => c.copyWith(displayName: name));
  Future<void> setAvatarId(String avatarId) =>
      _mutate((c) => c.copyWith(avatarId: avatarId));
  Future<void> setAuthIntroShown() =>
      _mutate((c) => c.copyWith(authIntroShown: true));

  /// מסמן שההדרכה המוטבעת של שלב 1 הוצגה, כדי שלא תוצג שוב במשחקים חוזרים.
  Future<void> setLevel1TutorialSeen() =>
      _mutate((c) => c.copyWith(level1TutorialSeen: true));

  /// מזכה מספר רמזי מתנה (למשל בונוס אבן-דרך) - בלי לגרוע ממטבעות, בשונה
  /// מ-[buyHints] שנועד לקנייה בחנות.
  Future<void> grantHints(int amount) =>
      _mutate((c) => c.copyWith(hints: c.hints + amount));

  /// מסנכרן את שם התצוגה מספק ההתחברות (Google/Apple/Facebook/מייל) לתוך
  /// הפרופיל המקומי - נקרא אוטומטית מיד אחרי כל התחברות מוצלחת לחשבון
  /// אמיתי (לא אורח/ת), כך שהשם במשחק תמיד ישקף את החשבון המחובר. תמונת
  /// הפרופיל (photoUrl) לא נשמרת כאן - היא נלקחת "חיה" מ-authStateProvider
  /// בכל מקום שמציג אוואטאר, כדי שתמיד תהיה עדכנית בלי צורך בסנכרון נוסף.
  Future<void> syncFromAuthUser(AuthUser user) async {
    if (user.isAnonymous) return;
    final name = user.displayName?.trim();
    if (name == null || name.isEmpty) return;
    await _mutate((c) => c.displayName == name ? c : c.copyWith(displayName: name));
  }

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

  /// קונה סקין במטבעות ומצייד אותו. אם כבר בבעלות, רק מצייד בלי לחייב.
  /// מחזיר false אם אין מספיק מטבעות.
  Future<bool> buyOrEquipCosmetic({
    required CosmeticSlot slot,
    required String id,
    required int cost,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return false;
    final alreadyOwned = current.ownedFor(slot.name).contains(id);
    if (!alreadyOwned && current.coins < cost) return false;
    await _mutate((c) {
      final owned = List<String>.from(c.ownedFor(slot.name));
      if (!owned.contains(id)) owned.add(id);
      final coins = alreadyOwned ? c.coins : c.coins - cost;
      switch (slot) {
        case CosmeticSlot.letter:
          return c.copyWith(coins: coins, letterSkinId: id, ownedLetterSkins: owned);
        case CosmeticSlot.marker:
          return c.copyWith(coins: coins, markerSkinId: id, ownedMarkerSkins: owned);
        case CosmeticSlot.board:
          return c.copyWith(coins: coins, boardSkinId: id, ownedBoardSkins: owned);
      }
    });
    return true;
  }

  /// מזכה חבילה שנקנתה בכסף אמיתי (מטבעות ו/או רמזים).
  Future<void> grantRealMoneyReward({int coins = 0, int hints = 0}) async {
    if (coins <= 0 && hints <= 0) return;
    await _mutate((c) => c.copyWith(coins: c.coins + coins, hints: c.hints + hints));
  }

  /// קונה [amount] רמזים תמורת [cost] מטבעות (בחנות). מחזיר false אם אין
  /// מספיק מטבעות.
  Future<bool> buyHints({required int amount, required int cost}) async {
    final current = state.valueOrNull;
    if (current == null || current.coins < cost) return false;
    await _mutate((c) => c.copyWith(coins: c.coins - cost, hints: c.hints + amount));
    return true;
  }

  /// גורע מטבעות (דמי כניסה לחדר פרטי). מחזיר false אם אין מספיק.
  Future<bool> spendCoins(int amount) async {
    if (amount <= 0) return true;
    final current = state.valueOrNull;
    if (current == null || current.coins < amount) return false;
    await _mutate((c) => c.copyWith(coins: c.coins - amount));
    return true;
  }

  /// מזכה מטבעות (החזר מיציאת לובי, או קופה לזוכה בסיום סדרה).
  Future<void> addCoins(int amount) async {
    if (amount <= 0) return;
    await _mutate((c) => c.copyWith(coins: c.coins + amount));
  }
}

final playerProfileProvider =
    StateNotifierProvider<PlayerProfileNotifier, AsyncValue<PlayerProfile>>((ref) {
  final repo = ref.watch(progressRepositoryProvider);
  return PlayerProfileNotifier(repo);
});
