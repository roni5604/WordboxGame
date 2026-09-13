import '../models/room_models.dart';

/// ממשק מופשט למצב "משחק מול חברים" - מאפשר להחליף מימוש (Firestore, שרת
/// עצמאי, וכו') מבלי לגעת במסכים. המימוש בפועל הוא [FirestoreMultiplayerRepository]
/// (ראו firestore_multiplayer_repository.dart).
abstract class MultiplayerRepository {
  /// מזהה המשתמש/ת הנוכחי/ת (מתחבר/ת כאורח/ת אוטומטית אם צריך). שימושי
  /// ל-UI כדי לדעת "האם אני המנהל/ת" בלי לעבור דרך שאילתת רשת.
  Future<String> ensureSignedIn();

  Future<GameRoom> createRoom({
    required String hostDisplayName,
    required int gridSize,
    required int roundSeconds,
    required int targetScore,
    required int maxPlayers,
    required Duration joinWindow,
    int totalRounds = 1,
    int entryFee = 5,
  });

  /// קריאת חדר בלי להצטרף - לתצוגת דמי כניסה/קופה במסך ההצטרפות.
  Future<GameRoom> fetchRoom(String roomCode);

  Future<GameRoom> joinRoom({required String roomCode, required String displayName});

  Stream<GameRoom> watchRoom(String roomCode);

  /// מתחיל את המשחק (רק המנהל/ת רשאי/ת) - קובע `startedAt` ומעביר את
  /// החדר למצב `inProgress`.
  Future<void> startGame(String roomCode);

  /// מעדכן את הניקוד/מספר המילים העצמי של השחקן/ית הנוכחי/ת בחדר -
  /// נקרא בכל מציאת מילה מקומית (ראו lib/game_engine/game_session.dart).
  Future<void> updateMyScore(String roomCode, {required int score, required int wordsFound});

  /// מסמן שהסבב הסתיים (זמן נגמר / מישהו הגיע לניקוד היעד) - "מי שראשון
  /// קובע", בטוח לקריאה כפולה מכמה לקוחות בו-זמנית. אם מועבר [winnerUid]
  /// (ורק כשאין שוויון בניקוד המוביל), מונה הניצחונות המצטבר של אותו/ה
  /// שחקן/ית ב-[GameRoom.wins] מתקדם באחד. בסבב האחרון מסמן גם `potAwarded`.
  Future<void> finishRoom(String roomCode, {String? winnerUid});

  /// "משחק חוזר" - רק מנהל/ת החדר, ורק כשהסבב הקודם הסתיים (`finished`):
  /// מייצר לוח חדש (boardSeed אחר), מאפס ניקוד/מילים של כל השחקנים/ות,
  /// ומחזיר את החדר למצב `waiting` כדי שאפשר יהיה ללחוץ "התחל משחק" שוב.
  /// מונה הניצחונות המצטבר ([GameRoom.wins]) והגדרות המשחק (גודל לוח,
  /// משך סבב וכו') לא משתנים.
  Future<void> restartRoom(String roomCode);

  /// הסבב הבא בסדרה - רק מנהל/ת, ורק אחרי `finished` וכשיש עוד משחקונים:
  /// לוח חדש, איפוס ניקוד, `currentRound + 1`, ומעבר ישר ל-`inProgress`
  /// (בלי חזרה ללובי). הקופה ודמי הכניסה לא משתנים.
  Future<void> startNextRound(String roomCode);

  Future<void> leaveRoom(String roomCode);
}

/// Stub זמני - זורק חריגה ברורה, לשימוש כשה-backend כבוי (AppConfig.useFirebaseBackend == false).
class UnimplementedMultiplayerRepository implements MultiplayerRepository {
  Never _unavailable() =>
      throw UnimplementedError('משחק מול חברים דורש חיבור לאינטרנט ול-Firebase.');

  @override
  Future<String> ensureSignedIn() => _unavailable();

  @override
  Future<GameRoom> createRoom({
    required String hostDisplayName,
    required int gridSize,
    required int roundSeconds,
    required int targetScore,
    required int maxPlayers,
    required Duration joinWindow,
    int totalRounds = 1,
    int entryFee = 5,
  }) =>
      _unavailable();

  @override
  Future<GameRoom> fetchRoom(String roomCode) => _unavailable();

  @override
  Future<GameRoom> joinRoom({required String roomCode, required String displayName}) =>
      _unavailable();

  @override
  Stream<GameRoom> watchRoom(String roomCode) => _unavailable();

  @override
  Future<void> startGame(String roomCode) => _unavailable();

  @override
  Future<void> updateMyScore(String roomCode, {required int score, required int wordsFound}) =>
      _unavailable();

  @override
  Future<void> finishRoom(String roomCode, {String? winnerUid}) => _unavailable();

  @override
  Future<void> restartRoom(String roomCode) => _unavailable();

  @override
  Future<void> startNextRound(String roomCode) => _unavailable();

  @override
  Future<void> leaveRoom(String roomCode) => _unavailable();
}
