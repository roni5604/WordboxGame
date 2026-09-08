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

  /// פלטת "האריחים הצבעוניים" - בהשראת אייקון האפליקציה (ריבועים מעוגלים
  /// קרם/אפרסק/כתום/פוקסיה) עם אות אדומה עבה ומתאר לבן. כל תא בלוח מקבל
  /// צבע מהפלטה הזו לפי מיקומו, כדי שהלוח ייראה כמו פסיפס חגיגי כמו האייקון.
  static const List<Color> tileCandyPalette = [
    Color(0xFFFFF3E0), // קרם
    Color(0xFFFFD9A0), // אפרסק
    Color(0xFFFFC178), // כתום בהיר
    Color(0xFFEC4899), // פוקסיה
  ];

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
}
