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
///
/// המטרה של שלב היא **מספר מילים** (לא ניקוד) - [wordsRequired] - כדי
/// שהיעד יהיה מוחשי, ברור וקל להבנה ("מצאו 3 מילים!"). הכוכבים (ראו
/// [GameSession.currentStars] ב-lib/game_engine/game_session.dart) נגזרים
/// מהיחס בין מילים שנמצאו למילים שנדרשו, לא מניקוד.
class LevelConfig extends Equatable {
  final int levelNumber; // 1-based
  final WorldTier tier;
  final int gridSize;
  final Duration timeLimit;

  /// מספר המילים שצריך למצוא כדי "לעבור" את השלב (כוכב אחד לפחות).
  final int wordsRequired;
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
    required this.wordsRequired,
    this.minWordLength = 2,
    this.isMilestoneLevel = false,
  });

  /// יעדי המילים לכוכב 1/2/3 - יחסיים ל-[wordsRequired] (ראו
  /// [GameSession.starsForWordCount]): כוכב אחד = יעד המילים המלא, שני
  /// כוכבים = יעד וחצי, שלושה כוכבים = כפול היעד.
  int get oneStarWords => wordsRequired;
  int get twoStarWords => (wordsRequired * 1.5).ceil();
  int get threeStarWords => wordsRequired * 2;

  @override
  List<Object?> get props => [
        levelNumber,
        tier,
        gridSize,
        timeLimit,
        wordsRequired,
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

    void addWorld(WorldTier tier, int count) {
      for (int i = 0; i < count; i++) {
        final wordsRequired = wordsRequiredForLevel(levelNumber);
        levels.add(
          LevelConfig(
            levelNumber: levelNumber,
            tier: tier,
            gridSize: tier.gridSize,
            timeLimit: timeLimitForLevel(
              wordsRequired: wordsRequired,
              gridSize: tier.gridSize,
            ),
            wordsRequired: wordsRequired,
            // אבן-דרך = השלב הראשון של העולם, פרט לעולם הראשון עצמו
            // (שם אין "מעבר" קודם לחגוג).
            isMilestoneLevel: i == 0 && levelNumber > 1,
          ),
        );
        levelNumber++;
      }
    }

    addWorld(WorldTier.seedling, levelsInFirstTier);
    addWorld(WorldTier.sprout, levelsPerTier);
    addWorld(WorldTier.bloom, levelsPerTier);
    addWorld(WorldTier.forest, levelsPerTier);
    // עולם "פסגה" עם 7x7 - 10 שלבים אחרונים; גודל הלוח כבר לא עולה
    // מכאן והלאה, אז אין עוד אבני-דרך חדשות.
    for (int i = 0; i < 10; i++) {
      final wordsRequired = wordsRequiredForLevel(levelNumber);
      levels.add(
        LevelConfig(
          levelNumber: levelNumber,
          tier: WorldTier.summit,
          gridSize: WorldTier.summit.gridSize,
          timeLimit: timeLimitForLevel(
            wordsRequired: wordsRequired,
            gridSize: WorldTier.summit.gridSize,
          ),
          wordsRequired: wordsRequired,
          isMilestoneLevel: i == 0,
        ),
      );
      levelNumber++;
    }

    return levels;
  }

  /// מספר המילים הנדרש לעבור שלב - עולה בהדרגה כדי שהמטרה תישאר ברורה
  /// ומוחשית: שלב 1 = 3 מילים, שלב 2 = 4, ומשלב 3 והלאה נשאר לתמיד בטווח
  /// 5-7 (לא ממשיך לטפס לאינסוף), עם תנודה קלה בטווח הזה לפי מיקום השלב
  /// בתוך ה"עשירייה" שלו (ראו [positionWithinTier]) - כך שהקושי עדיין
  /// עולה בהדרגה בתוך כל עולם, בלי להפוך את המטרה לבלתי-מושגת.
  static int wordsRequiredForLevel(int levelNumber) {
    if (levelNumber == 1) return 3;
    if (levelNumber == 2) return 4;
    if (levelNumber == 3) return 5;
    if (levelNumber == 4) return 6;
    if (levelNumber == 5) return 7;

    final position = positionWithinTier(levelNumber);
    final blockSize = tierBlockSize(levelNumber);
    final t = blockSize <= 1 ? 0.0 : position / (blockSize - 1);
    return (5 + t * 2).round().clamp(5, 7);
  }

  /// זמן השלב - קצר וברור, נגזר ממספר המילים הנדרש ומגודל הלוח (לוח
  /// גדול יותר דורש קצת יותר זמן חיפוש), תמיד בטווח סביר (30-110 שניות)
  /// כדי שהטיימר יישאר ברור ולא "יימשך" יותר מהצורך.
  static Duration timeLimitForLevel({required int wordsRequired, required int gridSize}) {
    final seconds = 25 + wordsRequired * 7 + (gridSize - 3) * 5;
    return Duration(seconds: seconds.clamp(30, 110));
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
