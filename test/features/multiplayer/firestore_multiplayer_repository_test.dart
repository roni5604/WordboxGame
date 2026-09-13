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
      expect(room.totalRounds, 1);
      expect(room.currentRound, 1);
      expect(room.entryFee, 5);
      expect(room.pot, 5);
      expect(room.paidUids['host-uid'], isTrue);
    });

    test('יוצר חדר עם מספר משחקונים ודמי כניסה שנבחרו', () async {
      final host = repoFor('host-uid', name: 'דנה');
      final room = await host.createRoom(
        hostDisplayName: 'דנה',
        gridSize: 5,
        roundSeconds: 90,
        targetScore: 0,
        maxPlayers: 8,
        joinWindow: const Duration(minutes: 10),
        totalRounds: 4,
        entryFee: 20,
      );

      expect(room.totalRounds, 4);
      expect(room.entryFee, 20);
      expect(room.pot, 20);
    });
  });

  group('fetchRoom', () {
    test('מחזיר חדר קיים בלי להצטרף', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
        entryFee: 10,
      );

      final guest = repoFor('guest-uid');
      final peeked = await guest.fetchRoom(room.roomCode);
      expect(peeked.entryFee, 10);
      expect(peeked.pot, 10);
      expect(peeked.players, hasLength(1));
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
      expect(updated.pot, 10);
      expect(updated.paidUids['guest-uid'], isTrue);
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

    test('עם winnerUid מקדם את מונה הניצחונות שלו/ה באחד', () async {
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
      await host.startGame(room.roomCode);

      await host.finishRoom(room.roomCode, winnerUid: 'guest-uid');
      // מאפשר לזרם ה-snapshots הפנימי של fake_cloud_firestore לפלוט את
      // העדכון שכתבנו בטרנזקציה לפני שנפתח מאזין watchRoom חדש (ראו
      // גם את בדיקת watchRoom למטה שמשתמשת באותה טכניקה).
      await Future<void>.delayed(Duration.zero);

      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.wins['guest-uid'], 1);
      expect(updated.wins['host-uid'], isNull);
    });

    test('קריאה כפולה עם winnerUid לא מכפילה את הספירה ("מי שראשון קובע")', () async {
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

      await host.finishRoom(room.roomCode, winnerUid: 'host-uid');
      await host.finishRoom(room.roomCode, winnerUid: 'host-uid');
      await Future<void>.delayed(Duration.zero);

      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.wins['host-uid'], 1);
    });
  });

  group('restartRoom', () {
    test('רק המנהל/ת יכול/ה להתחיל משחק חוזר, ורק אחרי שהסבב הסתיים', () async {
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
      await host.startGame(room.roomCode);

      expect(() => host.restartRoom(room.roomCode), throwsA(isA<StateError>()));
      expect(() => guest.restartRoom(room.roomCode), throwsA(isA<StateError>()));

      await host.finishRoom(room.roomCode, winnerUid: 'host-uid');
      await guest.updateMyScore(room.roomCode, score: 30, wordsFound: 4);

      expect(() => guest.restartRoom(room.roomCode), throwsA(isA<StateError>()));

      final oldSeed = room.boardSeed;
      await host.restartRoom(room.roomCode);

      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.status, RoomStatus.waiting);
      expect(updated.startedAt, isNull);
      expect(updated.boardSeed, isNot(oldSeed));
      // הגדרות המשחק ומונה הניצחונות המצטבר נשמרים.
      expect(updated.gridSize, 4);
      expect(updated.wins['host-uid'], 1);
      // הניקוד של כל השחקנים/ות מתאפס לסבב הבא.
      for (final player in updated.players) {
        expect(player.score, 0);
        expect(player.wordsFound, 0);
      }
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
      expect(updated.pot, 5);
      expect(updated.paidUids.containsKey('guest-uid'), isFalse);
    });
  });

  group('startNextRound', () {
    test('המנהל/ת מעלה סבב ומתחיל משחק בלי לגעת בקופה', () async {
      final host = repoFor('host-uid');
      final room = await host.createRoom(
        hostDisplayName: 'מנהל',
        gridSize: 4,
        roundSeconds: 60,
        targetScore: 0,
        maxPlayers: 4,
        joinWindow: const Duration(minutes: 10),
        totalRounds: 3,
        entryFee: 10,
      );
      final guest = repoFor('guest-uid');
      await guest.joinRoom(roomCode: room.roomCode, displayName: 'עומר');
      await host.startGame(room.roomCode);
      await host.finishRoom(room.roomCode, winnerUid: 'host-uid');
      await Future<void>.delayed(Duration.zero);

      expect(() => guest.startNextRound(room.roomCode), throwsA(isA<StateError>()));

      await host.startNextRound(room.roomCode);
      final updated = await host.watchRoom(room.roomCode).first;
      expect(updated.status, RoomStatus.inProgress);
      expect(updated.currentRound, 2);
      expect(updated.pot, 20);
      expect(updated.entryFee, 10);
      expect(updated.wins['host-uid'], 1);
      for (final player in updated.players) {
        expect(player.score, 0);
      }
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
