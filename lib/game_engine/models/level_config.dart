import 'package:equatable/equatable.dart';

/// "עולם" תמטי בקמפיין - קבוצת שלבים המשתפת גודל לוח, פלטת צבעים וקושי.
enum WorldTier {
  seedling, // 3x3
  sprout, // 4x4
  bloom, // 5x5
  forest, // 6x6
  summit, // 7x7 ומעלה
}

extension WorldTierX on WorldTier {
  String get titleHe {
    switch (this) {
      case WorldTier.seedling:
        return 'נבטים';
      case WorldTier.sprout:
        return 'ניצנים';
      case WorldTier.bloom:
        return 'פריחה';
      case WorldTier.forest:
        return 'היער הגדול';
      case WorldTier.summit:
        return 'פסגת המילים';
    }
  }

  int get gridSize {
    switch (this) {
      case WorldTier.seedling:
        return 3;
      case WorldTier.sprout:
        return 4;
      case WorldTier.bloom:
        return 5;
      case WorldTier.forest:
        return 6;
      case WorldTier.summit:
        return 7;
    }
  }
}

/// הגדרות שלב בודד בקמפיין יחיד-המשתתף.
class LevelConfig extends Equatable {
  final int levelNumber; // 1-based
  final WorldTier tier;
  final int gridSize;
  final Duration timeLimit;
  final int oneStarScore;
  final int twoStarScore;
  final int threeStarScore;
  final int minWordLength;

  const LevelConfig({
    required this.levelNumber,
    required this.tier,
    required this.gridSize,
    required this.timeLimit,
    required this.oneStarScore,
    required this.twoStarScore,
    required this.threeStarScore,
    this.minWordLength = 2,
  });

  @override
  List<Object?> get props => [
        levelNumber,
        tier,
        gridSize,
        timeLimit,
        oneStarScore,
        twoStarScore,
        threeStarScore,
        minWordLength,
      ];
}

/// בונה את רשימת השלבים המלאה של הקמפיין באופן דטרמיניסטי (פרוצדורלי),
/// כך שקל להוסיף עוד שלבים בעתיד רק ע"י שינוי הפרמטרים כאן.
class CampaignLevels {
  CampaignLevels._();

  static const int levelsPerWorldSeedling = 5;
  static const int levelsPerWorldSprout = 7;
  static const int levelsPerWorldBloom = 8;
  static const int levelsPerWorldForest = 10;

  static final List<LevelConfig> all = _build();

  static List<LevelConfig> _build() {
    final levels = <LevelConfig>[];
    int levelNumber = 1;

    void addWorld(WorldTier tier, int count, {required int baseTimeSec}) {
      for (int i = 0; i < count; i++) {
        final difficultyStep = i / (count - 1).clamp(1, 999);
        final timeSec = (baseTimeSec - (difficultyStep * 20)).round();
        final base = 20 + levelNumber * 6;
        levels.add(
          LevelConfig(
            levelNumber: levelNumber,
            tier: tier,
            gridSize: tier.gridSize,
            timeLimit: Duration(seconds: timeSec.clamp(45, 180)),
            oneStarScore: base,
            twoStarScore: (base * 1.8).round(),
            threeStarScore: (base * 2.6).round(),
          ),
        );
        levelNumber++;
      }
    }

    addWorld(WorldTier.seedling, levelsPerWorldSeedling, baseTimeSec: 90);
    addWorld(WorldTier.sprout, levelsPerWorldSprout, baseTimeSec: 110);
    addWorld(WorldTier.bloom, levelsPerWorldBloom, baseTimeSec: 130);
    addWorld(WorldTier.forest, levelsPerWorldForest, baseTimeSec: 150);
    // עולם "פסגה" עם 7x7 - מספר בלתי מוגבל, אינסופי (נבנה על פי דרישה).
    for (int i = 0; i < 10; i++) {
      final base = 20 + levelNumber * 6;
      levels.add(
        LevelConfig(
          levelNumber: levelNumber,
          tier: WorldTier.summit,
          gridSize: WorldTier.summit.gridSize,
          timeLimit: const Duration(seconds: 150),
          oneStarScore: base,
          twoStarScore: (base * 1.8).round(),
          threeStarScore: (base * 2.6).round(),
        ),
      );
      levelNumber++;
    }

    return levels;
  }

  static LevelConfig byLevelNumber(int levelNumber) {
    return all.firstWhere(
      (l) => l.levelNumber == levelNumber,
      orElse: () => all.last,
    );
  }
}
