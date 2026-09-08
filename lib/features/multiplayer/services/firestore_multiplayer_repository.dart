import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/room_models.dart';
import 'multiplayer_repository.dart';

/// מימוש Firestore למצב רב-משתתפים מבוסס תורות.
///
/// **לא מחובר כברירת מחדל** - ראו הערת הרישוי/אימות החוקים בתוכנית
/// (docs/GAME_DESIGN.md, סעיף "מצב רב-משתתפים"). לפני הפעלה בפרודקשן יש:
/// 1. להריץ `flutterfire configure` ולהפעיל AppConfig.useFirebaseBackend.
/// 2. לפרוס את חוקי האבטחה של Firestore (firestore.rules) כך שרק בעל
///    התור הנוכחי יכול לכתוב מילה, וכל שאר הכתיבות (טעינת השלב הבא,
///    בדיקת הזמן) יתבצעו ב-Cloud Function ולא ישירות מהלקוח.
/// 3. להוסיף Cloud Function שמאמתת את המילה מול המילון בצד שרת (כדי
///    שלקוח לא יוכל "לרמות" ולשלוח מילה לא חוקית עם ניקוד גבוה).
///
/// המימוש כאן הוא נקודת התחלה סבירה ללקוח (UI + מאזינים בזמן אמת),
/// ומדגים את מבנה מסמכי Firestore המומלץ:
///   rooms/{roomCode}                - מסמך מצב החדר (סבב, תור, סטטוס)
///   rooms/{roomCode}/players/{uid}  - תת-אוסף לכל שחקן (מונע צוואר בקבוק
///                                     בכתיבה על אותו מסמך, ראו open items).
class FirestoreMultiplayerRepository implements MultiplayerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreMultiplayerRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _rooms => _firestore.collection('rooms');

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(5, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> _ensureUid() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

  @override
  Future<GameRoom> createRoom({required String hostDisplayName, int gridSize = 5}) async {
    final uid = await _ensureUid();
    final roomCode = _generateRoomCode();

    final host = PlayerInRoom(uid: uid, displayName: hostDisplayName, isHost: true);

    await _rooms.doc(roomCode).set({
      'status': RoomStatus.waiting.name,
      'gridSize': gridSize,
      'currentTurnUid': null,
      'turnSecondsRemaining': 30,
      'roundNumber': 1,
      'maxRounds': 5,
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _rooms.doc(roomCode).collection('players').doc(uid).set({
      'displayName': hostDisplayName,
      'score': 0,
      'isHost': true,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return GameRoom(roomCode: roomCode, status: RoomStatus.waiting, players: [host], gridSize: gridSize);
  }

  @override
  Future<GameRoom> joinRoom({required String roomCode, required String displayName}) async {
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(roomCode);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw StateError('חדר עם הקוד $roomCode לא נמצא.');
    }

    await roomRef.collection('players').doc(uid).set({
      'displayName': displayName,
      'score': 0,
      'isHost': false,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    return _readRoom(roomCode);
  }

  Future<GameRoom> _readRoom(String roomCode) async {
    final roomSnap = await _rooms.doc(roomCode).get();
    final playersSnap = await _rooms.doc(roomCode).collection('players').get();
    return _mapRoom(roomCode, roomSnap.data()!, playersSnap.docs);
  }

  GameRoom _mapRoom(
    String roomCode,
    Map<String, dynamic> data,
    List<QueryDocumentSnapshot<Map<String, dynamic>>> playerDocs,
  ) {
    return GameRoom(
      roomCode: roomCode,
      status: RoomStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RoomStatus.waiting,
      ),
      gridSize: (data['gridSize'] as num?)?.toInt() ?? 5,
      currentTurnUid: data['currentTurnUid'] as String?,
      turnSecondsRemaining: (data['turnSecondsRemaining'] as num?)?.toInt() ?? 30,
      roundNumber: (data['roundNumber'] as num?)?.toInt() ?? 1,
      maxRounds: (data['maxRounds'] as num?)?.toInt() ?? 5,
      players: [
        for (final doc in playerDocs)
          PlayerInRoom(
            uid: doc.id,
            displayName: doc.data()['displayName'] as String? ?? '?',
            score: (doc.data()['score'] as num?)?.toInt() ?? 0,
            isHost: doc.data()['isHost'] as bool? ?? false,
          ),
      ],
    );
  }

  @override
  Stream<GameRoom> watchRoom(String roomCode) {
    // ממזג את מאזין מסמך החדר עם מאזין תת-אוסף השחקנים לזרם אחד מאוחד.
    final roomStream = _rooms.doc(roomCode).snapshots();
    return roomStream.asyncMap((roomSnap) async {
      final playersSnap = await _rooms.doc(roomCode).collection('players').get();
      return _mapRoom(roomCode, roomSnap.data() ?? {}, playersSnap.docs);
    });
  }

  @override
  Future<void> submitWordForTurn(String roomCode, String normalizedWord) async {
    // הערה: בפרודקשן יש להעביר את הולידציה הזו ל-Cloud Function (callable)
    // כדי שהלקוח לא יוכל לזייף ניקוד. כאן, לצורך שלד ראשוני, אנחנו רק
    // מדגימים את הכתיבה הטרנזקציונית הבסיסית.
    final uid = await _ensureUid();
    final playerRef = _rooms.doc(roomCode).collection('players').doc(uid);

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(playerRef);
      final currentScore = (snap.data()?['score'] as num?)?.toInt() ?? 0;
      tx.update(playerRef, {'score': currentScore + normalizedWord.length});
    });
  }

  @override
  Future<void> leaveRoom(String roomCode) async {
    final uid = await _ensureUid();
    await _rooms.doc(roomCode).collection('players').doc(uid).delete();
  }
}
