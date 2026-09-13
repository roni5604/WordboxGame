import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordbox_hebrew/features/multiplayer/models/room_models.dart';
import 'package:wordbox_hebrew/features/multiplayer/services/firestore_multiplayer_repository.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  FirestoreMultiplayerRepository repoFor(String uid, {String? name}) {
    final auth = MockFirebaseAuth(
      signedIn: true,
      mockUser: MockUser(uid: uid, displayName: name ?? uid),
    );
    return FirestoreMultiplayerRepository(firestore: firestore, auth: auth);
  }

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  group('createRoom', () {
    test('יוצר חדר עם קוד תקין, המנהל/ת ברשימת השחקנים, ומזהה כמנהל/ת', () async {
      final host = repoFor('host-uid', name: 'דנה');
      final room = await host.createRoom(
        hostDisplayName: 'דנה',
        gridSize: 5,
        roundSeconds: 90,
        targetScore: 0,
        maxPlayers: 6,
        joinWindow: const Duration(minutes: 10),
      );

      expect(room.roomCode.length, 5);
      expect(room.status, RoomStatus.waiting);
      expect(room.hostUid, 'host-uid');
      expect(room.gridSize, 5);
      expect(room.roundSeconds, 90);
      expect(room.players, hasLength(1));
      expect(room.players.single.isHost, isTrue);
      expect(room.players.single.displayName, 'דנה');
      expect(room.isJoinWindowOpen, isTrue);
    });
  });

  group('joinRoom', () {
    test('שחקן/ית שני/ה מצטרפ/ת בהצלחה ורואה את שני השחקנים בחדר', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );

      final guest = repoFor('guest-uid');
      final updated = await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      expect(updated.players, hasLength(2));
      expect(updated.players.map((p) => p.displayName), containsAll(['מנהל', 'עומר']));
      expect(updated.players.firstWhere((p) => p.uid == 'guest-uid').isHost, isFalse);
    });

    test('זורק שגיאה כשהחדר לא קיים', () async {
      final guest = repoFor('guest-uid');
      expect(
        () => guest.joinRoom(roomCode: 'ZZZZZ', displayName: 'מישהו'),
        throwsA(isA<StateError>()),
      );
    });

    test('זורק שגיאה כשהחדר מלא', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 1,
        joinWindow: const Duration(minutes: 10),
      );

      final guest = repoFor('guest-uid');
      expect(
        () => guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר'),
        throwsA(isA<StateError>()),
      );
    });

    test('זורק שגיאה כשהמשחק כבר התחיל', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );
      await host.startGame(room.roomCode);

      final guest = repoFor('guest-uid');
      expect(
        () => guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר'),
        throwsA(isA<StateError>()),
      );
    });

    test('הצטרפות כפולה של אותו שחקן/ית לא יוצרת כפילות', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );

      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');
      final second = await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      expect(second.players, hasLength(2));
    });

    test('הקוד מורכב מספרות בלבד (בלי אותיות מבלבלות)', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );

      expect(RegExp(r'^[0-9]{5}$').hasMatch(room.roomCode), isTrue);
    });
  });

  group('startGame', () {
    test('רק המנהל/ת יכול/ה להתחיל את המשחק', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );
      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      expect(() => guest.startGame(room.roomCode), throwsA(isA<StateError>()));

      await host.startGame(room.roomCode);
      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.status, RoomStatus.inProgress);
      expect(updated.startedAt, isNotNull);
    });
  });

  group('updateMyScore', () {
    test('מעדכן ניקוד ומספר מילים אישיים בלבד', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );
      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      await guest.updateMyScore(room.roomCode, score: 42, wordsFound: 5);

      final updated = await host.watchRoom(room.roomCode).first;
      final guestPlayer = updated.players.firstWhere((p) => p.uid == 'guest-uid');
      expect(guestPlayer.score, 42);
      expect(guestPlayer.wordsFound, 5);
      // המנהל/ת לא נפגע/ה מעדכון הניקוד של שחקן/ית אחר/ת.
      final hostPlayer = updated.players.firstWhere((p) => p.uid == 'host-uid');
      expect(hostPlayer.score, 0);
    });
  });

  group('finishRoom', () {
    test('מעביר את הסבב למצב finished, וקריאה כפולה בטוחה (אין שגיאה)', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );
      await host.startGame(room.roomCode);

      await host.finishRoom(room.roomCode);
      await host.finishRoom(room.roomCode); // "מי שראשון קובע" - לא זורק שגיאה.

      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.status, RoomStatus.finished);
    });
  });

  group('leaveRoom', () {
    test('מוחק את מסמך השחקן/ית מתת-האוסף', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );
      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      await guest.leaveRoom(room.roomCode);

      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.players, hasLength(1));
      expect(updated.players.single.uid, 'host-uid');
    });
  });

  group('watchRoom', () {
    test('פולט עדכון גם כששחקן/ית חדש/ה מצטרף/ת (לא רק בשינוי מסמך החדר)', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
      );

      final emittedPlayerCounts = <int>[];
      final subscription = host.watchRoom(room.roomCode).listen((r) {
        emittedPlayerCounts.add(r.players.length);
      });

      // מאפשר לזרם הראשוני להיפלט לפני שהשחקן/ית השני/ה מצטרף/ת.
      await Future<void>.delayed(Duration.zero);

      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');

      await Future<void>.delayed(Duration.zero);
      await subscription.cancel();

      expect(emittedPlayerCounts, contains(2));
    });
  });
}
