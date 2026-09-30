import 'package:equatable/equatable.dart';

/// "עולם" תמטי בקמפיין - קבוצת שלבים המשתפת גודל לוח, פלטת צבעים וקושי.
///
/// שלב א' של המשחק (ראו [CampaignLevels]) משתמש רק ב-4 העולמות הראשונים
/// (נבטים..היער הגדול, 100 שלבים). "פסגת המילים" (7×7) שמור בכוונה
/// לעולם החמישי העתידי - הוספתו תדרוש רק שורת `WorldTier.summit` נוספת
/// ברשימת [CampaignLevels.worldOrder], בלי שינוי מבני נוסף.
enum WorldTier {
  seedling, // 3x3
  sprout, // 4x4
  bloom, // 5x5
  forest, // 6x6
  summit, // 7x7 ומעלה - עולם עתידי, לא בשימוש עדיין ב-CampaignLevels.all
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

/// סוג שלב בתוך העולם שלו - קובע קושי-על, ניסוח חגיגה ותגמול:
///
/// - [normal]: שלב רגיל.
/// - [master]: "שלב מאסטר" - מופיע כמה פעמים בכל עולם (ראו
///   [CampaignLevels.masterCadence]), עם לוח קשה יותר וזמן קצר יותר
///   מהבייסליין השוטף של אותו רגע במשחק, ותגמול מטבעות כפול.
/// - [worldFinale]: השלב האחרון של העולם - הקשה ביותר בעולם, פותח את
///   העולם הבא, ומפעיל גם חגיגת "עולם חדש נפתח!" וגם סיבוב גלגל מזל
///   (ראו lib/features/game/level_result_screen.dart).
enum LevelKind { normal, master, worldFinale }

/// הגדרות שלב בודד בקמפיין יחיד-המשתתף.
///
/// המטרה של שלב היא **ניקוד** - [scoreRequired]. מילה קצרה שווה מעט
/// נקודות ומילה ארוכה שווה הרבה יותר (ראו [scoreForWordLength]).
/// הכוכבים (ראו [GameSession.currentStars]) נגזרים מהיחס בין הניקוד
/// שנצבר ליעד: שליש = כוכב, שני שלישים = שני כוכבים, היעד המלא = שלושה.
/// השלב מסתיים ברגע שמגיעים ליעד הניקוד, גם אם נשאר זמן. בלי כוכב אחד
/// לפחות השלב הבא נשאר נעול.
class LevelConfig extends Equatable {
  final int levelNumber; // 1-based
  final WorldTier tier;
  final int gridSize;
  final Duration timeLimit;

  /// ניקוד שצריך לצבור כדי לסיים את השלב בשלושה כוכבים.
  final int scoreRequired;
  final int minWordLength;

  /// סוג השלב - רגיל / מאסטר / פינאלה של עולם (ראו [LevelKind]).
  final LevelKind kind;

  const LevelConfig({
    required this.levelNumber,
    required this.tier,
    required this.gridSize,
    required this.timeLimit,
    required this.scoreRequired,
    this.minWordLength = 2,
    this.kind = LevelKind.normal,
  });

  bool get isMasterLevel => kind == LevelKind.master;

  /// true אם זה שלב "פינאלה" - השלב האחרון בעולם, שבו מציגים חגיגת
  /// "עולם חדש נפתח!" + סיבוב גלגל מזל, ומעניקים פרס נדיב (ראו
  /// lib/features/game/level_result_screen.dart).
  bool get isWorldFinale => kind == LevelKind.worldFinale;

  /// יעדי הניקוד לכוכב 1/2/3 - מחלקים את [scoreRequired] לשלישים (ראו
  /// [GameSession.starsForScore]): כל שליש מהיעד שווה כוכב, ושלושה
  /// כוכבים מתקבלים בדיוק כשמגיעים ליעד הניקוד המלא - ואז השלב מסתיים
  /// באותו רגע, גם אם נשאר זמן על השעון.
  int get oneStarScore => (scoreRequired / 3).ceil();
  int get twoStarScore => (scoreRequired * 2 / 3).ceil();
  int get threeStarScore => scoreRequired;

