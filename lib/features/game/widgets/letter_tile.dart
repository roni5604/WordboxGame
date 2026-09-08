import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';

enum TileVisualState { idle, selected, success, error, hint }

/// אריח אות בודד בלוח - בסגנון "ריבוע מעוגל צבעוני" (squircle) עם אות
/// עבה ומתאר לבן, בהשראת אייקון האפליקציה. כל תא במצב idle מקבל צבע
/// מפלטת ה"ממתקים" (קרם/אפרסק/כתום/פוקסיה) לפי מיקומו בלוח, כך שהלוח
/// כולו נראה כמו פסיפס חגיגי - אותו סגנון בדיוק כמו האייקון.
class LetterTile extends StatelessWidget {
  final String letter;
  final double size;
  final TileVisualState state;

  /// אינדקס לבחירת צבע מהפלטה במצב idle (בד"כ מבוסס על מיקום השורה/עמודה).
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
        final palette = AppColors.tileCandyPalette;
        return palette[paletteIndex % palette.length];
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
    final radius = size * 0.28;
    final fontSize = size * 0.46;

    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: AppColors.tileShadow,
            blurRadius: state == TileVisualState.idle ? 4 : 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: state == TileVisualState.selected
            ? Border.all(color: Colors.white, width: 3)
            : state == TileVisualState.hint
                ? Border.all(color: Colors.white, width: 3)
                : null,
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
      return tile.animate().scaleXY(begin: 1, end: 1.12, duration: 120.ms, curve: Curves.easeOut);
    }
    if (state == TileVisualState.hint) {
      return tile
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(begin: 1, end: 1.1, duration: 300.ms, curve: Curves.easeInOut);
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
        Text(
          letter,
          style: baseStyle.copyWith(color: AppColors.tileLetterRed),
        ),
      ],
    );
  }
}
