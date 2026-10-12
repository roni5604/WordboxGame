import 'package:flutter/widgets.dart';

/// שפת התנועה של האפליקציה - עקומות ומשכים אחידים לכל האנימציות.
///
/// הערכים לקוחים מעקרונות התנועה של Emil Kowalski (skills/animate), מ-Impeccable
/// (reference/animate.md) ומעקומות ה-ease של GSAP, ומומרים ל-Flutter:
/// * כניסה/יציאה - ease-out חזק (אף פעם לא ease-in על ממשק - הוא מאחר בדיוק
///   את הרגע שבו מסתכלים).
/// * תזוזה על המסך - ease-in-out חזק.
/// * לחיצה - 100-160ms. ממשק שגרתי - עד 300ms. רק רגעי חגיגה נדירים (פתיחת
///   תיבה, ניצחון) מקבלים זמן ותנועה "משחקית" ארוכה יותר.
/// * אף פעם לא scale(0): מתחילים מ-0.9 ומעלה + שקיפות.
class Motion {
  Motion._();

  /// ease-out חזק לממשק - cubic-bezier(0.23, 1, 0.32, 1).
  static const Curve out = Cubic(0.23, 1, 0.32, 1);

  /// ease-in-out חזק לתזוזה על המסך - cubic-bezier(0.77, 0, 0.175, 1).
  static const Curve inOut = Cubic(0.77, 0, 0.175, 1);

  /// עקומת מגירה בסגנון iOS - cubic-bezier(0.32, 0.72, 0, 1).
  static const Curve drawer = Cubic(0.32, 0.72, 0, 1);

  /// האטה "בטוחה" לכניסה מודגשת - cubic-bezier(0.16, 1, 0.3, 1) (expo.out).
  static const Curve expoOut = Cubic(0.16, 1, 0.3, 1);

  /// GSAP back.out(1.7) - חריגה קטנה ונחיתה. לרגעים משחקיים בלבד.
  static const Curve backOut = Cubic(0.34, 1.56, 0.64, 1);

  /// "פופ" חזק יותר (back.out(2.5)) - לפרסים ותגיות דרגה.
  static const Curve pop = Cubic(0.3, 1.9, 0.55, 1);

  static const Duration press = Duration(milliseconds: 120);
  static const Duration quick = Duration(milliseconds: 180);
  static const Duration standard = Duration(milliseconds: 260);
  static const Duration emphasis = Duration(milliseconds: 420);
  static const Duration celebrate = Duration(milliseconds: 700);

  /// מרווח בין פריטים שנכנסים ברצף (30-80ms לפי Emil).
  static const Duration stagger = Duration(milliseconds: 60);

  /// האם המשתמש/ת ביקשו "הפחתת תנועה" במערכת. במצב הזה מורידים תזוזות
  /// ורעידות, אבל משאירים שקיפות/צבע - מעט ועדין, לא אפס.
  static bool reduced(BuildContext context) => MediaQuery.maybeDisableAnimationsOf(context) ?? false;
}
