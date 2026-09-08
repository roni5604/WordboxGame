import 'package:flutter/material.dart';

import '../../game/widgets/connector_painter.dart';
import '../../game/widgets/letter_tile.dart';

/// הדגמה ויזואלית סטטית (לא אינטראקטיבית) של חיבור אותיות שכנות ליצירת
/// מילה - משמשת במסך ההדרכה/החוקים כדי "להראות" ולא רק "להסביר".
/// [highlightedCount] קובע כמה תאים מסומנים כרגע (לאנימציה מדורגת).
class MiniGridDemo extends StatelessWidget {
  final List<String> letters; // row-major
  final int columns;
  final List<int> path; // אינדקסים לפי סדר החיבור
  final int highlightedCount;
  final double tileSize;
  final double spacing;

  const MiniGridDemo({
    super.key,
    required this.letters,
    required this.columns,
    required this.path,
    required this.highlightedCount,
    this.tileSize = 56,
    this.spacing = 12,
  });

  Offset _centerOf(int index) {
    final row = index ~/ columns;
    final col = index % columns;
    return Offset(
      col * (tileSize + spacing) + tileSize / 2,
      row * (tileSize + spacing) + tileSize / 2,
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = (letters.length / columns).ceil();
    final width = columns * tileSize + (columns - 1) * spacing;
    final height = rows * tileSize + (rows - 1) * spacing;
    final activePath = path.take(highlightedCount).toList();

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: ConnectorPainter(points: activePath.map(_centerOf).toList()),
          ),
          for (int i = 0; i < letters.length; i++)
            Builder(builder: (context) {
              final center = _centerOf(i);
              final isActive = activePath.contains(i);
              return Positioned(
                left: center.dx - tileSize / 2,
                top: center.dy - tileSize / 2,
                child: LetterTile(
                  letter: letters[i],
                  size: tileSize,
                  paletteIndex: (i ~/ columns * 31 + i % columns * 17) % 4,
                  state: isActive ? TileVisualState.selected : TileVisualState.idle,
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// עוטף את [MiniGridDemo] בלופ אנימציה שמדגים חיבור אותיות בהדרגה,
/// ואז מתחיל מחדש - כמו הדגמת "גרירת אצבע" חיה.
class AnimatedMiniGridDemo extends StatefulWidget {
  final List<String> letters;
  final int columns;
  final List<int> path;

  const AnimatedMiniGridDemo({
    super.key,
    required this.letters,
    required this.columns,
    required this.path,
  });

  @override
  State<AnimatedMiniGridDemo> createState() => _AnimatedMiniGridDemoState();
}

class _AnimatedMiniGridDemoState extends State<AnimatedMiniGridDemo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700 * widget.path.length + 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final stepDuration = 700 / (700 * widget.path.length + 900);
        final progress = _controller.value;
        final revealed = (progress / stepDuration).floor() + 1;
        final count = revealed.clamp(0, widget.path.length);
        return MiniGridDemo(
          letters: widget.letters,
          columns: widget.columns,
          path: widget.path,
          highlightedCount: count,
        );
      },
    );
  }
}
