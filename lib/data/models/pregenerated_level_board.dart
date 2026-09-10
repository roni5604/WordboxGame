import 'package:equatable/equatable.dart';

import '../../game_engine/models/grid_position.dart';

/// לוח קבוע ומוכן-מראש לשלב בודד (ראו assets/boards/level_boards.json,
/// שנבנה ע"י tool/generate_level_boards.dart) - זהה לכל המשתמשים/ות.
class PregeneratedLevelBoard extends Equatable {
  final int size;
  final List<List<String>> letters;

  /// רק לשלב 1: מילה ונתיב לצורך ההדגמה המוטבעת בתחילת השלב (ראו
  /// lib/features/game/game_screen.dart).
  final String? tutorialWord;
  final List<GridPosition>? tutorialPath;

  const PregeneratedLevelBoard({
    required this.size,
    required this.letters,
    this.tutorialWord,
    this.tutorialPath,
  });

  factory PregeneratedLevelBoard.fromJson(Map<String, dynamic> json) {
    final letters = (json['letters'] as List)
        .map((row) => (row as List).cast<String>())
        .toList();

    final rawPath = json['tutorialPath'] as List?;
    final tutorialPath = rawPath
        ?.map((p) => GridPosition((p as List)[0] as int, p[1] as int))
        .toList();

    return PregeneratedLevelBoard(
      size: json['size'] as int,
      letters: letters,
      tutorialWord: json['tutorialWord'] as String?,
      tutorialPath: tutorialPath,
    );
  }

  @override
  List<Object?> get props => [size, letters, tutorialWord, tutorialPath];
}
