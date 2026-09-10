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

  /// true אם זה שלב "אבן דרך" - השלב הראשון בעולם חדש (גודל לוח שגדל
  /// לעומת השלב הקודם), שבו מציגים חגיגת "עולם חדש נפתח!" ופרס נדיב
  /// (ראו lib/features/game/level_result_screen.dart).
  final bool isMilestoneLevel;

  const LevelConfig({
    required this.levelNumber,
    required this.tier,
    required this.gridSize,
    required this.timeLimit,
    required this.oneStarScore,
    required this.twoStarScore,
    required this.threeStarScore,
    this.minWordLength = 2,
    this.isMilestoneLevel = false,
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
        isMilestoneLevel,
      ];
}

/// בונה את רשימת השלבים המלאה של הקמפיין באופן דטרמיניסטי (פרוצדורלי),
/// כך שקל להוסיף עוד שלבים בעתיד רק ע"י שינוי הפרמטרים כאן.
///
/// מבנה "אבני דרך" קבוע: כל 10 שלבים גודל הלוח עולה בדרגה אחת ומוצגת
/// חגיגת "עולם חדש נפתח!" (ראו [LevelConfig.isMilestoneLevel]) -
/// שלבים 1-9 = 3×3 ("נבטים"), 10-19 = 4×4 ("ניצנים"), 20-29 = 5×5
/// ("פריחה"), 30-39 = 6×6 ("היער הגדול"), 40 ומעלה = 7×7 ("פסגת המילים",
/// שם גודל הלוח נשאר קבוע - זו התקרה הגרפית/דיקדוקית הנוכחית של המשחק).
/// העולם הראשון קצר ב-1 שלב (9 ולא 10) בכוונה, כדי ששלב 10 עצמו - בדיוק
/// כפי שהתבקש - יהיה שלב האבן-דרך הראשון (המעבר ל-4×4).
class CampaignLevels {
  CampaignLevels._();

  static const int levelsInFirstTier = 9;
  static const int levelsPerTier = 10;

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
            // אבן-דרך = השלב הראשון של העולם, פרט לעולם הראשון עצמו
            // (שם אין "מעבר" קודם לחגוג).
            isMilestoneLevel: i == 0 && levelNumber > 1,
          ),
        );
        levelNumber++;
      }
    }

    addWorld(WorldTier.seedling, levelsInFirstTier, baseTimeSec: 90);
    addWorld(WorldTier.sprout, levelsPerTier, baseTimeSec: 110);
    addWorld(WorldTier.bloom, levelsPerTier, baseTimeSec: 130);
    addWorld(WorldTier.forest, levelsPerTier, baseTimeSec: 150);
    // עולם "פסגה" עם 7x7 - מספר בלתי מוגבל, אינסופי (נבנה על פי דרישה).
    // גודל הלוח כבר לא עולה מכאן והלאה, אז אין עוד אבני-דרך חדשות.
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
          isMilestoneLevel: i == 0,
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

  /// המיקום (0-מבוסס) של השלב בתוך "עשיריית" העולם הנוכחי שלו - 0 עבור
  /// השלב הראשון/הכי-קל של העולם, ועד 9 (או 8 בעולם הראשון) עבור השלב
  /// האחרון/הכי-קשה. משמש לקביעת פרופיל הקושי של בניית הלוח (ראו
  /// lib/game_engine/level_board_builder.dart).
  static int positionWithinTier(int levelNumber) {
    if (levelNumber <= levelsInFirstTier) return levelNumber - 1;
    return (levelNumber - levelsInFirstTier - 1) % levelsPerTier;
  }

  /// גודל ה"עשיריה" שהשלב הנתון שייך אליה (9 בעולם הראשון, 10 בכל השאר) -
  /// משמש לנרמל את [positionWithinTier] לטווח 0..1.
  static int tierBlockSize(int levelNumber) {
    return levelNumber <= levelsInFirstTier ? levelsInFirstTier : levelsPerTier;
  }
}