  @override
  List<Object?> get props => [
        levelNumber,
        tier,
        gridSize,
        timeLimit,
        scoreRequired,
        minWordLength,
        kind,
      ];
}

/// בונה את רשימת השלבים המלאה של הקמפיין באופן דטרמיניסטי (פרוצדורלי),
/// כך שקל להוסיף עוד שלבים/עולמות בעתיד רק ע"י הרחבת [worldOrder].
///
/// מבנה קבוע: כל עולם מכיל בדיוק [levelsPerWorld] שלבים. בתוך כל עולם,
/// כל [masterCadence]-י שלב הוא "שלב מאסטר" (קשה יותר מהבייסליין השוטף,
/// תגמול כפול), והשלב האחרון של העולם הוא "פינאלה" (הקשה ביותר, פותח את
/// העולם הבא + גלגל מזל). ראו [LevelKind].
///
/// שלב א' נוכחי: 4 עולמות × 25 שלבים = 100 שלבים (נבטים 3×3, ניצנים 4×4,
/// פריחה 5×5, היער הגדול 6×6). הקושי (ראו [scoreRequiredForLevel] ו-
/// [BoardDifficultyProfile.forLevel] ב-lib/game_engine/level_board_builder.dart)
/// עולה **בהדרגה על פני כל המשחק** (לא מתאפס בתחילת כל עולם) כדי שההתקדמות
/// תישאר משמעותית ולא תרגיש כמו "איפוס" בכל עולם חדש.
class CampaignLevels {
  CampaignLevels._();

  /// מספר קבוע של שלבים בכל עולם - גם לצורך קביעת קושי (ראו
  /// [globalProgress]) וגם לצורך תדירות שלבי מאסטר/פינאלה.
  static const int levelsPerWorld = 25;

  /// כל [masterCadence] שלבים בתוך עולם (1-מבוסס) הוא שלב מאסטר, פרט
  /// לשלב האחרון של העולם עצמו (שהוא פינאלה, לא מאסטר). בעולם בן 25
  /// שלבים זה נותן 4 שלבי מאסטר (6, 12, 18, 24) + פינאלה אחת (25).
  static const int masterCadence = 6;

  /// יעד ניקוד לתחרויות רב-משתתפים, שנגמרות לפי שעון ולא לפי יעד שלב.
  /// גבוה מספיק כדי שסשן תחרות לא ייסגר מוקדם אם מישהו בודק את היעד.
  static const int raceScoreGoal = 1000000;

  /// תחילת וסוף עקומת הניקוד לכל עולם (שלב רגיל, לפני בונוס מאסטר/פינאלה).
  static const List<int> _worldScoreStart = [9, 26, 50, 80];
  static const List<int> _worldScoreEnd = [22, 45, 75, 120];

  /// סדר העולמות הפעילים כרגע. הוספת עולם נוסף בעתיד (למשל
  /// [WorldTier.summit], 7×7) היא שינוי של שורה אחת כאן בלבד.
  static const List<WorldTier> worldOrder = [
    WorldTier.seedling,
    WorldTier.sprout,
    WorldTier.bloom,
    WorldTier.forest,
  ];

  static final List<LevelConfig> all = _build();

  static int get totalLevels => worldOrder.length * levelsPerWorld;

  static List<LevelConfig> _build() {
    final levels = <LevelConfig>[];
    int levelNumber = 1;

    for (final tier in worldOrder) {
      for (int position = 1; position <= levelsPerWorld; position++) {
        final kind = _kindForPosition(position);
        final scoreRequired = scoreRequiredForLevel(levelNumber, kind: kind);
        levels.add(
          LevelConfig(
            levelNumber: levelNumber,
            tier: tier,
            gridSize: tier.gridSize,
            timeLimit: timeLimitForLevel(
              scoreRequired: scoreRequired,
              gridSize: tier.gridSize,
              kind: kind,
            ),
            scoreRequired: scoreRequired,
            kind: kind,
          ),
        );
        levelNumber++;
      }
    }

    return levels;
  }

