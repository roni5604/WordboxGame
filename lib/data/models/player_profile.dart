import 'package:equatable/equatable.dart';

import 'level_progress.dart';

/// מצב ההתקדמות הכולל של השחקן - נשמר מקומית (Hive), ובעתיד גם מסונכרן
/// ל-Firestore (ראו lib/data/repositories/firebase_progress_repository.dart).
class PlayerProfile extends Equatable {
  final Map<int, LevelProgress> levelProgress;
  final int coins;
  final int highestUnlockedLevel;
  final bool soundOn;
  final bool hapticsOn;
  final bool onboardingCompleted;
  final String displayName;

  const PlayerProfile({
    this.levelProgress = const {},
    this.coins = 0,
    this.highestUnlockedLevel = 1,
    this.soundOn = true,
    this.hapticsOn = true,
    this.onboardingCompleted = false,
    this.displayName = 'שחקן/ית',
  });

  int get totalStars => levelProgress.values.fold(0, (sum, p) => sum + p.stars);

  bool isLevelUnlocked(int levelNumber) => levelNumber <= highestUnlockedLevel;

  LevelProgress progressFor(int levelNumber) =>
      levelProgress[levelNumber] ?? LevelProgress(levelNumber: levelNumber);

  PlayerProfile copyWith({
    Map<int, LevelProgress>? levelProgress,
    int? coins,
    int? highestUnlockedLevel,
    bool? soundOn,
    bool? hapticsOn,
    bool? onboardingCompleted,
    String? displayName,
  }) {
    return PlayerProfile(
      levelProgress: levelProgress ?? this.levelProgress,
      coins: coins ?? this.coins,
      highestUnlockedLevel: highestUnlockedLevel ?? this.highestUnlockedLevel,
      soundOn: soundOn ?? this.soundOn,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      displayName: displayName ?? this.displayName,
    );
  }

  @override
  List<Object?> get props => [
        levelProgress,
        coins,
        highestUnlockedLevel,
        soundOn,
        hapticsOn,
        onboardingCompleted,
        displayName,
      ];
}
