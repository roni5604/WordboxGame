import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../../core/theme/app_colors.dart';

enum TileVisualState { idle, selected, success, error }

class LetterTile extends StatelessWidget {
  final String letter;
  final double size;
  final TileVisualState state;

  const LetterTile({
    super.key,
    required this.letter,
    required this.size,
    this.state = TileVisualState.idle,
  });

  Color get _bgColor {
    switch (state) {
      case TileVisualState.idle:
        return AppColors.tileFace;
      case TileVisualState.selected:
        return AppColors.tileSelected;
      case TileVisualState.success:
        return AppColors.success;
      case TileVisualState.error:
        return AppColors.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bgColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.tileShadow,
            blurRadius: state == TileVisualState.idle ? 4 : 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: state == TileVisualState.selected
            ? Border.all(color: Colors.white, width: 3)
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: TextStyle(
          fontSize: size * 0.42,
          fontWeight: FontWeight.w800,
          color: state == TileVisualState.idle ? AppColors.textDark : Colors.white,
        ),
      ),
    );

    if (state == TileVisualState.selected) {
      return tile.animate().scaleXY(begin: 1, end: 1.12, duration: 120.ms, curve: Curves.easeOut);
    }
    return tile;
  }
}
