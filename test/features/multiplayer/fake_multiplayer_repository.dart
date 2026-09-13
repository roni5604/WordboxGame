import 'dart:async';

import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/services/multiplayer_repository.dart';

/// תיעוד פרמטרים של קריאה ל-createRoom, לצורך אימות בבדיקות.
class CreateRoomCall {
  final String hostDisplayName;
  final int gridSize;
  final int roundSeconds;
  final int targetScore;
  final int maxPlayers;
  final Duration joinWindow;

  CreateRoomCall({
    required this.hostDisplayName,
    required this.gridSize,
    required this.roundSeconds,
    required this.targetScore,
    required this.maxPlayers,
    required this.joinWindow,
  });
}

/// מימוש מזויף (fake) של [MultiplayerRepository] לבדיקות UI - שולט באופן
/// מלא בתוצאות/שגיאות ומאפשר לדחוף עדכוני חדר ידניים דרך [pushRoomUpdate]
/// כדי לבדוק תגובת המסכים לשינויים בזמן אמת (למשל תחילת משחק).
class FakeMultiplayerRepository implements MultiplayerRepository {
  final List<CreateRoomCall> createRoomCalls = [];
  final List<String> startGameCalls = [];
  final List<String> leaveRoomCalls = [];
  final List<({String roomCode, String? winnerUid})> finishRoomCalls = [];
  final List<String> restartRoomCalls = [];
  final List<({String roomCode, int score, int wordsFound})> updateScoreCalls = [];
  Object? restartRoomError;

  String myUid = 'me-uid';
  GameRoom? lastCreatedRoom;
  Object? createRoomError;
  Object? joinRoomError;
  GameRoom Function(String roomCode, String displayName)? joinRoomResultBuilder;

  final Map<String, StreamController<GameRoom>> _controllers = {};

  StreamController<GameRoom> _controllerFor(String roomCode) =>
      _controllers.putIfAbsent(roomCode, () => StreamController<GameRoom>.broadcast());

  /// דוחף עדכון חדר ידני לכל מי שמאזין ל-watchRoom(roomCode) - מדמה עדכון
  /// שהיה מגיע מ-Firestore בפועל (למשל שחקן/ית מצטרף/ת, המנהל/ת מתחיל/ה).
  void pushRoomUpdate(GameRoom room) {
    _controllerFor(room.roomCode).add(room);
  }

  @override
  Future<String> ensureSignedIn() async => myUid;

  @override
  Future<GameRoom> createRoom({
    required String hostDisplayName,
    required int gridSize,
    required int roundSeconds,
    required int targetScore,
    required int maxPlayers,
    required Duration joinWindow,
  }) async {
    createRoomCalls.add(CreateRoomCall(
      hostDisplayName: hostDisplayName,
      gridSize: gridSize,
      roundSeconds: roundSeconds,
      targetScore: targetScore,
      maxPlayers: maxPlayers,
      joinWindow: joinWindow,
    ));
    if (createRoomError != null) throw createRoomError!;

    final room = GameRoom(
      roomCode: 'ABCDE',
      status: RoomStatus.waiting,
      hostUid: myUid,
      gridSize: gridSize,
      boardSeed: 1234,
      roundSeconds: roundSeconds,
      targetScore: targetScore,
      maxPlayers: maxPlayers,
      joinDeadline: DateTime.now().add(joinWindow),
      players: [PlayerInRoom(uid: myUid, displayName: hostDisplayName, isHost: true)],
    );
    lastCreatedRoom = room;
    return room;
  }

  @override
  Future<GameRoom> joinRoom({required String roomCode, required String displayName}) async {
    if (joinRoomError != null) throw joinRoomError!;
    if (joinRoomResultBuilder != null) return joinRoomResultBuilder!(roomCode, displayName);

    return GameRoom(
      roomCode: roomCode,
      status: RoomStatus.waiting,
      hostUid: 'someone-else',
      gridSize: 5,
      boardSeed: 1,
      roundSeconds: 90,
      targetScore: 0,
      maxPlayers: 6,
      players: [
        const PlayerInRoom(uid: 'someone-else', displayName: 'מנהל', isHost: true),
        PlayerInRoom(uid: myUid, displayName: displayName),
      ],
    );
  }

  @override
  Stream<GameRoom> watchRoom(String roomCode) => _controllerFor(roomCode).stream;

  @override
  Future<void> startGame(String roomCode) async {
    startGameCalls.add(roomCode);
  }

  @override
  Future<void> updateMyScore(String roomCode, {required int score, required int wordsFound}) async {
    updateScoreCalls.add((roomCode: roomCode, score: score, wordsFound: wordsFound));
  }

  @override
  Future<void> finishRoom(String roomCode, {String? winnerUid}) async {
    finishRoomCalls.add((roomCode: roomCode, winnerUid: winnerUid));
  }

  @override
  Future<void> restartRoom(String roomCode) async {
    restartRoomCalls.add(roomCode);
    if (restartRoomError != null) throw restartRoomError!;
  }

  @override
  Future<void> leaveRoom(String roomCode) async {
    leaveRoomCalls.add(roomCode);
  }
}
