import 'package:equatable/equatable.dart';

/// מודלים לשלב 2 (רב-משתתפים) - עדיין לא מחוברים ל-backend אמיתי,
/// אך מגדירים כבר את מבנה הנתונים הצפוי כדי לפשט את המימוש העתידי.
/// ראו lib/features/multiplayer/services/multiplayer_repository.dart.

enum RoomStatus { waiting, inProgress, finished }

class PlayerInRoom extends Equatable {
  final String uid;
  final String displayName;
  final int score;
  final bool isHost;

  const PlayerInRoom({
    required this.uid,
    required this.displayName,
    this.score = 0,
    this.isHost = false,
  });

  @override
  List<Object?> get props => [uid, displayName, score, isHost];
}

class GameRoom extends Equatable {
  final String roomCode;
  final RoomStatus status;
  final List<PlayerInRoom> players;
  final int gridSize;
  final String? currentTurnUid;
  final int turnSecondsRemaining;
  final int roundNumber;
  final int maxRounds;

  const GameRoom({
    required this.roomCode,
    required this.status,
    required this.players,
    this.gridSize = 5,
    this.currentTurnUid,
    this.turnSecondsRemaining = 30,
    this.roundNumber = 1,
    this.maxRounds = 5,
  });

  @override
  List<Object?> get props => [
        roomCode,
        status,
        players,
        gridSize,
        currentTurnUid,
        turnSecondsRemaining,
        roundNumber,
        maxRounds,
      ];
}
