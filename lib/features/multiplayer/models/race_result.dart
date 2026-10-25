import 'package:equatable/equatable.dart';

import 'race_config.dart';

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

  /// ההגדרות שבהן שוחקה התחרות (מול המחשב) - לכפתור "עוד סיבוב" עם אותם
  /// יריבים בדיוק. null במשחק מול חברים.
  final RaceConfig? config;

  /// משחק מול חברים: מספר הסבב שהסתיים (GameRoom.currentRound) - כדי שמסך
  /// התוצאות יעבור למשחק רק כשמתחיל סבב *חדש*, ולא בגלל עדכון חדר ישן.
  final int? round;

  const RaceResult({required this.rankedParticipants, this.config, this.round});

  int get humanRank => rankedParticipants.indexWhere((p) => p.isHuman) + 1;
  bool get humanWon => humanRank == 1;

  @override
  List<Object?> get props => [rankedParticipants, round];
}
