import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/social_models.dart';

/// שגיאה ידידותית בעברית מהשכבה החברתית - ה-UI מציג את [message] כמו שהיא.
class SocialException implements Exception {
  final String message;
  const SocialException(this.message);

  @override
  String toString() => message;
}

/// הנתונים שאני מפרסם/ת בכרטיס הציבורי שלי.
class MyPublicInfo {
  final String displayName;
  final String avatarId;
  final String? photoUrl;
  final int totalStars;
  final int highestLevel;

  /// תוצאת האתגר היומי האחרונה (לדירוג "אתגר היום" אצל חברים).
  final String? dailyDate;
  final int dailyScore;
  final int dailyStreak;

  const MyPublicInfo({
    required this.displayName,
    required this.avatarId,
    this.photoUrl,
    required this.totalStars,
    required this.highestLevel,
    this.dailyDate,
    this.dailyScore = 0,
    this.dailyStreak = 0,
  });

  @override
  bool operator ==(Object other) =>
      other is MyPublicInfo &&
      other.displayName == displayName &&
      other.avatarId == avatarId &&
      other.photoUrl == photoUrl &&
      other.totalStars == totalStars &&
      other.highestLevel == highestLevel &&
      other.dailyDate == dailyDate &&
      other.dailyScore == dailyScore &&
      other.dailyStreak == dailyStreak;

  @override
  int get hashCode =>
      Object.hash(displayName, avatarId, photoUrl, totalStars, highestLevel, dailyDate, dailyScore, dailyStreak);
}

/// כל מה שקשור לחברים: כרטיס ציבורי, נוכחות (מי מחובר), בקשות חברות,
/// רשימת חברים עם מאזן "ראש בראש", והזמנות למשחק בזמן אמת.
///
/// המימוש בפועל - [FirestoreSocialRepository]. במצב אופליין -
/// [OfflineSocialRepository] (זרמים ריקים, פעולות שמסבירות שצריך חיבור).
abstract class SocialRepository {
  bool get isAvailable;

  Future<String> ensureSignedIn();

  /// הקוד הקצר שחברים מקלידים כדי להוסיף אותי.
  Future<String> myFriendCode();

  Future<void> publishMyProfile(MyPublicInfo info);

  /// פעימת נוכחות - נקראת כל דקה כשהאפליקציה פתוחה.
  Future<void> heartbeat(PresenceStatus status);

  Future<void> goOffline();

  Stream<List<FriendEntry>> watchFriends();
  Stream<List<FriendRequest>> watchIncomingRequests();
  Stream<List<FriendRequest>> watchOutgoingRequests();

  Future<PublicProfile?> findByFriendCode(String code);
  Future<List<PublicProfile>> fetchProfiles(List<String> uids);

  /// שולח בקשת חברות. אם הצד השני כבר ביקש ממני - מאשר מיד.
  /// מחזיר true אם הפכנו לחברים מיד.
  Future<bool> sendFriendRequest(String toUid, {String toName = ''});
  Future<void> acceptFriendRequest(FriendRequest request);
  Future<void> declineFriendRequest(FriendRequest request);
  Future<void> cancelFriendRequest(String toUid);
  Future<void> removeFriend(String friendUid);

  Future<GameInvite> sendInvite({
    required String toUid,
    String toName = '',
    required String roomCode,
    required int gridSize,
    required int roundSeconds,
    required int entryFee,
  });
  Stream<List<GameInvite>> watchIncomingInvites();
  Stream<List<GameInvite>> watchSentInvites(String roomCode);
  Future<void> respondToInvite(GameInvite invite, {required bool accept});

  /// מעדכן סטטיסטיקה אחרי משחק בחדר פרטי: המונה הכללי שלי, ומאזן "ראש
  /// בראש" מול כל יריב/ה שהוא/היא גם חבר/ה.
  Future<void> recordMatch({required Map<String, int> scores, required String myUid});

  /// קוד חבר דטרמיניסטי מתוך ה-uid: 6 תווים בלי תווים מבלבלים (0/O, 1/I).
  static String friendCodeFor(String uid) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final bytes = sha1.convert(utf8.encode('wordbox-friend:$uid')).bytes;
    return String.fromCharCodes([
      for (int i = 0; i < 6; i++) alphabet.codeUnitAt(bytes[i] % alphabet.length),
    ]);
  }

  static String normalizeFriendCode(String input) =>
      input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
}

/// מימוש "אופליין" - כשאין Firebase. הזרמים ריקים והפעולות מסבירות למה.
class OfflineSocialRepository implements SocialRepository {
  static const _message = 'חברים ומשחק משותף דורשים חיבור לאינטרנט.';

  Never _fail() => throw const SocialException(_message);

  @override
  bool get isAvailable => false;

  @override
  Future<String> ensureSignedIn() async => _fail();

  @override
  Future<String> myFriendCode() async => _fail();

  @override
  Future<void> publishMyProfile(MyPublicInfo info) async {}

  @override
  Future<void> heartbeat(PresenceStatus status) async {}

  @override
  Future<void> goOffline() async {}

  @override
  Stream<List<FriendEntry>> watchFriends() => Stream.value(const []);

  @override
  Stream<List<FriendRequest>> watchIncomingRequests() => Stream.value(const []);

  @override
  Stream<List<FriendRequest>> watchOutgoingRequests() => Stream.value(const []);

  @override
  Future<PublicProfile?> findByFriendCode(String code) async => _fail();

  @override
  Future<List<PublicProfile>> fetchProfiles(List<String> uids) async => const [];

  @override
  Future<bool> sendFriendRequest(String toUid, {String toName = ''}) async => _fail();

  @override
  Future<void> acceptFriendRequest(FriendRequest request) async => _fail();

  @override
  Future<void> declineFriendRequest(FriendRequest request) async => _fail();

  @override
  Future<void> cancelFriendRequest(String toUid) async => _fail();

  @override
  Future<void> removeFriend(String friendUid) async => _fail();

  @override
  Future<GameInvite> sendInvite({
    required String toUid,
    String toName = '',
    required String roomCode,
    required int gridSize,
    required int roundSeconds,
    required int entryFee,
  }) async =>
      _fail();

  @override
  Stream<List<GameInvite>> watchIncomingInvites() => Stream.value(const []);

  @override
  Stream<List<GameInvite>> watchSentInvites(String roomCode) => Stream.value(const []);

  @override
  Future<void> respondToInvite(GameInvite invite, {required bool accept}) async {}

  @override
  Future<void> recordMatch({required Map<String, int> scores, required String myUid}) async {}
}
