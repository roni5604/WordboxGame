import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';

enum TileVisualState { idle, selected, success, error, hint }

/// אריח אות בודד בלוח - עיגול מלא ואחיד (בהשראת עיצוב משחקי חיבור-אותיות
/// מוכרים: עיגולים לבנים/אחידים עם צל רך ומרווחים ברורים בין תא לתא,
/// כדי שגם חיבור אלכסוני יהיה נוח וברור לעין). כל תא במצב idle מקבל את
/// אותו צבע אפרסק אחיד ([AppColors.tileIdle]) - אין יותר פלטת "פסיפס"
/// לפי מיקום.
class LetterTile extends StatelessWidget {
  final String letter;
  final double size;
  final TileVisualState state;

  /// נשמר לתאימות לאחור עם קריאות קיימות (grid_board.dart,
  /// mini_grid_demo.dart) - לא משפיע יותר על הצבע במצב idle, שהוא אחיד.
  final int paletteIndex;

  const LetterTile({
    super.key,
    required this.letter,
    required this.size,
    this.state = TileVisualState.idle,
    this.paletteIndex = 0,
  });

  Color get _bgColor {
    switch (state) {
      case TileVisualState.idle:
        return AppColors.tileIdle;
      case TileVisualState.selected:
        return AppColors.tileSelected;
      case TileVisualState.success:
        return AppColors.success;
      case TileVisualState.error:
        return AppColors.error;
      case TileVisualState.hint:
        return AppColors.star;
    }
  }

  /// במצב idle האות נראית כמו באייקון: אדומה עם מתאר לבן עבה.
  /// במצבים אחרים (נבחר/הצלחה/שגיאה) האות לבנה על רקע צבעוני רווי.
  bool get _useRedOutlinedLetter => state == TileVisualState.idle;

  @override
  Widget build(BuildContext context) {
    // עיגול מלא (BoxShape.circle) - עם המרווח הנוח שנפתח בין אריח לאריח
    // (ראו grid_board.dart: tileAt מרנדר את התא בכ-0.8 מגודל התא בפועל)
    // בהשראת עיצוב משחקי חיבור-אותיות מוכרים, בלי לפגוע בדיוק הגרירה
    // (שמבוסס על cellSize המלא, לא על גודל התא המצומצם הזה).
    final fontSize = size * 0.46;
    final isIdle = state == TileVisualState.idle;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: BoxShape.circle,
        boxShadow: isIdle
            ? const [
                BoxShadow(
                  color: AppColors.tileShadow,
                  blurRadius: 6,
                  offset: Offset(0, 2),
                ),
              ]
            : const [
                BoxShadow(
                  color: AppColors.tileShadow,
                  blurRadius: 10,
                  offset: Offset(0, 3),
                ),
              ],
        border:
            state == TileVisualState.selected || state == TileVisualState.hint
            ? Border.all(color: Colors.white, width: 3)
            : Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1),
      ),
      alignment: Alignment.center,
      child: _useRedOutlinedLetter
          ? _OutlinedLetter(letter: letter, fontSize: fontSize)
          : Text(
              letter,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
    );

    if (state == TileVisualState.selected) {
      // סקאלה מתונה יותר (הייתה 1.12) - כך שאריח נבחר לא "בולע" משמעותית
      // משטח השכנים הצמודים אליו (אין רווח שיכול לספוג את ההתרחבות).
      return tile.animate().scaleXY(
        begin: 1,
        end: 1.06,
        duration: 120.ms,
        curve: Curves.easeOut,
      );
    }
    if (state == TileVisualState.hint) {
      return tile
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.06,
            duration: 300.ms,
            curve: Curves.easeInOut,
          );
    }
    return tile;
  }
}

/// אות עבה עם מתאר לבן - אפקט "מדבקה" כמו באייקון האפליקציה. מיושם עם
/// Stack: טקסט תחתון עם קו מתאר לבן עבה (Paint.stroke) וטקסט עליון מלא
/// באדום, שני הטקסטים ממורכזים בדיוק זה על זה.
class _OutlinedLetter extends StatelessWidget {
  final String letter;
  final double fontSize;

  const _OutlinedLetter({required this.letter, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
    );
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          letter,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..color = Colors.white,
          ),
        ),
        Text(letter, style: baseStyle.copyWith(color: AppColors.tileLetterRed)),
      ],
    );
  }
}
