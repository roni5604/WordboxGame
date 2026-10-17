import 'models/level_config.dart';

/// "פרקים" בקמפיין: כל [levelsPerChapter] שלבים הם פרק (5 פרקים בכל עולם,
/// 20 פרקים ב-100 השלבים). כדי להיכנס לפרק הבא צריך אחד משניים:
///
/// 1. **מספיק כוכבים** מכל השלבים שלפניו ([requiredStars]) - הדרך
///    "הטבעית": משחקים טוב, או חוזרים לשלב קודם ומשפרים כוכבים.
/// 2. **פתיחה במטבעות** ([unlockCost]) - המחיר תלוי בכמה כוכבים חסרים,
///    כך שמי שחסר/ה לו כוכב אחד משלם/ת מעט, ומי שדילג/ה על הרבה משלם/ת הרבה.
///
/// למה: בלי שער, אפשר "לרוץ" קדימה עם כוכב אחד בכל שלב (או לדלג במטבעות)
/// ולהגיע ללוחות גדולים מבלי לשלוט בקטנים. השער מוודא שליטה, נותן סיבה
/// לחזור לשלבים ישנים, ויוצר שימוש משמעותי למטבעות.
///
/// הדרישה עולה בהדרגה: 1.8 כוכבים בממוצע לשלב בתחילת המשחק, ועד 2.4
/// בסופו (מתוך 3). שחקן/ית שמסיים/ת רוב השלבים ב-3 כוכבים לא ירגיש/תרגיש
/// בשער בכלל; מי שמסיים/ת הרבה שלבים בכוכב אחד ייתקע/תיתקע ויצטרך/תצטרך
/// לשפר או לשלם.
class CampaignChapters {
  CampaignChapters._();

  static const int levelsPerChapter = 5;

  /// ממוצע הכוכבים לשלב שנדרש בשער הראשון ובשער האחרון של המשחק.
  static const double startStarsPerLevel = 1.8;
  static const double endStarsPerLevel = 2.4;

  static int get totalChapters => (CampaignLevels.totalLevels / levelsPerChapter).ceil();

  /// מספר הפרק (1-מבוסס) של [levelNumber].
  static int chapterOf(int levelNumber) => (levelNumber - 1) ~/ levelsPerChapter + 1;

  static int firstLevelOf(int chapter) => (chapter - 1) * levelsPerChapter + 1;

  static int lastLevelOf(int chapter) =>
      (chapter * levelsPerChapter).clamp(1, CampaignLevels.totalLevels);

  /// true אם [levelNumber] הוא השלב הראשון של פרק שיש לפניו שער (כל פרק
  /// מלבד הראשון).
  static bool isGateLevel(int levelNumber) =>
      levelNumber > 1 && (levelNumber - 1) % levelsPerChapter == 0;

  /// מיקום הפרק בתוך העולם שלו (1-5).
  static int chapterWithinWorld(int chapter) =>
      (chapter - 1) % (CampaignLevels.levelsPerWorld ~/ levelsPerChapter) + 1;

  /// כמה כוכבים (מכל השלבים שלפני הפרק) צריך כדי להיכנס ל-[chapter].
  static int requiredStars(int chapter) {
    if (chapter <= 1) return 0;
    final first = firstLevelOf(chapter);
    final levelsBefore = first - 1;
    final t = CampaignLevels.globalProgress(first);
    final perLevel = startStarsPerLevel + (endStarsPerLevel - startStarsPerLevel) * t;
    return (levelsBefore * perLevel).round();
  }

  /// מחיר פתיחת [chapter] במטבעות כשחסרים [missingStars] כוכבים. כל כוכב
  /// חסר עולה יותר בעולמות מתקדמים; יש מינימום (כדי שזה תמיד יהיה החלטה)
  /// ותקרה (כדי שזה לא יהיה בלתי אפשרי). מעוגל ל-5.
  static int unlockCost({required int chapter, required int missingStars}) {
    if (missingStars <= 0) return 0;
    final world = (chapterWorldIndex(chapter)).clamp(0, 3);
    final perStar = 25 + 10 * world;
    final minCost = 60 + 20 * world;
    final maxCost = 300 + 150 * world;
    final raw = (missingStars * perStar).clamp(minCost, maxCost);
    return (raw / 5).round() * 5;
  }

  /// אינדקס העולם (0-מבוסס) של [chapter].
  static int chapterWorldIndex(int chapter) =>
      (firstLevelOf(chapter) - 1) ~/ CampaignLevels.levelsPerWorld;
}
