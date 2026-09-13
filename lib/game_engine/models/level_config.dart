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
/// המטרה של שלב היא **מספר מילים** (לא ניקוד) - [wordsRequired] - כדי
/// שהיעד יהיה מוחשי, ברור וקל להבנה ("מצאו 3 מילים!"). הכוכבים (ראו
/// [GameSession.currentStars] ב-lib/game_engine/game_session.dart) נגזרים
/// מהיחס בין מילים שנמצאו למילים שנדרשו (שליש מהיעד = כוכב), לא מניקוד.
/// השלב מסתיים באופן מיידי כשמגיעים ליעד המילים המלא, גם אם נשאר זמן.
class LevelConfig extends Equatable {
  final int levelNumber; // 1-based
  final WorldTier tier;
  final int gridSize;
  final Duration timeLimit;

  /// מספר המילים שצריך למצוא כדי "לעבור" את השלב (כוכב אחד לפחות).
  final int wordsRequired;
  final int minWordLength;

  /// סוג השלב - רגיל / מאסטר / פינאלה של עולם (ראו [LevelKind]).
  final LevelKind kind;

  const LevelConfig({
    required this.levelNumber,
    required this.tier,
    required this.gridSize,
    required this.timeLimit,
    required this.wordsRequired,
    this.minWordLength = 2,
    this.kind = LevelKind.normal,
  });

  bool get isMasterLevel => kind == LevelKind.master;

  /// true אם זה שלב "פינאלה" - השלב האחרון בעולם, שבו מציגים חגיגת
  /// "עולם חדש נפתח!" + סיבוב גלגל מזל, ומעניקים פרס נדיב (ראו
  /// lib/features/game/level_result_screen.dart).
  bool get isWorldFinale => kind == LevelKind.worldFinale;

  /// יעדי המילים לכוכב 1/2/3 - מחלקים את [wordsRequired] לשלישים (ראו
  /// [GameSession.starsForWordCount]): כל שליש מהיעד שנמצא שווה כוכב,
  /// ושלושה כוכבים (המקסימום) מתקבלים בדיוק כשמגיעים ליעד המילים המלא -
  /// ואז השלב מסתיים באותו רגע, גם אם נשאר זמן על השעון.
  int get oneStarWords => (wordsRequired / 3).ceil();
  int get twoStarWords => (wordsRequired * 2 / 3).ceil();
  int get threeStarWords => wordsRequired;

  @override
  List<Object?> get props => [
        levelNumber,
        tier,
        gridSize,
        timeLimit,
        wordsRequired,
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
/// פריחה 5×5, היער הגדול 6×6). הקושי (ראו [wordsRequiredForLevel] ו-
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
        final wordsRequired = wordsRequiredForLevel(levelNumber, kind: kind);
        levels.add(
          LevelConfig(
            levelNumber: levelNumber,
            tier: tier,
            gridSize: tier.gridSize,
            timeLimit: timeLimitForLevel(
              wordsRequired: wordsRequired,
              gridSize: tier.gridSize,
              kind: kind,
            ),
            wordsRequired: wordsRequired,
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

  /// מספר המילים הנדרש לעבור שלב - עולה בהדרגה כדי שהמטרה תישאר ברורה
  /// ומוחשית: שלב 1 = 3 מילים, שלב 2 = 4, שלב 3 = 5, שלב 4 = 6, שלב 5 = 7,
  /// ומשם ממשיך לעלות **לאט מאוד ולאורך כל המשחק** (לא נשאר שטוח לנצח),
  /// עם תוספת קלה לשלבי מאסטר/פינאלה כדי שהם יורגשו קשים יותר מרגע
  /// הופעתם, לא רק בגלל הלוח.
  static int wordsRequiredForLevel(int levelNumber, {LevelKind kind = LevelKind.normal}) {
    if (levelNumber == 1) return 3;
    if (levelNumber == 2) return 4;
    if (levelNumber == 3) return 5;
    if (levelNumber == 4) return 6;
    if (levelNumber == 5) return 7;

    final g = globalProgress(levelNumber);
    int base = (5 + g * 3).round().clamp(5, 8);
    if (kind == LevelKind.master) base += 1;
    if (kind == LevelKind.worldFinale) base += 2;
    return base.clamp(5, 11);
  }

  /// זמן השלב - קצר וברור, עם מרווח נוח כדי שהיעד (מספר מילים) יישאר
  /// בהחלט מושג בלי למהר. נגזר ממספר המילים הנדרש ומגודל הלוח (לוח גדול
  /// יותר דורש קצת יותר זמן חיפוש), ומעוגל לעשרות שניות קרובות (30, 40,
  /// 50...) כדי שהזמן המוצג יהיה תמיד מספר "עגול" ונעים. שלבי מאסטר
  /// ופינאלה מקבלים פחות זמן יחסית לבייסליין (15%-20% פחות) - כך שהם
  /// מורגשים דחוקים ומאתגרים יותר, לא רק "עוד מילה אחת".
  static Duration timeLimitForLevel({
    required int wordsRequired,
    required int gridSize,
    LevelKind kind = LevelKind.normal,
  }) {
    final rawSeconds = 30 + wordsRequired * 9 + (gridSize - 3) * 6;
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
