import 'package:equatable/equatable.dart';

class RaceParticipantResult extends Equatable {
  final String name;
  final int score;
  final int wordsFound;
  final bool isHuman;

  const RaceParticipantResult({
    required this.name,
    required this.score,
    required this.wordsFound,
    required this.isHuman,
  });

  @override
  List<Object?> get props => [name, score, wordsFound, isHuman];
}

class RaceResult extends Equatable {
  final List<RaceParticipantResult> rankedParticipants; // ממוין מהניקוד הגבוה לנמוך

  const RaceResult({required this.rankedParticipants});

  int get humanRank => rankedParticipants.indexWhere((p) => p.isHuman) + 1;
  bool get humanWon => humanRank == 1;

  @override
  List<Object?> get props => [rankedParticipants];
}