  static LevelKind _kindForPosition(int position) {
    if (position == levelsPerWorld) return LevelKind.worldFinale;
    if (position % masterCadence == 0) return LevelKind.master;
    return LevelKind.normal;
  }

  /// התקדמות גלובלית מנורמלת (0..1) על פני **כל** שלבי הקמפיין - 0 עבור
  /// השלב הראשון, 1.0 עבור השלב האחרון. זה הבסיס לעקומת הקושי הרציפה
  /// (מילים נדרשות, זמן, פרופיל קושי הלוח) שלא מתאפסת בתחילת כל עולם.
  static double globalProgress(int levelNumber) {
    final total = totalLevels;
    if (total <= 1) return 0;
    return ((levelNumber - 1) / (total - 1)).clamp(0.0, 1.0);
  }

  /// המיקום (1-מבוסס) של השלב בתוך העולם שלו - 1 עבור השלב הראשון/הקל
  /// ביותר של העולם, ועד [levelsPerWorld] (הפינאלה) עבור השלב האחרון.
  static int positionWithinWorld(int levelNumber) {
    return ((levelNumber - 1) % levelsPerWorld) + 1;
  }

  /// ניקוד היעד של שלב. בכל עולם העקומה עולה לאט מתחילת הטווח לסופו
  /// (3×3: 9–22, 4×4: 26–45, 5×5: 50–75, 6×6: 80–120). שלב מאסטר מקבל
  /// כ-20% יותר, ופינאלה כ-30% יותר, כדי שהם יורגשו קשים יותר.
  static int scoreRequiredForLevel(int levelNumber, {LevelKind kind = LevelKind.normal}) {
    final worldIndex =
        ((levelNumber - 1) ~/ levelsPerWorld).clamp(0, _worldScoreStart.length - 1);
    final position = positionWithinWorld(levelNumber);
    final start = _worldScoreStart[worldIndex];
    final end = _worldScoreEnd[worldIndex];
    final span = levelsPerWorld - 1;
    final t = span == 0 ? 0.0 : (position - 1) / span;
    final base = (start + (end - start) * t).round();
    final multiplier = switch (kind) {
      LevelKind.master => 1.2,
      LevelKind.worldFinale => 1.3,
      LevelKind.normal => 1.0,
    };
    return (base * multiplier).round();
  }

  /// זמן השלב - קצר וברור, עם מרווח נוח כדי שיעד הניקוד יישאר בהישג
  /// בלי למהר. נגזר מיעד הניקוד (בערך כאילו כל 3 נקודות הן "מילה")
  /// ומגודל הלוח, ומעוגל לעשרות שניות. שלבי מאסטר ופינאלה מקבלים פחות
  /// זמן יחסית לבייסליין (15%-20% פחות).
  static Duration timeLimitForLevel({
    required int scoreRequired,
    required int gridSize,
    LevelKind kind = LevelKind.normal,
  }) {
    final wordEquivalent = (scoreRequired / 3).round();
    final rawSeconds = 30 + wordEquivalent * 9 + (gridSize - 3) * 6;
    double multiplier = 1.0;
    if (kind == LevelKind.master) multiplier = 0.85;
    if (kind == LevelKind.worldFinale) multiplier = 0.8;
    final adjustedSeconds = rawSeconds * multiplier;
    final rounded = ((adjustedSeconds / 10).round() * 10);
    return Duration(seconds: rounded.clamp(30, 150));
  }

  static LevelConfig byLevelNumber(int levelNumber) {
    return all.firstWhere(
      (l) => l.levelNumber == levelNumber,
      orElse: () => all.last,
    );
  }
}
