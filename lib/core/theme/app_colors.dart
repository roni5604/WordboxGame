import 'package:flutter/material.dart';

/// פלטת הצבעים הראשית של Wordbox-IL, בהשראת הסגנון הצבעוני והחגיגי של
/// משחקי מילים חברתיים (כתום-אפרסק חם + טורקיז), עם פלטה נפרדת לכל עולם.
class AppColors {
  AppColors._();

  static const Color background = Color(0xFF13B8B0);
  static const Color backgroundDark = Color(0xFF0E8C86);

  static const Color primary = Color(0xFFFF7A45);
  static const Color primaryDark = Color(0xFFE85D2A);

  static const Color tileFace = Color(0xFFFFFFFF);
  static const Color tileSelected = Color(0xFFFFE066);
  static const Color tileShadow = Color(0x33000000);

  /// צבע אחיד לכל אריחי הלוח במצב idle - עיגולי אפרסק נעימים על רקע
  /// הגרדיאנט של המסך (ראו letter_tile.dart, grid_board.dart), בהשראת
  /// עיצוב משחקי חיבור-אותיות מוכרים עם עיגולים לבנים/אחידים ומרווחים
  /// ברורים בין תא לתא.
  static const Color tileIdle = Color(0xFFFFD9A0);

  static const Color tileLetterRed = Color(0xFFE0303B);

  static const Color success = Color(0xFF4CD97B);
  static const Color error = Color(0xFFFF5C5C);

  /// צבע ייחודי לרב-משתתפים/תחרויות - תואם לגרדיאנט מסכי התחרות.
  static const Color accent = Color(0xFF6A11CB);

  static const Color textDark = Color(0xFF2B2440);
  static const Color textLight = Color(0xFFFFFFFF);

  static const Color star = Color(0xFFFFC93C);
  static const Color starEmpty = Color(0x40FFFFFF);

  /// גרדיאנט רקע ייחודי לכל "עולם" בקמפיין - תחושת התקדמות ויזואלית ברורה.
  static const List<List<Color>> worldGradients = [
    [Color(0xFFFF9A56), Color(0xFFFF6F91)], // נבטים
    [Color(0xFF43CBFF), Color(0xFF9708CC)], // ניצנים
    [Color(0xFFFDC830), Color(0xFFF37335)], // פריחה
    [Color(0xFF11998E), Color(0xFF38EF7D)], // היער הגדול
    [Color(0xFF6A11CB), Color(0xFF2575FC)], // פסגת המילים
  ];

  static List<Color> gradientForWorldIndex(int index) {
    return worldGradients[index % worldGradients.length];
  }

  /// אייקון Material ייחודי לכל "עולם" - זהות ויזואלית נוספת מעבר לגרדיאנט
  /// (בלי תלות בנכסי אמנות חדשים), מוצג בכותרת המפה ובבאנרי מעבר-עולם
  /// (ראו lib/features/home/campaign_map_screen.dart).
  static const List<IconData> worldIcons = [
    Icons.eco_rounded, // נבטים
    Icons.water_drop_rounded, // ניצנים
    Icons.wb_sunny_rounded, // פריחה
    Icons.park_rounded, // היער הגדול
    Icons.terrain_rounded, // פסגת המילים
  ];

  static IconData iconForWorldIndex(int index) {
    return worldIcons[index % worldIcons.length];
  }

  /// צבע קו-המסלול במפת השלבים - גרסה בהירה יותר של גרדיאנט העולם,
  /// כדי שהמסלול יישאר קריא מעל רקע העולם ועדיין יצבע את האזור.
  static Color pathColorForWorldIndex(int index) {
    final colors = gradientForWorldIndex(index);
    return Color.lerp(colors.first, Colors.white, 0.45)!;
  }

  static const Color masterAmber = Color(0xFFFFA000);
  static const Color masterDeep = Color(0xFFFF6D00);
  static const Color finaleViolet = Color(0xFF7C4DFF);
  static const Color finaleGold = Color(0xFFFFD54F);
  static const Color luckyTeal = Color(0xFF00BCD4);
  static const Color luckyGold = Color(0xFFFFC107);
}
