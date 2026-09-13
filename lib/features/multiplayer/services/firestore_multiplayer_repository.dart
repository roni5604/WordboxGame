import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/room_models.dart';
import 'multiplayer_repository.dart';

/// מימוש Firestore ל"משחק מול חברים" - חדרים פרטיים עם קוד, מבוססי סבב
/// משותף וסימולטני (בדיוק כמו מצב "משחק מול המחשב" הקיים).
///
/// מבנה מסמכי Firestore:
///   rooms/{roomCode}                - מסמך הגדרות/מצב החדר (ראו room_models.dart)
///   rooms/{roomCode}/players/{uid}  - תת-אוסף לכל שחקן/ית (מונע צוואר בקבוק
///                                     בכתיבה על אותו מסמך כשכולם מעדכנים ניקוד).
///
/// **מודל אבטחה:** הלקוח אמין (client-trusted) - כל שחקן/ית כותב/ת רק
/// לניקוד של עצמו/ה, מאומת מקומית מול הלוח והמילון (בדיוק כמו במשחק
/// יחיד-שחקן, ראו lib/game_engine/game_session.dart). אין Cloud Functions;
/// חוקי firestore.rules אוכפים בעלות/מונוטוניות ניקוד/מעברי סטטוס חוקיים.
/// ראו את חוקי האבטחה ב-firestore.rules לפירוט המלא.
class FirestoreMultiplayerRepository implements MultiplayerRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  FirestoreMultiplayerRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> get _rooms => _firestore.collection('rooms');

  /// קוד חדר בן 5 ספרות (רק 0-9) - קל להקלדה על מקלדת מספרית/בטלפון,
  /// ואין בו בלבול בין אותיות/ספרות דומות (0/O, 1/I) כמו בקוד אלפאנומרי.
  String _generateRoomCode() {
    final rand = Random();
    return List.generate(5, (_) => rand.nextInt(10)).join();
  }

  void _validateCreateSettings({required int totalRounds, required int entryFee}) {
    if (totalRounds < 1 || totalRounds > 10) {
      throw StateError('מספר משחקונים חייב להיות בין 1 ל-10.');
    }
    if (!GameRoom.allowedEntryFees.contains(entryFee)) {
      throw StateError('דמי כניסה לא חוקיים.');
    }
  }

  @override
  Future<String> ensureSignedIn() => _ensureUid();

  Future<String> _ensureUid() async {
    final current = _auth.currentUser;
    if (current != null) return current.uid;
    final credential = await _auth.signInAnonymously();
    return credential.user!.uid;
  }

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
  }) async {
    _validateCreateSettings(totalRounds: totalRounds, entryFee: entryFee);
    final uid = await _ensureUid();

    // מנסים כמה קודים במקרה הנדיר של התנגשות עם חדר קיים שעדיין פעיל.
    for (int attempt = 0; attempt < 5; attempt++) {
      final roomCode = _generateRoomCode();
      final roomRef = _rooms.doc(roomCode);
      final existing = await roomRef.get();
      if (existing.exists) continue;

      final boardSeed = Random().nextInt(1 << 31);
      final joinDeadline = DateTime.now().add(joinWindow);

      await roomRef.set({
        'status': RoomStatus.waiting.name,
        'hostUid': uid,
        'gridSize': gridSize,
        'boardSeed': boardSeed,
        'roundSeconds': roundSeconds,
        'targetScore': targetScore,
        'maxPlayers': maxPlayers,
        'totalRounds': totalRounds,
        'currentRound': 1,
        'entryFee': entryFee,
        'pot': entryFee,
        'paidUids': {uid: true},
        'potAwarded': false,
        'joinDeadline': Timestamp.fromDate(joinDeadline),
        'startedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await roomRef.collection('players').doc(uid).set({
        'displayName': hostDisplayName,
        'score': 0,
        'wordsFound': 0,
        'isHost': true,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      return GameRoom(
        roomCode: roomCode,
        status: RoomStatus.waiting,
        hostUid: uid,
        gridSize: gridSize,
        boardSeed: boardSeed,
        roundSeconds: roundSeconds,
        targetScore: targetScore,
        maxPlayers: maxPlayers,
        totalRounds: totalRounds,
        currentRound: 1,
        entryFee: entryFee,
        pot: entryFee,
        paidUids: {uid: true},
        joinDeadline: joinDeadline,
        players: [
          PlayerInRoom(uid: uid, displayName: hostDisplayName, isHost: true),
        ],
      );
    }

    throw StateError('לא הצלחנו ליצור חדר כרגע - נסו שוב.');
  }

  @override
  Future<GameRoom> fetchRoom(String roomCode) async {
    final code = roomCode.trim();
    final roomSnap = await _rooms.doc(code).get();
    if (!roomSnap.exists || roomSnap.data() == null) {
      throw StateError('חדר עם הקוד $code לא נמצא.');
    }
    return _readRoom(code);
  }

  @override
  Future<GameRoom> joinRoom({required String roomCode, required String displayName}) async {
    final code = roomCode.trim();
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(code);
    final roomSnap = await roomRef.get();
    if (!roomSnap.exists) {
      throw StateError('חדר עם הקוד $code לא נמצא.');
    }

    final room = _mapRoom(code, roomSnap.data()!, const []);
    final alreadyJoined = (await roomRef.collection('players').doc(uid).get()).exists;

    if (!alreadyJoined) {
      if (room.status != RoomStatus.waiting) {
        throw StateError('המשחק בחדר הזה כבר התחיל.');
      }
      if (!room.isJoinWindowOpen) {
        throw StateError('תוקף הקוד פג - בקשו קוד חדש ממנהל/ת החדר.');
      }
      final playersSnap = await roomRef.collection('players').get();
      if (playersSnap.docs.length >= room.maxPlayers) {
        throw StateError('החדר מלא (מקסימום ${room.maxPlayers} שחקנים).');
      }

      final alreadyPaid = room.paidUids[uid] == true;
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        final data = snap.data();
        if (data == null) throw StateError('חדר עם הקוד $code לא נמצא.');

        tx.set(roomRef.collection('players').doc(uid), {
          'displayName': displayName,
          'score': 0,
          'wordsFound': 0,
          'isHost': false,
          'joinedAt': FieldValue.serverTimestamp(),
        });

        if (!alreadyPaid) {
          final paid = Map<String, dynamic>.from(data['paidUids'] as Map? ?? {});
          if (paid[uid] != true) {
            paid[uid] = true;
            final entryFee = (data['entryFee'] as num?)?.toInt() ?? room.entryFee;
            tx.update(roomRef, {
              'paidUids': paid,
              'pot': ((data['pot'] as num?)?.toInt() ?? 0) + entryFee,
            });
          }
        }
      });
    }

    return _readRoom(code);
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
      hostUid: data['hostUid'] as String? ?? '',
      gridSize: (data['gridSize'] as num?)?.toInt() ?? 5,
      boardSeed: (data['boardSeed'] as num?)?.toInt() ?? 0,
      roundSeconds: (data['roundSeconds'] as num?)?.toInt() ?? 90,
      targetScore: (data['targetScore'] as num?)?.toInt() ?? 0,
      maxPlayers: (data['maxPlayers'] as num?)?.toInt() ?? GameRoom.defaultMaxPlayers,
      totalRounds: (data['totalRounds'] as num?)?.toInt() ?? 1,
      currentRound: (data['currentRound'] as num?)?.toInt() ?? 1,
      entryFee: (data['entryFee'] as num?)?.toInt() ?? 5,
      pot: (data['pot'] as num?)?.toInt() ?? 0,
      paidUids: (data['paidUids'] as Map<String, dynamic>?)?.map(
            (uid, paid) => MapEntry(uid, paid == true),
          ) ??
          const {},
      potAwarded: data['potAwarded'] as bool? ?? false,
      joinDeadline: (data['joinDeadline'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      wins: (data['wins'] as Map<String, dynamic>?)?.map(
            (uid, winCount) => MapEntry(uid, (winCount as num?)?.toInt() ?? 0),
          ) ??
          const {},
      players: [
        for (final doc in playerDocs)
          PlayerInRoom(
            uid: doc.id,
            displayName: doc.data()['displayName'] as String? ?? '?',
            score: (doc.data()['score'] as num?)?.toInt() ?? 0,
            wordsFound: (doc.data()['wordsFound'] as num?)?.toInt() ?? 0,
            isHost: doc.data()['isHost'] as bool? ?? false,
          ),
      ],
    );
  }

  @override
  Stream<GameRoom> watchRoom(String roomCode) {
    // ממזג את מאזין מסמך החדר עם מאזין תת-אוסף השחקנים לזרם אחד מאוחד,
    // כדי שהלובי/המסך יתעדכנו בזמן אמת גם כששחקן/ית חדש/ה מצטרף/ת (שינוי
    // שלא נוגע במסמך החדר עצמו, ולכן חייב מאזין נפרד על תת-האוסף).
    late StreamController<GameRoom> controller;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? roomSub;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? playersSub;

    DocumentSnapshot<Map<String, dynamic>>? latestRoom;
    List<QueryDocumentSnapshot<Map<String, dynamic>>> latestPlayers = [];
    // שני המאזינים נפתחים במקביל, ולא מובטח מי מהם יספק את המצב הראשוני
    // שלו קודם - בלי ה"שערים" האלה, אירוע ראשוני של אחד מהם (למשל מסמך
    // החדר) יכול "לדלוף" ל-emit() לפני שתת-אוסף השחקנים סיפק אפילו רגע
    // אחד, וכך לגרום לפריצת רגע אחד עם 0 שחקנים גם כשהחדר לא ריק בפועל.
    bool roomReady = false;
    bool playersReady = false;

    void emit() {
      if (!roomReady || !playersReady) return;
      final roomData = latestRoom?.data();
      if (roomData == null) return;
      controller.add(_mapRoom(roomCode, roomData, latestPlayers));
    }

    controller = StreamController<GameRoom>.broadcast(
      onListen: () {
        roomSub = _rooms.doc(roomCode).snapshots().listen(
              (snap) {
                latestRoom = snap;
                roomReady = true;
                emit();
              },
              onError: controller.addError,
            );
        playersSub = _rooms.doc(roomCode).collection('players').snapshots().listen(
              (snap) {
                latestPlayers = snap.docs;
                playersReady = true;
                emit();
              },
              onError: controller.addError,
            );
      },
      onCancel: () {
        roomSub?.cancel();
        playersSub?.cancel();
      },
    );

    return controller.stream;
  }

  @override
  Future<void> startGame(String roomCode) async {
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(roomCode);
    final snap = await roomRef.get();
    final data = snap.data();
    if (data == null) throw StateError('החדר לא נמצא.');
    if (data['hostUid'] != uid) {
      throw StateError('רק מנהל/ת החדר יכול/ה להתחיל את המשחק.');
    }
    await roomRef.update({
      'status': RoomStatus.inProgress.name,
      'startedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> updateMyScore(String roomCode, {required int score, required int wordsFound}) async {
    final uid = await _ensureUid();
    await _rooms.doc(roomCode).collection('players').doc(uid).update({
      'score': score,
      'wordsFound': wordsFound,
    });
  }

  @override
  Future<void> finishRoom(String roomCode, {String? winnerUid}) async {
    final roomRef = _rooms.doc(roomCode);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(roomRef);
        final data = snap.data();
        if (data == null) return;
        if (data['status'] == RoomStatus.finished.name) return;

        final currentRound = (data['currentRound'] as num?)?.toInt() ?? 1;
        final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 1;
        final update = <String, dynamic>{'status': RoomStatus.finished.name};
        // מונה הניצחונות מתקדם רק כאן (בתוך אותה טרנזקציה שמסמנת finished
        // בפעם הראשונה) - כך "מי שראשון קובע" ממנע ספירה כפולה גם אם כמה
        // לקוחות מנסים לסיים את הסבב בו-זמנית.
        if (winnerUid != null) {
          final wins = Map<String, dynamic>.from(data['wins'] as Map? ?? {});
          wins[winnerUid] = ((wins[winnerUid] as num?)?.toInt() ?? 0) + 1;
          update['wins'] = wins;
        }
        if (currentRound >= totalRounds) {
          update['potAwarded'] = true;
        }
        tx.update(roomRef, update);
      });
    } on FirebaseException {
      // "מי שראשון קובע" - אם לקוח אחר כבר סימן שהחדר הסתיים, אין בעיה.
    }
  }

  @override
  Future<void> restartRoom(String roomCode) async {
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(roomCode);
    final snap = await roomRef.get();
    final data = snap.data();
    if (data == null) throw StateError('החדר לא נמצא.');
    if (data['hostUid'] != uid) {
      throw StateError('רק מנהל/ת החדר יכול/ה להתחיל משחק חוזר.');
    }
    if (data['status'] != RoomStatus.finished.name) {
      throw StateError('אפשר להתחיל משחק חוזר רק אחרי שהסבב הנוכחי הסתיים.');
    }

    final playersSnap = await roomRef.collection('players').get();
    final batch = _firestore.batch();
    batch.update(roomRef, {
      'status': RoomStatus.waiting.name,
      'boardSeed': Random().nextInt(1 << 31),
      'startedAt': null,
    });
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {'score': 0, 'wordsFound': 0});
    }
    await batch.commit();
  }

  @override
  Future<void> startNextRound(String roomCode) async {
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(roomCode);
    final snap = await roomRef.get();
    final data = snap.data();
    if (data == null) throw StateError('החדר לא נמצא.');
    if (data['hostUid'] != uid) {
      throw StateError('רק מנהל/ת החדר יכול/ה להתחיל את הסבב הבא.');
    }
    if (data['status'] != RoomStatus.finished.name) {
      throw StateError('אפשר להתחיל סבב הבא רק אחרי שהסבב הנוכחי הסתיים.');
    }
    final currentRound = (data['currentRound'] as num?)?.toInt() ?? 1;
    final totalRounds = (data['totalRounds'] as num?)?.toInt() ?? 1;
    if (currentRound >= totalRounds) {
      throw StateError('אין סבב נוסף בסדרה הזו.');
    }

    final playersSnap = await roomRef.collection('players').get();
    final batch = _firestore.batch();
    batch.update(roomRef, {
      'status': RoomStatus.inProgress.name,
      'boardSeed': Random().nextInt(1 << 31),
      'startedAt': FieldValue.serverTimestamp(),
      'currentRound': currentRound + 1,
    });
    for (final doc in playersSnap.docs) {
      batch.update(doc.reference, {'score': 0, 'wordsFound': 0});
    }
    await batch.commit();
  }

  @override
  Future<void> leaveRoom(String roomCode) async {
    final uid = await _ensureUid();
    final roomRef = _rooms.doc(roomCode);
    final snap = await roomRef.get();
    final data = snap.data();
    final batch = _firestore.batch();
    batch.delete(roomRef.collection('players').doc(uid));
    if (data != null && data['status'] == RoomStatus.waiting.name) {
      final paid = Map<String, dynamic>.from(data['paidUids'] as Map? ?? {});
      if (paid[uid] == true) {
        final entryFee = (data['entryFee'] as num?)?.toInt() ?? 0;
        final nextPot = ((data['pot'] as num?)?.toInt() ?? 0) - entryFee;
        batch.update(roomRef, {
          'paidUids.$uid': FieldValue.delete(),
          'pot': nextPot < 0 ? 0 : nextPot,
        });
      }
    }
    await batch.commit();
  }
}
