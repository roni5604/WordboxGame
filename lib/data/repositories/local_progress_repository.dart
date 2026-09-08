import 'package:hive_flutter/hive_flutter.dart';

import '../models/level_progress.dart';
import '../models/player_profile.dart';
import 'progress_repository.dart';

/// מימוש מקומי (Hive) של [ProgressRepository] - האחסון שעליו האפליקציה
/// רצה כברירת מחדל, כך שהמשחק היחיד-שחקן עובד לגמרי אופליין וללא חשבון.
class LocalProgressRepository implements ProgressRepository {
  static const String boxName = 'wordbox_progress';

  Box? _box;

  Future<Box> _openBox() async {
    return _box ??= await Hive.openBox(boxName);
  }

  @override
  Future<PlayerProfile> loadProfile() async {
    final box = await _openBox();

    final rawStars = Map<dynamic, dynamic>.from(
      box.get('level_stars', defaultValue: <dynamic, dynamic>{}) as Map,
    );
    final rawBestScore = Map<dynamic, dynamic>.from(
      box.get('level_best_score', defaultValue: <dynamic, dynamic>{}) as Map,
    );
    final rawCompleted = Map<dynamic, dynamic>.from(
      box.get('level_completed', defaultValue: <dynamic, dynamic>{}) as Map,
    );

    final levelNumbers = <int>{
      ...rawStars.keys.map((k) => int.parse(k.toString())),
      ...rawBestScore.keys.map((k) => int.parse(k.toString())),
    };

    final levelProgress = <int, LevelProgress>{
      for (final level in levelNumbers)
        level: LevelProgress(
          levelNumber: level,
          stars: (rawStars[level.toString()] as int?) ?? 0,
          bestScore: (rawBestScore[level.toString()] as int?) ?? 0,
          completed: (rawCompleted[level.toString()] as bool?) ?? false,
        ),
    };

    return PlayerProfile(
      levelProgress: levelProgress,
      coins: box.get('coins', defaultValue: 0) as int,
      highestUnlockedLevel: box.get('highest_unlocked_level', defaultValue: 1) as int,
      soundOn: box.get('sound_on', defaultValue: true) as bool,
      hapticsOn: box.get('haptics_on', defaultValue: true) as bool,
      onboardingCompleted: box.get('onboarding_completed', defaultValue: false) as bool,
      displayName: box.get('display_name', defaultValue: 'שחקן/ית') as String,
    );
  }

  @override
  Future<void> saveProfile(PlayerProfile profile) async {
    final box = await _openBox();

    final starsMap = <String, int>{
      for (final e in profile.levelProgress.entries) e.key.toString(): e.value.stars,
    };
    final bestScoreMap = <String, int>{
      for (final e in profile.levelProgress.entries) e.key.toString(): e.value.bestScore,
    };
    final completedMap = <String, bool>{
      for (final e in profile.levelProgress.entries) e.key.toString(): e.value.completed,
    };

    await box.putAll({
      'level_stars': starsMap,
      'level_best_score': bestScoreMap,
      'level_completed': completedMap,
      'coins': profile.coins,
      'highest_unlocked_level': profile.highestUnlockedLevel,
      'sound_on': profile.soundOn,
      'haptics_on': profile.hapticsOn,
      'onboarding_completed': profile.onboardingCompleted,
      'display_name': profile.displayName,
    });
  }
}
