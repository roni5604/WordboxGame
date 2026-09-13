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
  });

  Future<GameRoom> joinRoom({required String roomCode, required String displayName});

  Stream<GameRoom> watchRoom(String roomCode);

  /// מתחיל את המשחק (רק המנהל/ת רשאי/ת) - קובע `startedAt` ומעביר את
  /// החדר למצב `inProgress`.
  Future<void> startGame(String roomCode);

  /// מעדכן את הניקוד/מספר המילים העצמי של השחקן/ית הנוכחי/ת בחדר -
  /// נקרא בכל מציאת מילה מקומית (ראו lib/game_engine/game_session.dart).
  Future<void> updateMyScore(String roomCode, {required int score, required int wordsFound});

  /// מסמן שהסבב הסתיים (זמן נגמר / מישהו הגיע לניקוד היעד) - "מי שראשון
  /// קובע", בטוח לקריאה כפולה מכמה לקוחות בו-זמנית.
  Future<void> finishRoom(String roomCode);

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
  }) =>
      _unavailable();

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
  Future<void> finishRoom(String roomCode) => _unavailable();

  @override
  Future<void> leaveRoom(String roomCode) => _unavailable();
}
