import 'package:equatable/equatable.dart';

/// התקדמות שנשמרה עבור שלב בודד בקמפיין.
class LevelProgress extends Equatable {
  final int levelNumber;
  final int stars; // 0-3
  final int bestScore;
  final bool completed;

  const LevelProgress({
    required this.levelNumber,
    this.stars = 0,
    this.bestScore = 0,
    this.completed = false,
  });

  LevelProgress copyWith({int? stars, int? bestScore, bool? completed}) {
    return LevelProgress(
      levelNumber: levelNumber,
      stars: stars ?? this.stars,
      bestScore: bestScore ?? this.bestScore,
      completed: completed ?? this.completed,
    );
  }

  @override
  List<Object?> get props => [levelNumber, stars, bestScore, completed];
}
