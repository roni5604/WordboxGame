import 'package:equatable/equatable.dart';

/// מודלים למצב "משחק מול חברים" (חדרים פרטיים אמיתיים דרך Firestore).
/// ראו lib/features/multiplayer/services/multiplayer_repository.dart למימוש.
///
/// מודל המשחק הוא **סבב משותף וסימולטני**: כל השחקנים בחדר פותרים במקביל
/// את אותו לוח (המסונכרן דטרמיניסטית בין הלקוחות דרך [GameRoom.boardSeed] -
/// ראו lib/game_engine/board_generator.dart) למשך [GameRoom.roundSeconds],
/// בדיוק כמו במצב "משחק מול המחשב" הקיים - אין תורות מתחלפים בין שחקנים.

enum RoomStatus { waiting, inProgress, finished }

class PlayerInRoom extends Equatable {
  final String uid;
  final String displayName;
  final int score;
  final int wordsFound;
  final bool isHost;

  const PlayerInRoom({
    required this.uid,
    required this.displayName,
    this.score = 0,
    this.wordsFound = 0,
    this.isHost = false,
  });

  @override
  List<Object?> get props => [uid, displayName, score, wordsFound, isHost];
}

class GameRoom extends Equatable {
  final String roomCode;
  final RoomStatus status;
  final List<PlayerInRoom> players;

  final String hostUid;

  /// גודל הלוח (למשל 4/5/6) - נבחר ע"י מנהל/ת החדר ביצירה, קבוע לאורך המשחק.
  final int gridSize;

  /// ה-seed המשמש את [BoardGenerator] כדי שכל הלקוחות ייצרו לוח זהה
  /// בדיוק, בלי לשדר את 49 האותיות עצמן.
  final int boardSeed;

  /// משך הסבב המשותף בשניות - "כמה זמן כל תור" בבקשת מנהל/ת החדר.
  final int roundSeconds;

  /// ניקוד יעד לניצחון מוקדם - 0 = "ללא יעד" (המשחק מסתיים רק בתום הזמן).
  final int targetScore;

  /// מספר השחקנים המקסימלי המותר בחדר.
  final int maxPlayers;

  /// מתי נסגרת האפשרות להצטרף לחדר עם הקוד (גם אם המשחק עדיין לא התחיל).
  final DateTime? joinDeadline;

  /// מתי המנהל/ת לחץ/ה "התחל משחק" - כל לקוח מחשב מקומית כמה זמן נשאר
  /// לפי `roundSeconds - now.difference(startedAt)`, בלי לשדר טיימר בכל שנייה.
  final DateTime? startedAt;

  /// מונה ניצחונות מצטבר לכל שחקן/ית בחדר הזה (uid -> מספר סבבים שנוצחו),
  /// לצורך תצוגת יחס ניצחונות/הפסדים (למשל "1:2") בין חברי החדר על פני
  /// כמה סבבי "משחק חוזר" (ראו restartRoom ב-multiplayer_repository.dart).
  /// לא מתאפס בין סבבים - רק כשנוצר חדר חדש לגמרי.
  final Map<String, int> wins;

  const GameRoom({
    required this.roomCode,
    required this.status,
    required this.players,
    required this.hostUid,
    this.gridSize = 5,
    this.boardSeed = 0,
    this.roundSeconds = 90,
    this.targetScore = 0,
    this.maxPlayers = 6,
    this.joinDeadline,
    this.startedAt,
    this.wins = const {},
  });

  bool get hasTargetScore => targetScore > 0;
  bool get isJoinWindowOpen =>
      status == RoomStatus.waiting && (joinDeadline == null || DateTime.now().isBefore(joinDeadline!));
  bool get isFull => players.length >= maxPlayers;

  GameRoom copyWith({
    RoomStatus? status,
    List<PlayerInRoom>? players,
    DateTime? startedAt,
    Map<String, int>? wins,
  }) {
    return GameRoom(
      roomCode: roomCode,
      status: status ?? this.status,
      players: players ?? this.players,
      hostUid: hostUid,
      gridSize: gridSize,
      boardSeed: boardSeed,
      roundSeconds: roundSeconds,
      targetScore: targetScore,
      maxPlayers: maxPlayers,
      joinDeadline: joinDeadline,
      startedAt: startedAt ?? this.startedAt,
      wins: wins ?? this.wins,
    );
  }

  @override
  List<Object?> get props => [
        roomCode,
        status,
        players,
        hostUid,
        gridSize,
        boardSeed,
        roundSeconds,
        targetScore,
        maxPlayers,
        joinDeadline,
        startedAt,
        wins,
      ];
}
