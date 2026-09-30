import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/cosmetics/cosmetic_catalog.dart';
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

  /// סקין אותיות. null = העיצוב הקלאסי.
  final LetterSkin? letterSkin;

  /// צבע אריח מסקין הלוח. סקין האותיות יכול לדרוס אותו דרך [LetterSkin.tileOverride].
  final Color? boardTileColor;

  const LetterTile({
    super.key,
    required this.letter,
    required this.size,
    this.state = TileVisualState.idle,
    this.paletteIndex = 0,
    this.letterSkin,
    this.boardTileColor,
  });

  Color get _bgColor {
    switch (state) {
      case TileVisualState.idle:
        return letterSkin?.tileOverride ?? boardTileColor ?? AppColors.tileIdle;
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

  /// במצב idle האות לפי הסקין. במצבים אחרים האות לבנה על רקע צבעוני.
  bool get _useStyledIdleLetter => state == TileVisualState.idle;

  @override
  Widget build(BuildContext context) {
    // עיגול מלא (BoxShape.circle) - עם המרווח הנוח שנפתח בין אריח לאריח
    // (ראו grid_board.dart: tileAt מרנדר את התא בכ-0.8 מגודל התא בפועל)
    // בהשראת עיצוב משחקי חיבור-אותיות מוכרים, בלי לפגוע בדיוק הגרירה
    // (שמבוסס על cellSize המלא, לא על גודל התא המצומצם הזה).
    final fontSize = size * 0.46;
    final isIdle = state == TileVisualState.idle;
    final rounded = letterSkin?.shape == LetterTileShape.roundedSquare;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: rounded ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: rounded ? BorderRadius.circular(size * 0.22) : null,
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
      child: _useStyledIdleLetter
          ? _StyledIdleLetter(letter: letter, fontSize: fontSize, skin: letterSkin)
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

/// אות במצב idle לפי סקין. ברירת המחדל היא האות האדומה עם מתאר לבן.
class _StyledIdleLetter extends StatelessWidget {
  final String letter;
  final double fontSize;
  final LetterSkin? skin;

  const _StyledIdleLetter({required this.letter, required this.fontSize, this.skin});

  @override
  Widget build(BuildContext context) {
    final outlined = skin?.outlined ?? true;
    final letterColor = skin?.letterColor ?? AppColors.tileLetterRed;
    final outlineColor = skin?.outlineColor ?? Colors.white;
    final weight = skin?.fontWeight ?? FontWeight.w900;
    final baseStyle = TextStyle(
      fontSize: fontSize,
      fontWeight: weight,
      height: 1,
    );
    if (!outlined) {
      return Text(letter, style: baseStyle.copyWith(color: letterColor));
    }
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          letter,
          style: baseStyle.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.16
              ..color = outlineColor,
          ),
        ),
        Text(letter, style: baseStyle.copyWith(color: letterColor)),
      ],
    );
  }
}
