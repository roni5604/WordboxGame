import '../models/room_models.dart';

/// ממשק מופשט למצב רב-משתתפים - יאפשר להחליף מימוש (Firestore, שרת
/// עצמאי, וכו') מבלי לגעת במסכים.
///
/// המימוש בפועל (Firestore) ייכתב בשלב 2 של הפיתוח, לאחר שהחוקים המדויקים
/// (סבבים, ניקוד, מה קורה כשנגמר הזמן) יאומתו מול Wordbox המקורי - ראו
/// "נושאים פתוחים" בתוכנית. המבנה כאן (חדרים, שחקנים, תורות) כבר תואם
/// לארכיטקטורה שתוארה ב-docs/FIREBASE_SETUP.md כדי לחסוך זמן מימוש עתידי.
abstract class MultiplayerRepository {
  Future<GameRoom> createRoom({required String hostDisplayName, int gridSize = 5});
  Future<GameRoom> joinRoom({required String roomCode, required String displayName});
  Stream<GameRoom> watchRoom(String roomCode);
  Future<void> submitWordForTurn(String roomCode, String normalizedWord);
  Future<void> leaveRoom(String roomCode);
}

/// Stub זמני - זורק חריגה ברורה, כדי שממשק המשתמש יידע להציג מסך
/// "בקרוב" במקום לנסות להתחבר לשרת שלא קיים עדיין.
class UnimplementedMultiplayerRepository implements MultiplayerRepository {
  @override
  Future<GameRoom> createRoom({required String hostDisplayName, int gridSize = 5}) {
    throw UnimplementedError('מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית).');
  }

  @override
  Future<GameRoom> joinRoom({required String roomCode, required String displayName}) {
    throw UnimplementedError('מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית).');
  }

  @override
  Stream<GameRoom> watchRoom(String roomCode) {
    throw UnimplementedError('מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית).');
  }

  @override
  Future<void> submitWordForTurn(String roomCode, String normalizedWord) {
    throw UnimplementedError('מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית).');
  }

  @override
  Future<void> leaveRoom(String roomCode) {
    throw UnimplementedError('מצב רב-משתתפים עדיין בפיתוח (שלב 2 בתוכנית).');
  }
}
